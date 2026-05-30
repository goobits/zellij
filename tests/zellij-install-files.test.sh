#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
zellij_dir="$(cd -- "$script_dir/.." && pwd)"
tmp="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT

HOME="$tmp/home" \
ZELLIJ_INSTALL_BINARY=0 \
ZELLIJ_INSTALL_SHELL_RC=0 \
  "$zellij_dir/install.sh" >/dev/null

for executable in \
  zbackend \
  zfrontend \
  zellij-launch-session \
  zellij-session-tab-order \
  zellij-saved-session-order \
  zellij-live-tab-order \
  zellij-open-session \
  zellij-render-layout \
  zwork \
  .zellij-agent-tab-watcher
do
  if [[ ! -x "$tmp/home/.local/bin/$executable" ]]; then
    printf 'Expected installed executable %s\n' "$executable" >&2
    exit 1
  fi
done

for file in \
  .config/zellij/config.kdl \
  .local/share/zellij-workspaces/profiles/sketch-api/profile.conf \
  .local/share/zellij-workspaces/profiles/sketch-api/backend.tabs \
  .local/share/zellij-workspaces/profiles/sketch-api/frontend.tabs
do
  if [[ ! -f "$tmp/home/$file" ]]; then
    printf 'Expected installed file %s\n' "$file" >&2
    exit 1
  fi
done

if [[ -e "$tmp/home/.zshrc" || -e "$tmp/home/.bashrc" ]]; then
  printf 'Shell rc files should not be created when ZELLIJ_INSTALL_SHELL_RC=0\n' >&2
  exit 1
fi
