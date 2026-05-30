#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
helper="$script_dir/../bin/zellij-session-tab-order"
tmp="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT

session_dir="$tmp/zellij/contract_version_1/session_info/test-workspace"
mkdir -p "$session_dir"

cat > "$session_dir/session-layout.kdl" <<'EOF'
layout {
    cwd "/workspace"
    tab name="database" hide_floating_panes=true {
        pane contents_file="initial_contents_1"
    }
    tab name="scratch 🤖" focus=true hide_floating_panes=true {
        pane focus=true contents_file="initial_contents_2"
    }
    tab name="editor" hide_floating_panes=true {
        pane contents_file="initial_contents_3"
    }
    tab name="server" hide_floating_panes=true {
        pane contents_file="initial_contents_4"
    }
    tab name="custom" hide_floating_panes=true {
        pane contents_file="initial_contents_5"
    }
    new_tab_template {
        pane cwd="/workspace"
    }
}
EOF

cat > "$session_dir/session-metadata.kdl" <<'EOF'
name "test-workspace"
tabs {
    tab {
        position 0
        name "database"
        tab_id 0
    }
    tab {
        position 1
        name "scratch 🤖"
        tab_id 1
    }
    tab {
        position 2
        name "editor"
        tab_id 2
    }
    tab {
        position 3
        name "server"
        tab_id 3
    }
    tab {
        position 4
        name "custom"
        tab_id 4
    }
}
panes {
    pane {
        id 0
        tab_position 0
    }
    pane {
        id 1
        tab_position 1
    }
    pane {
        id 2
        tab_position 2
    }
    pane {
        id 3
        tab_position 3
    }
    pane {
        id 4
        tab_position 4
    }
}
EOF

XDG_CACHE_HOME="$tmp" ZELLIJ_SESSION_TAB_ORDER_SAVED_ONLY=1 \
  "$helper" test-workspace editor server database logs scratch

layout_order="$(
  awk -F '"' '/^    tab name=/ { print $2 }' "$session_dir/session-layout.kdl"
)"
expected_layout_order=$'editor\nserver\ndatabase\nscratch 🤖\ncustom'

if [[ "$layout_order" != "$expected_layout_order" ]]; then
  printf 'Unexpected session-layout tab order:\n%s\n' "$layout_order" >&2
  exit 1
fi

metadata_order="$(
  awk '
    /^    tab \{/ { in_tab = 1; position = ""; name = "" }
    in_tab && /^        position / { position = $2 }
    in_tab && /^        name / { name = $2; gsub(/"/, "", name) }
    in_tab && /^    \}/ { print position "\t" name; in_tab = 0 }
  ' "$session_dir/session-metadata.kdl"
)"
expected_metadata_order=$'0\teditor\n1\tserver\n2\tdatabase\n3\tscratch\n4\tcustom'

if [[ "$metadata_order" != "$expected_metadata_order" ]]; then
  printf 'Unexpected session-metadata tab order:\n%s\n' "$metadata_order" >&2
  exit 1
fi

pane_positions="$(
  awk '/^        tab_position / { print $2 }' "$session_dir/session-metadata.kdl"
)"
expected_pane_positions=$'2\n3\n0\n1\n4'

if [[ "$pane_positions" != "$expected_pane_positions" ]]; then
  printf 'Unexpected pane tab positions:\n%s\n' "$pane_positions" >&2
  exit 1
fi

live_bin="$tmp/bin"
live_state="$tmp/live-tabs.tsv"
mkdir -p "$live_bin"
ln -s "$script_dir/fixtures/fake-zellij" "$live_bin/zellij"

cat > "$live_state" <<'EOF'
0	0	true	infra
1	1	false	server
2	2	false	logs
3	3	false	docs
4	4	false	preview
5	5	false	scratch
EOF

: > "${live_state}.panes"

PATH="$live_bin:$PATH" FAKE_ZELLIJ_TABS="$live_state" XDG_CACHE_HOME="$tmp/live-cache" ZELLIJ_SESSION_TAB_ORDER_CREATE_MISSING=1 \
  "$helper" test-live infra server logs docs preview database scratch

live_order="$(
  sort -t $'\t' -k2,2n "$live_state" | awk -F '\t' '{ print $4 }'
)"
expected_live_order=$'infra\nserver\nlogs\ndocs\npreview\ndatabase\nscratch'

if [[ "$live_order" != "$expected_live_order" ]]; then
  printf 'Unexpected live tab order:\n%s\n' "$live_order" >&2
  exit 1
fi

if [[ ! -f "${live_state}.saved" ]]; then
  printf 'Expected live session to be saved after creating missing tabs\n' >&2
  exit 1
fi

status_bar_count="$(grep -c 'zellij:status-bar' "${live_state}.panes" || true)"
if [[ "$status_bar_count" != "0" ]]; then
  printf 'Expected created status-bar panes to be closed, found %s\n' "$status_bar_count" >&2
  exit 1
fi
