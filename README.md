# 🧭 Zellij Workspaces

Reusable, profile-based Zellij workspace tooling. The scripts in this directory
are generic; project-specific profiles live outside this directory, such as
`config/zellij/` in the parent workspace.

## 🚀 Getting Started

### 🛠️ Install Tooling

From this directory:

```bash
goob install
```

This installs the shared Zellij helpers and shell integration.

If `goob` is not installed yet, run the source installer once:

```bash
./install.sh
```

### 📦 Create Repo Config

Create `config/zellij/profile.conf` and `config/zellij/main.tabs` with sane
defaults:

```bash
goob init
```

Create one workspace with custom tabs:

```bash
goob init app server infra docs
```

Create multiple workspaces:

```bash
goob init frontend=app,ui,tools backend=infra,api,db
```

Overwrite existing generated config:

```bash
goob init --force frontend=app,ui backend=infra,api
```

### ▶️ Open A Workspace

Open the default workspace. If `./config/zellij` exists, `goob` installs or
refreshes it automatically before opening Zellij:

```bash
goob
```

Open a named workspace:

```bash
goob default
```

Open a named session or override the root directory:

```bash
goob frontend -s sketch-api-2
goob frontend -r /custom/workspace/path
goob frontend -s sketch-api-2 -r /custom/workspace/path
```

List available workspaces:

```bash
goob ls
```

### ✅ Check Setup

Validate the install and profile:

```bash
goob doctor
```

## 🧰 Commands

### Friend-Facing Commands

```bash
goob install                           # Install shared tooling
goob init                              # Create config/zellij with defaults
goob init app server infra docs        # Create main.tabs with custom tabs
goob init frontend=app backend=api,db  # Create multiple workspaces
goob setup --config /path/to/profile   # Install/link a profile explicitly
goob doctor                            # Check install and current profile
goob ls                                # List workspaces
goob ps                                # List running Zellij sessions
goob kill <session>                    # Kill a running session
goob                                   # Open default workspace
goob <workspace>                       # Open a workspace
goob <workspace> -s <session>          # Open named session
goob <workspace> -r <root>             # Override root directory
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

A profile is a directory with inert config data and tab lists. In normal repos,
this lives at `config/zellij/`:

```text
config/zellij/
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

`goob init` defaults to:

```text
name=<current-directory-name>
root=<current-directory-path>
default_workspace=main
default_workspaces=main
```

with `main.tabs`:

```text
app
server
infra
scratch
```

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
bash tests/goob-init.test.sh
bash tests/goob.test.sh
bash tests/zellij-workspace-init.test.sh
```
