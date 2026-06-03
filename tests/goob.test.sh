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
if [[ "${1:-}" == "list-sessions" ]]; then
  printf 'frontend\nbackend\n'
  exit 0
fi
if [[ "${1:-}" == "delete-session" ]]; then
  session="${@: -1}"
  printf '%s\n' "$session" > "${FAKE_ZELLIJ_DELETED_SESSION:?}"
  if [[ "$*" != *"--force"* ]]; then
    printf 'expected force delete\n' >&2
    exit 1
  fi
  exit 0
fi
if [[ "${1:-}" == "action" ]]; then
  state="${FAKE_ZELLIJ_TABS:?}"
  shift
  case "${1:-}" in
    list-tabs)
      awk -F '\t' '
        BEGIN { printf "[" }
        {
          if (NR > 1) printf ","
          printf "{\"tab_id\":%s,\"position\":%s,\"active\":%s,\"name\":\"%s\"}", $1, $2, $3, $4
        }
        END { printf "]" }
      ' "$state"
      ;;
    list-panes)
      printf '[]'
      ;;
    new-tab)
      name=""
      while [[ "$#" -gt 0 ]]; do
        case "$1" in
          --name | -n)
            name="${2:-}"
            shift 2
            ;;
          *)
            shift
            ;;
        esac
      done
      next_id="$(awk -F '\t' 'BEGIN { max = -1 } { if ($1 > max) max = $1 } END { print max + 1 }' "$state")"
      next_position="$(awk 'END { print NR }' "$state")"
      printf '%s\t%s\tfalse\t%s\n' "$next_id" "$next_position" "$name" >> "$state"
      ;;
    close-tab-by-id)
      target="${2:-}"
      awk -F '\t' -v target="$target" 'BEGIN { OFS = FS } $1 != target { print }' "$state" > "${state}.next"
      mv "${state}.next" "$state"
      awk -F '\t' 'BEGIN { OFS = FS } { $2 = NR - 1; print }' "$state" > "${state}.next"
      mv "${state}.next" "$state"
      ;;
    go-to-tab-by-id)
      target="${2:-}"
      awk -F '\t' -v target="$target" 'BEGIN { OFS = FS } { $3 = ($1 == target ? "true" : "false"); print }' "$state" > "${state}.next"
      mv "${state}.next" "$state"
      ;;
    rename-tab-by-id)
      target="${2:-}"
      name="${3:-}"
      awk -F '\t' -v target="$target" -v name="$name" 'BEGIN { OFS = FS } { if ($1 == target) $4 = name; print }' "$state" > "${state}.next"
      mv "${state}.next" "$state"
      ;;
    move-tab)
      direction="${2:-}"
      [[ "$direction" == "left" ]] || exit 0
      active_position="$(awk -F '\t' '$3 == "true" { print $2 }' "$state")"
      [[ "$active_position" =~ ^[0-9]+$ ]] || exit 0
      if (( active_position == 0 )); then
        exit 0
      fi
      previous_position=$((active_position - 1))
      awk -F '\t' -v active="$active_position" -v previous="$previous_position" '
        BEGIN { OFS = FS }
        $2 == active { $2 = previous; print; next }
        $2 == previous { $2 = active; print; next }
        { print }
      ' "$state" > "${state}.next"
      mv "${state}.next" "$state"
      ;;
    save-session)
      touch "${state}.saved"
      ;;
  esac
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

if (
  cd "$tmp/project"
  HOME="$tmp/home" \
  PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
  FAKE_ZELLIJ_TABS="$tmp/tabs.tsv" \
  FAKE_ZELLIJ_ORDER_ARGS="$tmp/missing-order.txt" \
    "$tmp/home/.local/bin/goob" frtonend >"$tmp/missing.out" 2>"$tmp/missing.err"
); then
  printf 'Expected goob to reject missing workspace\n' >&2
  exit 1
fi

missing_error="$(cat "$tmp/missing.err")"
expected_missing_error=$'goob: workspace not found: frtonend\nLooked in: '"$tmp/home/.local/share/zellij-workspaces/profiles/my-site"$'\nAvailable workspaces:\nbackend\nextra\nfrontend\nCreate it with: goob frtonend=<tab>,...'
if [[ "$missing_error" != "$expected_missing_error" ]]; then
  printf 'Unexpected missing workspace error:\n%s\n' "$missing_error" >&2
  exit 1
