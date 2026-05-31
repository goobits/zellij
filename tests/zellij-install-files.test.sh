#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
zellij_dir="$(cd -- "$script_dir/.." && pwd)"
tmp="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT

install_output="$(
  HOME="$tmp/home" \
  ZELLIJ_INSTALL_BINARY=0 \
  ZELLIJ_INSTALL_SHELL_RC=0 \
    "$zellij_dir/install.sh"
)"

expected_output=$'Installed Zellij workspace setup.\nOpen a new shell or run: export PATH="$HOME/.local/bin:$PATH"\nIn a project directory, create a profile with: goob main=app,server,infra,scratch\nThen open the workspace with: goob'
if [[ "$install_output" != "$expected_output" ]]; then
  printf 'Unexpected install output:\n%s\n' "$install_output" >&2
  exit 1
fi

for executable in \
  zellij-launch-session \
  zellij-session-tab-order \
  zellij-saved-session-order \
  zellij-live-tab-order \
  zellij-open-session \
  zellij-render-layout \
  zwork \
  goob \
  zellij-workspace-init \
  zellij-workspace-doctor \
  .zellij-agent-tab-watcher
do
  if [[ ! -x "$tmp/home/.local/bin/$executable" ]]; then
    printf 'Expected installed executable %s\n' "$executable" >&2
    exit 1
  fi
done

for file in \
  .config/zellij/config.kdl
do
  if [[ ! -f "$tmp/home/$file" ]]; then
    printf 'Expected installed file %s\n' "$file" >&2
    exit 1
  fi
done

if grep -F '/usr/bin/zsh' "$tmp/home/.config/zellij/config.kdl" >/dev/null; then
  printf 'Installed Zellij config should not hardcode Linux zsh paths\n' >&2
  exit 1
fi

if ! grep -F 'post_command_discovery_hook "printf' "$tmp/home/.config/zellij/config.kdl" | grep -F '${SHELL:-sh}' >/dev/null; then
  printf 'Expected installed Zellij config to restore panes with the user shell\n' >&2
  exit 1
fi

if [[ -e "$tmp/home/.zshrc" || -e "$tmp/home/.bashrc" ]]; then
  printf 'Shell rc files should not be created when ZELLIJ_INSTALL_SHELL_RC=0\n' >&2
  exit 1
fi
