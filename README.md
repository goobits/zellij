# 🧭 goob: Zellij Workspaces

Reusable, zero-friction Zellij workspace tooling.

`goob` provides sane defaults for managing complex terminal environments. It lets
you define project layouts in plain text, then handles session management,
auto-linking, and layout generation for you.

The goal: **Clone a repo, type `goob`, and get to work.**

## 🚀 Getting Started

### 1. Global Install

Install the shared tooling once. From this repository directory, run:

```bash
./install.sh
```

If `zellij` is missing, this downloads pinned Zellij `0.44.3` for your
architecture. Set `ZELLIJ_INSTALL_BINARY=0` to skip binary installation.

### 2. Create A Workspace

In any project directory, assign a workspace name to a comma-separated tab list.
If `config/zellij/` does not exist, `goob` creates the profile first.

```bash
# Create a project profile with one workspace named main
goob main=app,server,infra,scratch

# Add another workspace
goob frontend=app,ui,tools

# Rename a workspace
goob rename frontend app-ui

# Add or replace a workspace in an existing project
goob backend=infra,api,db

# Open the workspace when you want a shell
goob backend
```

### 3. Daily Usage

When a project has `config/zellij/`, `goob` auto-detects it. You do not need to
manually link or install profiles for normal repos.

```bash
# Open the default workspace
goob

# Open a specific workspace
goob frontend

# Create, add, or replace a local workspace, then sync a matching session
goob now=tools,components,scratch

# Open a workspace in a named session
goob frontend -s sketch-api

# Open a workspace with a different root directory
goob frontend -r /custom/workspace/path

# Combine flags; order does not matter
goob frontend -s sketch-api -r /custom/workspace/path
```

### 4. Visibility And Management

```bash
goob list         # List available workspaces in the current project
goob ps           # List running Zellij sessions
goob kill <name>  # Kill a specific session
goob rename <old> <new>
goob doctor       # Validate the install and current profile config
```

### 5. Live Tab Management

Workspace names can also manage their live Zellij tabs. Indexed tab specs use
zero-based positions, so `keyboard@1` places `keyboard` at the second tab.

```bash
goob front list
goob front add keyboard
goob front add keyboard@1
goob front remove keyboard
goob front focus keyboard
goob front move keyboard@1
```

## 📁 How Profiles Work

A profile is a directory of inert config data that `goob` reads to build your
environment.

```text
my-project/config/zellij/
  profile.conf
  frontend.tabs
  backend.tabs
```

`profile.conf` sets project defaults:

```text
name=my-project
root=/workspace
default_workspace=frontend
default_workspaces=frontend backend
```

`*.tabs` files define workspace layouts. Each line is a tab name. You can
optionally set a tab working directory with a tab-separated second column:

```text
app
server	/workspace/server
scratch
```

`goob <workspace>` works for any `<workspace>.tabs` file. Workspace names such
as `frontend` and `backend` are conventions, not special cases.

Creating the first workspace writes:

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

## ✨ Quality Of Life Features

### 🤖 Agent Tab Status

`goob` includes a hidden watcher that marks tabs while background agents or
scripts are working:

- `🤖` means an agent or script is actively working.
- `🔔` means work finished on a background tab; it disappears when you view the
  tab.

Reset or inspect the watcher for a session:

```bash
ZELLIJ_SESSION_NAME=frontend ~/.local/bin/.zellij-agent-tab-watcher --restart
ZELLIJ_SESSION_NAME=frontend ~/.local/bin/.zellij-agent-tab-watcher --status
ZELLIJ_SESSION_NAME=frontend ~/.local/bin/.zellij-agent-tab-watcher --log 40
```

Tune polling:

```bash
ZELLIJ_AGENT_TAB_WATCHER_POLL_SECONDS=0.5 goob frontend
```

### 🧠 Smart Session Resumption

Existing sessions are preserved. When you resume a session, `goob` moves core
profile tabs back into their configured order. Extra ad-hoc tabs stay at the
end.

If you run `goob` from inside an existing Zellij client, it switches sessions in
place instead of nesting a second client.

Serialized sessions restore panes as shells instead of foreground apps. This
keeps tabs alive when `Ctrl+C` exits tools such as Codex.

### 🍎 macOS Notes And Keybinds

For Mac-like editing, let your terminal app handle standard shortcuts such as
Command+C, Command+V, Command+L, and Command+Left/Right. Configure Option as
Meta/Esc so Option+Left/Right reaches the shell for word movement.

The config maps standard Mac delete behaviors:

- `Alt + Backspace`: Delete previous word
- `Super + Backspace`: Delete current line

Text selection does not copy automatically. Use `Super c`, `Alt c`, or `Ctrl y`
to copy the active Zellij selection.

The config keeps mouse wheel scrolling enabled, disables Ctrl-wheel pane
resizing, and uses focus-follows-mouse so the pane under the pointer receives
scroll focus.

## 🧰 Under The Hood

`goob` installs helper commands into `~/.local/bin/`. You usually do not need to
touch these directly, but they are available for scripting:

- `goob`
- `zwork <profile> <workspace> [session] [workdir]`
- `zellij-workspace-init`
- `zellij-workspace-doctor`
- `zellij-launch-session`
- `zellij-open-session`
- `zellij-render-layout`
- `zellij-saved-session-order`
- `zellij-live-tab-order`
- `zellij-session-tab-order`
- `.zellij-agent-tab-watcher`

It also installs:

- `~/.config/zellij/config.kdl`
- a marked shell block in `~/.zshrc` and `~/.bashrc`

## ✅ Maintenance Checks

Run these after changing the Zellij setup:

```bash
bash -n bin/* install.sh tests/*.sh
bash tests/zellij-install-files.test.sh
bash tests/zellij-launch-session.test.sh
bash tests/zellij-agent-tab-watcher.test.sh
bash tests/zellij-session-tab-order.test.sh
bash tests/zellij-session-specs.test.sh
bash tests/goob-create.test.sh
bash tests/goob.test.sh
bash tests/zellij-workspace-init.test.sh
```