fi

: > "$tmp/tabs.tsv"
: > "$tmp/tabs.tsv.panes"

naked_help="$(
  cd "$tmp/project"
  HOME="$tmp/home" \
  PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
    "$tmp/home/.local/bin/goob" 2>&1
)"
if [[ "$naked_help" != usage:$'\n'* ]]; then
  printf 'Expected naked goob to show usage:\n%s\n' "$naked_help" >&2
  exit 1
fi

(
  cd "$tmp/project"
  HOME="$tmp/home" \
  PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
  FAKE_ZELLIJ_TABS="$tmp/tabs.tsv" \
  FAKE_ZELLIJ_ORDER_ARGS="$tmp/extra-order.txt" \
    "$tmp/home/.local/bin/goob" extra -s extra-session -r "$tmp/project"
)

extra_order="$(cat "$tmp/extra-order.txt")"
expected_extra_order=$'extra-session\nnotes\nscratch'
if [[ "$extra_order" != "$expected_extra_order" ]]; then
  printf 'Unexpected extra workspace order:\n%s\n' "$extra_order" >&2
  exit 1
fi

(
  cd "$tmp/project"
  HOME="$tmp/home" \
  PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
  FAKE_ZELLIJ_TABS="$tmp/tabs.tsv" \
  FAKE_ZELLIJ_ORDER_ARGS="$tmp/now-order.txt" \
    "$tmp/home/.local/bin/goob" now=tools,components,scratch >/dev/null
)

now_order="$(cat "$tmp/now-order.txt")"
expected_now_order=$'now\ntools\ncomponents\nscratch'
if [[ "$now_order" != "$expected_now_order" ]]; then
  printf 'Unexpected now workspace order:\n%s\n' "$now_order" >&2
  exit 1
fi

if [[ "$(cat "$profile_dir/now.tabs")" != $'tools\ncomponents\nscratch' ]]; then
  printf 'Unexpected local now.tabs:\n%s\n' "$(cat "$profile_dir/now.tabs")" >&2
  exit 1
fi

if ! grep -Fxq 'default_workspaces=frontend backend extra now' "$profile_dir/profile.conf"; then
  printf 'Expected now in default_workspaces:\n%s\n' "$(cat "$profile_dir/profile.conf")" >&2
  exit 1
fi

cat > "$profile_dir/front.tabs" <<'EOF'
tools
components
keyboard
skills
scratch
EOF

cat > "$tmp/tabs.tsv" <<'EOF'
0	0	false	tools 🤖
1	1	false	components 🤖
2	2	false	keyboard 🔔
3	3	true	skills 🤖
4	4	false	scratch 🤖
EOF

front_list="$(
  cd "$tmp/project"
  HOME="$tmp/home" \
  PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
  FAKE_ZELLIJ_TABS="$tmp/tabs.tsv" \
    "$tmp/home/.local/bin/goob" front list
)"
if [[ "$front_list" != $'  0 tools\n  1 components\n  2 keyboard\n* 3 skills\n  4 scratch' ]]; then
  printf 'Unexpected front list output:\n%s\n' "$front_list" >&2
  exit 1
fi

(
  cd "$tmp/project"
  HOME="$tmp/home" \
  PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
  FAKE_ZELLIJ_TABS="$tmp/tabs.tsv" \
  FAKE_ZELLIJ_ORDER_ARGS="$tmp/front-add-order.txt" \
    "$tmp/home/.local/bin/goob" front add search@1 >/dev/null
)

if [[ "$(cat "$profile_dir/front.tabs")" != $'tools\nsearch\ncomponents\nkeyboard\nskills\nscratch' ]]; then
  printf 'Unexpected front tabs after add:\n%s\n' "$(cat "$profile_dir/front.tabs")" >&2
  exit 1
fi

if [[ "$(cat "$tmp/front-add-order.txt")" != $'front\ntools\nsearch\ncomponents\nkeyboard\nskills\nscratch' ]]; then
  printf 'Unexpected front add sync order:\n%s\n' "$(cat "$tmp/front-add-order.txt")" >&2
  exit 1
