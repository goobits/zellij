#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
zellij_dir="$(cd -- "$script_dir/.." && pwd)"
tmp="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT

profile_dir="$tmp/profile/my-site"
mkdir -p "$profile_dir/bin" "$tmp/fake-bin"

cat > "$profile_dir/profile.conf" <<'EOF'
name=my-site
root=/tmp/project
default_workspace=default
default_workspaces=default extra
EOF

cat > "$profile_dir/default.tabs" <<'EOF'
editor
server	/tmp/project/server
scratch
EOF

cat > "$profile_dir/extra.tabs" <<'EOF'
one
two
EOF

cat > "$profile_dir/bin/zsite" <<'EOF'
#!/usr/bin/env bash
printf 'site launcher\n'
EOF
chmod +x "$profile_dir/bin/zsite"

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

HOME="$tmp/home" \
ZELLIJ_INSTALL_BINARY=0 \
ZELLIJ_INSTALL_SHELL_RC=0 \
PATH="$tmp/fake-bin:$PATH" \
  "$zellij_dir/install.sh" >/dev/null

HOME="$tmp/home" "$tmp/home/.local/bin/zellij-workspace-init" --config "$profile_dir" >/dev/null

for file in \
  .local/share/zellij-workspaces/profiles/my-site/profile.conf \
  .local/share/zellij-workspaces/profiles/my-site/default.tabs \
  .local/share/zellij-workspaces/profiles/my-site/extra.tabs
do
  if [[ ! -f "$tmp/home/$file" ]]; then
    printf 'Expected installed profile file %s\n' "$file" >&2
    exit 1
  fi
done

if [[ ! -x "$tmp/home/.local/bin/zsite" ]]; then
  printf 'Expected profile launcher zsite to be installed\n' >&2
  exit 1
fi

if [[ "$(cat "$tmp/home/.local/share/zellij-workspaces/default-profile")" != "my-site" ]]; then
  printf 'Expected my-site to be saved as the default profile\n' >&2
  exit 1
fi

HOME="$tmp/home" PATH="$tmp/fake-bin:$PATH" \
  "$tmp/home/.local/bin/goob" doctor --config "$profile_dir" >/dev/null

listed="$(
  HOME="$tmp/home" PATH="$tmp/fake-bin:$PATH" \
    "$tmp/home/.local/bin/goob" list --config "$profile_dir"
)"
expected_list=$'default\nextra'
if [[ "$listed" != "$expected_list" ]]; then
  printf 'Unexpected goob list output:\n%s\n' "$listed" >&2
  exit 1
fi

rendered="$("$tmp/home/.local/bin/zellij-render-layout" "$tmp/home/.local/share/zellij-workspaces/profiles/my-site/default.tabs" /tmp/project)"
if ! grep -F 'pane cwd="/tmp/project/server"' <<<"$rendered" >/dev/null; then
  printf 'Expected tab-specific cwd in installed profile layout:\n%s\n' "$rendered" >&2
  exit 1
fi
