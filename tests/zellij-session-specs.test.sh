#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
zellij_dir="$(cd -- "$script_dir/.." && pwd)"

check_layout_tabs() {
  local name profile_dir rendered spec expected actual

  name="$1"
  profile_dir="$zellij_dir/examples/basic-website"
  spec="$profile_dir/${name}.tabs"
  rendered="$("$zellij_dir/bin/zellij-render-layout" "$spec" /workspace)"
  expected="$(cat "$spec")"
  actual="$(awk -F '"' '/^    tab name=/ { print $2 }' <<<"$rendered")"

  if [[ "$actual" != "$expected" ]]; then
    printf 'Unexpected %s layout tabs:\n%s\n' "$name" "$actual" >&2
    printf 'Expected:\n%s\n' "$expected" >&2
    exit 1
  fi
}

check_layout_tabs default
