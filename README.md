# 🧭 Zellij Workspaces

Reusable, profile-based Zellij workspace tooling. The scripts in this directory
are generic; project-specific profiles live outside this directory, such as
`config/zellij/` in the parent workspace.

## 🚀 Getting Started

### 🛠️ Install Tooling

From this directory:

```bash
./install.sh
```

This installs the shared Zellij helpers and shell integration.

### 📦 Install A Profile

Install any profile directory that contains `profile.conf` and one or more
`*.tabs` files:

```bash
goob setup --config "$PWD/examples/basic-website"
```

### ▶️ Open A Workspace

Open the default workspace:

```bash
goob
```

Open a named workspace:

```bash
goob default
```

List available workspaces:

```bash
goob list
```

### ✅ Check Setup

Validate the install and profile:

```bash
goob doctor --config "$PWD/examples/basic-website"
```

## 🧰 Commands

### Friend-Facing Commands

```bash
goob setup --config /path/to/profile   # Install a profile
goob doctor --config /path/to/profile  # Check install and profile
goob list                              # List installed workspaces
goob                                   # Open default workspace
goob <workspace>                       # Open any <workspace>.tabs
goob <workspace> <session>             # Open named session variant
```

### Lower-Level Commands

```bash
zwork <profile> <workspace> [session] [workdir]
zellij-workspace-init --config /path/to/profile
zellij-workspace-doctor --config /path/to/profile
```

Prefer `goob` for normal use. The lower-level commands are kept for scripting,
debugging, and reuse outside this repo.

## 📁 Profiles

A profile is a directory with inert config data and tab lists:

```text
profiles/my-site/
  profile.conf
  frontend.tabs
  backend.tabs
```

`profile.conf` supports:

```text
name=my-site
root=/workspace
default_workspace=frontend
default_workspaces=frontend backend
```

Tab files define workspace layout. Each line is a tab name. A tab may also set a
working directory using a tab-separated second column:

```text
app
server	/workspace/server
scratch
```

`goob <workspace>` works for any installed `<workspace>.tabs` file, so
`frontend` and `backend` are only defaults, not special cases.

## 🧩 What It Installs

- `~/.config/zellij/config.kdl`
- `~/.local/bin/goob`
- `~/.local/bin/zwork`
- `~/.local/bin/zellij-launch-session`
- `~/.local/bin/zellij-open-session`
- `~/.local/bin/zellij-render-layout`
- `~/.local/bin/zellij-saved-session-order`
- `~/.local/bin/zellij-live-tab-order`
- `~/.local/bin/zellij-session-tab-order`
- `~/.local/bin/zellij-workspace-init`
- `~/.local/bin/zellij-workspace-doctor`
- `~/.local/bin/.zellij-agent-tab-watcher`
- a marked shell block in `~/.zshrc` and `~/.bashrc`

If `zellij` is missing, the installer downloads pinned Zellij `0.44.3` for
Linux/macOS arm64 or x86_64. Set `ZELLIJ_INSTALL_BINARY=0` to skip binary
installation.

## 🖥️ Sessions

Existing sessions are preserved. When a session is resumed, the launcher moves
known tabs back into profile order and saves the corrected session. Extra ad-hoc
tabs stay after the profile tabs.

When run from inside an existing Zellij client, `goob` switches sessions in
place instead of nesting a second Zellij client.

Serialized sessions restore panes as shells instead of foreground apps. This
keeps tabs alive when `Ctrl+C` exits tools such as Codex.

## 🤖 Agent Tab Status

The hidden watcher marks tabs with `🤖` while an agent pane reports active work.
When work finishes on a background tab, it switches to `🔔` until that tab is
viewed.

Debug watcher status:

```bash
ZELLIJ_SESSION_NAME=frontend ~/.local/bin/.zellij-agent-tab-watcher --status
ZELLIJ_SESSION_NAME=frontend ~/.local/bin/.zellij-agent-tab-watcher --log 40
ZELLIJ_SESSION_NAME=frontend ~/.local/bin/.zellij-agent-tab-watcher --watcher-log 40
```

Clear stale markers:

```bash
ZELLIJ_SESSION_NAME=frontend ~/.local/bin/.zellij-agent-tab-watcher --reset
```

Restart the watcher:

```bash
ZELLIJ_SESSION_NAME=frontend ~/.local/bin/.zellij-agent-tab-watcher --restart
```

Tune polling:

```bash
ZELLIJ_AGENT_TAB_WATCHER_POLL_SECONDS=0.5 goob frontend
```

## 🍎 macOS Notes

For Mac-like editing, let the terminal app keep standard Command shortcuts such
as Command+C, Command+V, Command+L, and Command+Left/Right. Configure Option as
Meta/Esc so Option+Left/Right reaches the shell for word movement.

The config also maps common Mac delete behavior:

- `Alt Backspace`: delete previous word
- `Super Backspace`: delete current line

Text selection does not copy automatically. Use `Super c`, `Alt c`, or `Ctrl y`
to copy the active Zellij selection.

## 🔗 Links And Mouse

The config keeps mouse wheel scrolling enabled, disables Ctrl-wheel pane
resizing, and uses focus-follows-mouse so the pane under the pointer receives
scroll focus.

Links are easiest to open with the terminal's modified-click gesture, usually
`Shift`+click or Command-click depending on the terminal.

## ✅ Maintenance Checks

Run these after changing the Zellij setup:

```bash
bash -n bin/* install.sh tests/*.sh
bash tests/zellij-install-files.test.sh
bash tests/zellij-launch-session.test.sh
bash tests/zellij-agent-tab-watcher.test.sh
bash tests/zellij-session-tab-order.test.sh
bash tests/zellij-session-specs.test.sh
bash tests/goob.test.sh
bash tests/zellij-workspace-init.test.sh
```
