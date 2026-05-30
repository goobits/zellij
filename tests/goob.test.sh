#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
zellij_dir="$(cd -- "$script_dir/.." && pwd)"
tmp="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp" || true
}
trap cleanup EXIT

profile_dir="$tmp/project/config/zellij"
mkdir -p "$profile_dir" "$tmp/fake-bin"

cat > "$tmp/fake-bin/zellij" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf 'zellij 0.44.3\n'
  exit 0
fi
if [[ "${1:-}" == "setup" && "${2:-}" == "--check" ]]; then
  exit 0
fi
exit 0
EOF
chmod +x "$tmp/fake-bin/zellij"

cat > "$profile_dir/profile.conf" <<'EOF'
name=my-site
root=/tmp/project
default_workspace=frontend
default_workspaces=frontend backend extra
EOF

cat > "$profile_dir/frontend.tabs" <<'EOF'
app
ui
scratch
EOF

cat > "$profile_dir/backend.tabs" <<'EOF'
api
database
scratch
EOF

cat > "$profile_dir/extra.tabs" <<'EOF'
notes
scratch
EOF

HOME="$tmp/home" \
ZELLIJ_INSTALL_BINARY=0 \
ZELLIJ_INSTALL_SHELL_RC=0 \
PATH="$tmp/fake-bin:$PATH" \
  "$zellij_dir/install.sh" >/dev/null

cat > "$tmp/home/.local/bin/zellij-session-tab-order" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "${FAKE_ZELLIJ_ORDER_ARGS:?}"
EOF
chmod +x "$tmp/home/.local/bin/zellij-session-tab-order"

HOME="$tmp/home" PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
  "$tmp/home/.local/bin/goob" setup --config "$profile_dir" >/dev/null

HOME="$tmp/home" PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
  "$tmp/home/.local/bin/goob" doctor --config "$profile_dir" >/dev/null

listed="$(
  HOME="$tmp/home" PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
    "$tmp/home/.local/bin/goob" list --config "$profile_dir"
)"
expected_list=$'backend\nextra\nfrontend'
if [[ "$listed" != "$expected_list" ]]; then
  printf 'Unexpected goob list output:\n%s\n' "$listed" >&2
  exit 1
fi

: > "$tmp/tabs.tsv"
: > "$tmp/tabs.tsv.panes"

(
  cd "$tmp/project"
  HOME="$tmp/home" \
  PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
  FAKE_ZELLIJ_TABS="$tmp/tabs.tsv" \
  FAKE_ZELLIJ_ORDER_ARGS="$tmp/default-order.txt" \
    "$tmp/home/.local/bin/goob"
)

default_order="$(cat "$tmp/default-order.txt")"
expected_default_order=$'frontend\napp\nui\nscratch'
if [[ "$default_order" != "$expected_default_order" ]]; then
  printf 'Unexpected default workspace order:\n%s\n' "$default_order" >&2
  exit 1
fi

(
  cd "$tmp/project"
  HOME="$tmp/home" \
  PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
  FAKE_ZELLIJ_TABS="$tmp/tabs.tsv" \
  FAKE_ZELLIJ_ORDER_ARGS="$tmp/extra-order.txt" \
    "$tmp/home/.local/bin/goob" extra extra-session /tmp/project
)

extra_order="$(cat "$tmp/extra-order.txt")"
expected_extra_order=$'extra-session\nnotes\nscratch'
if [[ "$extra_order" != "$expected_extra_order" ]]; then
  printf 'Unexpected extra workspace order:\n%s\n' "$extra_order" >&2
  exit 1
fi
