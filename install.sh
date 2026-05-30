#!/usr/bin/env bash
set -euo pipefail

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
zellij_version="${ZELLIJ_VERSION:-0.44.3}"
start_marker="# >>> zellij workspaces >>>"
end_marker="# <<< zellij workspaces <<<"
original_path="${PATH:-}"
local_bin="$HOME/.local/bin"
export PATH="$local_bin:$PATH"

original_path_has_local_bin() {
  case ":$original_path:" in
    *":$local_bin:"*) return 0 ;;
    *) return 1 ;;
  esac
}

install_zellij_binary() {
  if command -v zellij >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/zellij" ]]; then
    return
  fi

  if [[ "${ZELLIJ_INSTALL_BINARY:-1}" == "0" ]]; then
    printf 'zellij is not installed; skipped binary install because ZELLIJ_INSTALL_BINARY=0\n' >&2
    return
  fi

  local os arch target asset checksum_asset url tmp checksum expected
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os:$arch" in
    Linux:aarch64 | Linux:arm64)
      target="aarch64-unknown-linux-musl"
      ;;
    Linux:x86_64 | Linux:amd64)
      target="x86_64-unknown-linux-musl"
      ;;
    Darwin:arm64)
      target="aarch64-apple-darwin"
      ;;
    Darwin:x86_64)
      target="x86_64-apple-darwin"
      ;;
    *)
      printf 'zellij is not installed and this installer does not know platform %s/%s\n' "$os" "$arch" >&2
      return
      ;;
  esac

  for required in curl tar; do
    if ! command -v "$required" >/dev/null 2>&1; then
      printf 'zellij is not installed; need %s to install it automatically\n' "$required" >&2
      return
    fi
  done

  if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    printf 'zellij is not installed; need sha256sum or shasum to install it automatically\n' >&2
    return
  fi

  asset="zellij-${target}.tar.gz"
  checksum_asset="zellij-${target}.sha256sum"
  url="https://github.com/zellij-org/zellij/releases/download/v${zellij_version}"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  curl -fsSL "$url/$asset" -o "$tmp/$asset"
  curl -fsSL "$url/$checksum_asset" -o "$tmp/$checksum_asset"
  expected="$(awk 'NR == 1 { print $1 }' "$tmp/$checksum_asset")"
  if [[ -z "$expected" ]]; then
    printf 'could not find checksum for %s in Zellij %s\n' "$checksum_asset" "$zellij_version" >&2
    return 1
  fi

  tar -xzf "$tmp/$asset" -C "$tmp"
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s  %s\n' "$expected" "$tmp/zellij" | sha256sum -c -
  else
    checksum="$(shasum -a 256 "$tmp/zellij" | awk '{ print $1 }')"
    if [[ "$checksum" != "$expected" ]]; then
      printf 'checksum mismatch for %s\n' "$checksum_asset" >&2
      return 1
    fi
  fi
  install -d "$HOME/.local/bin"
  install -m 0755 "$tmp/zellij" "$HOME/.local/bin/zellij"
  rm -rf "$tmp"
  trap - EXIT
}

install_files() {
  local executable target
  local executables=(
    zellij-saved-session-order
    zellij-live-tab-order
    zellij-session-tab-order
    zellij-launch-session
    zellij-open-session
    zellij-render-layout
    zwork
    goob
    zellij-workspace-init
    zellij-workspace-doctor
    zellij-agent-tab-watcher
  )

  install -d "$HOME/.config/zellij" "$HOME/.local/bin" "$HOME/.local/share/zellij-workspaces/profiles"
  install -m 0644 "$source_dir/config.kdl" "$HOME/.config/zellij/config.kdl"

  for executable in "${executables[@]}"; do
    target="$executable"
    if [[ "$executable" == "zellij-agent-tab-watcher" ]]; then
      target=".zellij-agent-tab-watcher"
    fi
    install -m 0755 "$source_dir/bin/$executable" "$HOME/.local/bin/$target"
  done

  rm -f "$HOME/.local/bin/.zellij-codex-tab-watcher"
  rm -f "$HOME/.config/zellij/layouts/backend.kdl" "$HOME/.config/zellij/layouts/frontend.kdl"
}

shell_block() {
  cat <<'EOF'
export PATH="$HOME/.local/bin:$PATH"
alias zj='zellij'

if [[ -t 0 ]]; then
  stty -ixon 2>/dev/null
fi

if [[ -n "${ZSH_VERSION:-}" ]]; then
  bindkey -M viins '^[^?' backward-kill-word 2>/dev/null
  bindkey -M viins '^[^H' backward-kill-word 2>/dev/null
  bindkey -M emacs '^[^?' backward-kill-word 2>/dev/null
  bindkey -M emacs '^[^H' backward-kill-word 2>/dev/null
fi

if [[ -n "${ZELLIJ:-}" ]]; then
  codex() {
    local arg
    for arg in "$@"; do
      if [[ "$arg" == "--no-alt-screen" ]]; then
        command codex "$@"
        return
      fi
    done
    command codex --no-alt-screen "$@"
  }
fi

if [[ -n "${ZELLIJ:-}" && -x "$HOME/.local/bin/.zellij-agent-tab-watcher" ]]; then
  "$HOME/.local/bin/.zellij-agent-tab-watcher" --start
fi
EOF
}

update_shell_file() {
  local file tmp
  file="$1"
  tmp="$(mktemp)"
  touch "$file"
  awk -v start="$start_marker" -v end="$end_marker" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    skip != 1 { print }
  ' "$file" > "$tmp"

  {
    cat "$tmp"
    printf '\n%s\n' "$start_marker"
    shell_block
    printf '%s\n' "$end_marker"
  } > "$file"
  rm -f "$tmp"
}

install_zellij_binary
install_files

if [[ "${ZELLIJ_INSTALL_SHELL_RC:-1}" != "0" ]]; then
  update_shell_file "$HOME/.zshrc"
  update_shell_file "$HOME/.bashrc"
fi

printf 'Installed Zellij workspace setup.\n'
if ! original_path_has_local_bin; then
  printf 'Open a new shell or run: export PATH="$HOME/.local/bin:$PATH"\n'
fi
printf 'In a project directory, create a profile with: goob init\n'
printf 'Then open the workspace with: goob\n'
