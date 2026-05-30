#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
watcher="$script_dir/../bin/zellij-agent-tab-watcher"
tmp="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT

bin_dir="$tmp/bin"
screen_dir="$tmp/screens"
mkdir -p "$bin_dir" "$tmp/runtime" "$screen_dir"
ln -s "$script_dir/fixtures/fake-zellij" "$bin_dir/zellij"

tabs="$tmp/tabs.tsv"
panes="$tabs.panes"

cat > "$tabs" <<'EOF'
1	0	true	infra
EOF

cat > "$panes" <<'EOF'
1	1	infra	false	⠋ codex
EOF

PATH="$bin_dir:$PATH" \
XDG_RUNTIME_DIR="$tmp/runtime" \
ZELLIJ_SESSION_NAME=watcher-test \
FAKE_ZELLIJ_TABS="$tabs" \
  "$watcher" --once

busy_name="$(awk -F '\t' '$1 == 1 { print $4 }' "$tabs")"
if [[ "$busy_name" != "infra 🤖" ]]; then
  printf 'Expected busy marker, got %s\n' "$busy_name" >&2
  exit 1
fi

cat > "$tabs" <<'EOF'
1	0	true	infra
EOF

cat > "$panes" <<'EOF'
1	1	infra	false	claude --permission-mode bypassPermissions
EOF

cat > "$screen_dir/1.txt" <<'EOF'
 ▐▛███▜▌   Claude Code v2.1.156

· Deciphering…
EOF

PATH="$bin_dir:$PATH" \
XDG_RUNTIME_DIR="$tmp/runtime" \
ZELLIJ_SESSION_NAME=watcher-test \
FAKE_ZELLIJ_TABS="$tabs" \
FAKE_ZELLIJ_SCREEN_DIR="$screen_dir" \
  "$watcher" --once

claude_busy_name="$(awk -F '\t' '$1 == 1 { print $4 }' "$tabs")"
if [[ "$claude_busy_name" != "infra 🤖" ]]; then
  printf 'Expected Claude busy marker, got %s\n' "$claude_busy_name" >&2
  exit 1
fi

cat > "$tabs" <<'EOF'
1	0	true	infra 🤖
EOF

cat > "$panes" <<'EOF'
1	1	infra 🤖	false	claude --permission-mode bypassPermissions
EOF

cat > "$screen_dir/1.txt" <<'EOF'
 ▐▛███▜▌   Claude Code v2.1.156

❯
EOF

PATH="$bin_dir:$PATH" \
XDG_RUNTIME_DIR="$tmp/runtime" \
ZELLIJ_SESSION_NAME=watcher-test \
FAKE_ZELLIJ_TABS="$tabs" \
FAKE_ZELLIJ_SCREEN_DIR="$screen_dir" \
  "$watcher" --once

claude_idle_name="$(awk -F '\t' '$1 == 1 { print $4 }' "$tabs")"
if [[ "$claude_idle_name" != "infra" ]]; then
  printf 'Expected Claude idle marker cleanup, got %s\n' "$claude_idle_name" >&2
  exit 1
fi

cat > "$tabs" <<'EOF'
1	0	true	infra
EOF

cat > "$panes" <<'EOF'
1	1	infra	false	✦ Working
EOF

PATH="$bin_dir:$PATH" \
XDG_RUNTIME_DIR="$tmp/runtime" \
ZELLIJ_SESSION_NAME=watcher-test \
FAKE_ZELLIJ_TABS="$tabs" \
  "$watcher" --once

gemini_busy_name="$(awk -F '\t' '$1 == 1 { print $4 }' "$tabs")"
if [[ "$gemini_busy_name" != "infra 🤖" ]]; then
  printf 'Expected Gemini busy marker, got %s\n' "$gemini_busy_name" >&2
  exit 1
fi

cat > "$tabs" <<'EOF'
1	0	true	infra 🤖
EOF

cat > "$panes" <<'EOF'
1	1	infra 🤖	false	◇ Ready
EOF

PATH="$bin_dir:$PATH" \
XDG_RUNTIME_DIR="$tmp/runtime" \
ZELLIJ_SESSION_NAME=watcher-test \
FAKE_ZELLIJ_TABS="$tabs" \
  "$watcher" --once

gemini_ready_name="$(awk -F '\t' '$1 == 1 { print $4 }' "$tabs")"
if [[ "$gemini_ready_name" != "infra" ]]; then
  printf 'Expected Gemini ready marker cleanup, got %s\n' "$gemini_ready_name" >&2
  exit 1
fi

cat > "$tabs" <<'EOF'
1	0	true	infra 🤖
EOF

cat > "$panes" <<'EOF'
1	1	infra 🤖	false	✋ Action Required
EOF

PATH="$bin_dir:$PATH" \
XDG_RUNTIME_DIR="$tmp/runtime" \
ZELLIJ_SESSION_NAME=watcher-test \
FAKE_ZELLIJ_TABS="$tabs" \
  "$watcher" --once

gemini_action_required_name="$(awk -F '\t' '$1 == 1 { print $4 }' "$tabs")"
if [[ "$gemini_action_required_name" != "infra" ]]; then
  printf 'Expected Gemini action-required marker cleanup, got %s\n' "$gemini_action_required_name" >&2
  exit 1
fi

cat > "$tabs" <<'EOF'
1	0	true	infra
EOF

cat > "$panes" <<'EOF'
1	1	infra	false	⠋ codex
EOF

PATH="$bin_dir:$PATH" \
XDG_RUNTIME_DIR="$tmp/runtime" \
ZELLIJ_SESSION_NAME=watcher-test \
FAKE_ZELLIJ_TABS="$tabs" \
  "$watcher" --once

cat > "$tabs" <<'EOF'
1	0	false	infra 🤖
EOF

cat > "$panes" <<'EOF'
1	1	infra 🤖	false	workspace
EOF

PATH="$bin_dir:$PATH" \
XDG_RUNTIME_DIR="$tmp/runtime" \
ZELLIJ_SESSION_NAME=watcher-test \
FAKE_ZELLIJ_TABS="$tabs" \
  "$watcher" --once

notify_name="$(awk -F '\t' '$1 == 1 { print $4 }' "$tabs")"
if [[ "$notify_name" != "infra 🔔" ]]; then
  printf 'Expected notification marker, got %s\n' "$notify_name" >&2
  exit 1
fi

PATH="$bin_dir:$PATH" \
XDG_RUNTIME_DIR="$tmp/runtime" \
ZELLIJ_SESSION_NAME=watcher-test \
FAKE_ZELLIJ_TABS="$tabs" \
  "$watcher" --reset

reset_name="$(awk -F '\t' '$1 == 1 { print $4 }' "$tabs")"
if [[ "$reset_name" != "infra" ]]; then
  printf 'Expected reset marker cleanup, got %s\n' "$reset_name" >&2
  exit 1
fi