fi

(
  cd "$tmp/project"
  HOME="$tmp/home" \
  PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
  FAKE_ZELLIJ_TABS="$tmp/tabs.tsv" \
  FAKE_ZELLIJ_ORDER_ARGS="$tmp/front-move-order.txt" \
    "$tmp/home/.local/bin/goob" front move keyboard@1 >/dev/null
)

if [[ "$(cat "$profile_dir/front.tabs")" != $'tools\nkeyboard\nsearch\ncomponents\nskills\nscratch' ]]; then
  printf 'Unexpected front tabs after move:\n%s\n' "$(cat "$profile_dir/front.tabs")" >&2
  exit 1
fi

(
  cd "$tmp/project"
  HOME="$tmp/home" \
  PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
  FAKE_ZELLIJ_TABS="$tmp/tabs.tsv" \
    "$tmp/home/.local/bin/goob" front refresh >/dev/null
)

if [[ "$(awk -F '\t' '{ print $4 }' "$tmp/tabs.tsv")" != $'tools 🤖\nkeyboard\nsearch\ncomponents\nskills' ]]; then
  printf 'Expected front refresh to repair live titles:\n%s\n' "$(cat "$tmp/tabs.tsv")" >&2
  exit 1
fi

(
  cd "$tmp/project"
  HOME="$tmp/home" \
  PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
  FAKE_ZELLIJ_TABS="$tmp/tabs.tsv" \
  FAKE_ZELLIJ_ORDER_ARGS="$tmp/front-rename-order.txt" \
    "$tmp/home/.local/bin/goob" front rename keyboard keys >/dev/null
)

if [[ "$(cat "$profile_dir/front.tabs")" != $'tools\nkeys\nsearch\ncomponents\nskills\nscratch' ]]; then
  printf 'Unexpected front tabs after rename:\n%s\n' "$(cat "$profile_dir/front.tabs")" >&2
  exit 1
fi

if [[ "$(cat "$tmp/front-rename-order.txt")" != $'front\ntools\nkeys\nsearch\ncomponents\nskills\nscratch' ]]; then
  printf 'Unexpected front rename sync order:\n%s\n' "$(cat "$tmp/front-rename-order.txt")" >&2
  exit 1
fi

if [[ "$(awk -F '\t' '{ print $4 }' "$tmp/tabs.tsv")" != $'tools 🤖\nkeys\nsearch\ncomponents\nskills' ]]; then
  printf 'Expected front rename to refresh live titles:\n%s\n' "$(cat "$tmp/tabs.tsv")" >&2
  exit 1
fi

(
  cd "$tmp/project"
  HOME="$tmp/home" \
  PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
  FAKE_ZELLIJ_TABS="$tmp/tabs.tsv" \
    "$tmp/home/.local/bin/goob" front remove keys >/dev/null
)

if [[ "$(cat "$profile_dir/front.tabs")" != $'tools\nsearch\ncomponents\nskills\nscratch' ]]; then
  printf 'Unexpected front tabs after remove:\n%s\n' "$(cat "$profile_dir/front.tabs")" >&2
  exit 1
fi

if grep -q 'keys' "$tmp/tabs.tsv"; then
  printf 'Expected keys live tab to be closed:\n%s\n' "$(cat "$tmp/tabs.tsv")" >&2
  exit 1
fi

sessions="$(
  HOME="$tmp/home" PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
    "$tmp/home/.local/bin/goob" ps
)"
if [[ "$sessions" != $'frontend\nbackend' ]]; then
  printf 'Unexpected goob ps output:\n%s\n' "$sessions" >&2
  exit 1
fi

HOME="$tmp/home" \
PATH="$tmp/fake-bin:$tmp/home/.local/bin:$PATH" \
FAKE_ZELLIJ_DELETED_SESSION="$tmp/deleted-session.txt" \
  "$tmp/home/.local/bin/goob" kill extra-session >/dev/null

if [[ "$(cat "$tmp/deleted-session.txt")" != "extra-session" ]]; then
  printf 'Expected goob kill to delete extra-session\n' >&2
  exit 1
fi
