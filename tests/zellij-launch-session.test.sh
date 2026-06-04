#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
zellij_dir="$(cd -- "$script_dir/.." && pwd)"
tmp="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT

bin_dir="$tmp/bin"
profile_dir="$tmp/profiles/test-profile"
mkdir -p "$bin_dir" "$profile_dir"

cp "$zellij_dir/bin/zwork" "$bin_dir/zwork"
cp "$zellij_dir/bin/zellij-render-layout" "$bin_dir/zellij-render-layout"
cp "$zellij_dir/bin/zellij-open-session" "$bin_dir/zellij-open-session"
cp "$zellij_dir/bin/zellij-launch-session" "$bin_dir/zellij-launch-session"
ln -s "$script_dir/fixtures/fake-zellij" "$bin_dir/zellij"

cat > "$bin_dir/zellij-session-tab-order" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "${FAKE_ZELLIJ_ORDER_ARGS:?}"
EOF
chmod +x "$bin_dir"/*

cat > "$profile_dir/profile.conf" <<'EOF'
root=/tmp/test-root
EOF

cat > "$profile_dir/backend.tabs" <<'EOF'
editor
server
database
scratch
EOF

cat > "$profile_dir/frontend.tabs" <<'EOF'
preview
docs
scratch
EOF

: > "$tmp/tabs.tsv"
: > "$tmp/tabs.tsv.panes"

PATH="$bin_dir:$PATH" \
HOME="$tmp/home" \
ZELLIJ=1 \
ZELLIJ_PROFILE_DIR="$tmp/profiles" \
FAKE_ZELLIJ_TABS="$tmp/tabs.tsv" \
FAKE_ZELLIJ_ORDER_ARGS="$tmp/backend-order.txt" \
  "$bin_dir/zwork" test-profile backend backend-test /workspace

backend_order="$(cat "$tmp/backend-order.txt")"
expected_backend_order=$'backend-test\neditor\nserver\ndatabase\nscratch'
if [[ "$backend_order" != "$expected_backend_order" ]]; then
  printf 'Unexpected backend fallback tab order:\n%s\n' "$backend_order" >&2
  exit 1
fi

PATH="$bin_dir:$PATH" \
HOME="$tmp/home" \
ZELLIJ=1 \
ZELLIJ_PROFILE_DIR="$tmp/profiles" \
FAKE_ZELLIJ_TABS="$tmp/tabs.tsv" \
FAKE_ZELLIJ_ORDER_ARGS="$tmp/frontend-order.txt" \
  "$bin_dir/zwork" test-profile frontend frontend-test /workspace

frontend_order="$(cat "$tmp/frontend-order.txt")"
expected_frontend_order=$'frontend-test\npreview\ndocs\nscratch'
if [[ "$frontend_order" != "$expected_frontend_order" ]]; then
  printf 'Unexpected frontend fallback tab order:\n%s\n' "$frontend_order" >&2
  exit 1
fi

repair_bin_dir="$tmp/repair-bin"
repair_cache="$tmp/repair-cache"
repair_session_dir="$repair_cache/zellij/contract_version_1/session_info/fresh-session"
mkdir -p "$repair_bin_dir" "$repair_session_dir"
cp "$zellij_dir/bin/zellij-launch-session" "$repair_bin_dir/zellij-launch-session"

cat > "$repair_bin_dir/zellij-session-tab-order" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF

cat > "$repair_bin_dir/zellij" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "list-sessions" ]]; then
  exit 0
fi
printf '%s\n' "$*" > "${FAKE_ZELLIJ_LAUNCH_ARGS:?}"
EOF

repair_shell="$tmp/repair-shell"
cat > "$repair_shell" <<'EOF'
#!/usr/bin/env sh
exit 0
EOF
chmod +x "$repair_bin_dir"/* "$repair_shell"

printf 'pane command="/missing/zsh"\n' > "$repair_session_dir/session-layout.kdl"
printf 'command "/missing/zsh"\n' > "$repair_session_dir/session-metadata.kdl"
printf 'layout {}\n' > "$tmp/layout.kdl"

PATH="$repair_bin_dir:$PATH" \
HOME="$tmp/home" \
XDG_CACHE_HOME="$repair_cache" \
SHELL="$repair_shell" \
ZELLIJ= \
ZELLIJ_REPAIR_BROKEN_SHELL=/missing/zsh \
FAKE_ZELLIJ_LAUNCH_ARGS="$tmp/repair-launch-args.txt" \
  "$repair_bin_dir/zellij-launch-session" "$tmp/layout.kdl" fresh-session /workspace editor scratch

if grep -F '/missing/zsh' "$repair_session_dir/session-layout.kdl" "$repair_session_dir/session-metadata.kdl" >/dev/null; then
  printf 'Expected saved session shell paths to be repaired\n' >&2
  exit 1
fi

if ! grep -F "$repair_shell" "$repair_session_dir/session-layout.kdl" "$repair_session_dir/session-metadata.kdl" >/dev/null; then
  printf 'Expected saved session shell paths to use current shell\n' >&2
  exit 1
fi

repair_launch_args="$(cat "$tmp/repair-launch-args.txt")"
expected_repair_launch_args="--layout $tmp/layout.kdl attach --force-run-commands fresh-session --create"
if [[ "$repair_launch_args" != "$expected_repair_launch_args" ]]; then
  printf 'Unexpected repair launch args:\n%s\n' "$repair_launch_args" >&2
  exit 1
fi
