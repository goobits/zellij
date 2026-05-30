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

cp "$zellij_dir/bin/zbackend" "$bin_dir/zbackend"
cp "$zellij_dir/bin/zfrontend" "$bin_dir/zfrontend"
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
infra
accounts
electron
scratch
EOF

cat > "$profile_dir/frontend.tabs" <<'EOF'
app
components
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
expected_backend_order=$'backend-test\ninfra\naccounts\nelectron\nscratch'
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
expected_frontend_order=$'frontend-test\napp\ncomponents\nscratch'
if [[ "$frontend_order" != "$expected_frontend_order" ]]; then
  printf 'Unexpected frontend fallback tab order:\n%s\n' "$frontend_order" >&2
  exit 1
fi
