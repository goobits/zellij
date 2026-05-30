#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
zellij_dir="$(cd -- "$script_dir/.." && pwd)"
tmp="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT

mkdir -p "$tmp/fake-bin"

cat > "$tmp/fake-bin/zellij" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf 'zellij 0.44.3\n'
  exit 0
fi
if [[ "${1:-}" == "setup" && "${2:-}" == "--check" ]]; then
  exit 0
fi
if [[ "${1:-}" == "list-sessions" ]]; then
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

project="$tmp/my-site"
mkdir -p "$project"

(
  cd "$project"
  HOME="$tmp/home" PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
    "$tmp/home/.local/bin/goob" init >/dev/null
)

expected_profile=$'name=my-site\nroot='"$project"$'\ndefault_workspace=main\ndefault_workspaces=main'
if [[ "$(cat "$project/config/zellij/profile.conf")" != "$expected_profile" ]]; then
  printf 'Unexpected default profile.conf:\n%s\n' "$(cat "$project/config/zellij/profile.conf")" >&2
  exit 1
fi

expected_tabs=$'app\nserver\ninfra\nscratch'
if [[ "$(cat "$project/config/zellij/main.tabs")" != "$expected_tabs" ]]; then
  printf 'Unexpected default main.tabs:\n%s\n' "$(cat "$project/config/zellij/main.tabs")" >&2
  exit 1
fi

if [[ ! -f "$tmp/home/.local/share/zellij-workspaces/profiles/my-site/main.tabs" ]]; then
  printf 'Expected goob init to install generated profile\n' >&2
  exit 1
fi

if (
  cd "$project"
  HOME="$tmp/home" PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
    "$tmp/home/.local/bin/goob" init app server >/dev/null 2>&1
); then
  printf 'Expected goob init to refuse overwriting config/zellij without --force\n' >&2
  exit 1
fi

(
  cd "$project"
  HOME="$tmp/home" PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
    "$tmp/home/.local/bin/goob" init --force frontend=app,ui,tools backend=infra,api,db >/dev/null
)

expected_profile=$'name=my-site\nroot='"$project"$'\ndefault_workspace=frontend\ndefault_workspaces=frontend backend'
if [[ "$(cat "$project/config/zellij/profile.conf")" != "$expected_profile" ]]; then
  printf 'Unexpected multi-workspace profile.conf:\n%s\n' "$(cat "$project/config/zellij/profile.conf")" >&2
  exit 1
fi

if [[ "$(cat "$project/config/zellij/frontend.tabs")" != $'app\nui\ntools' ]]; then
  printf 'Unexpected frontend.tabs:\n%s\n' "$(cat "$project/config/zellij/frontend.tabs")" >&2
  exit 1
fi

if [[ "$(cat "$project/config/zellij/backend.tabs")" != $'infra\napi\ndb' ]]; then
  printf 'Unexpected backend.tabs:\n%s\n' "$(cat "$project/config/zellij/backend.tabs")" >&2
  exit 1
fi

listed="$(
  cd "$project"
  HOME="$tmp/home" PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
    "$tmp/home/.local/bin/goob" ls
)"
if [[ "$listed" != $'backend\nfrontend' ]]; then
  printf 'Unexpected goob ls output:\n%s\n' "$listed" >&2
  exit 1
fi

for invalid_args in \
  'bad=tab,,name' \
  'bad=' \
  'front=end plain-tab' \
  'bad/name=tab'
do
  if (
    cd "$project"
    HOME="$tmp/home" PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
      "$tmp/home/.local/bin/goob" init --force $invalid_args >/dev/null 2>&1
  ); then
    printf 'Expected goob init to reject: %s\n' "$invalid_args" >&2
    exit 1
  fi
done
