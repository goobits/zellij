# Zellij Workspaces

Profile-based Zellij workspace tooling. The core scripts are generic; project-specific profiles live outside this repo or under `examples/`.

## Install

From this repo:

```bash
./install.sh
```

Then install or create a profile and run:

```bash
zwork <profile> <workspace>
```

For example:

```bash
ZELLIJ_PROFILE_DIR="$PWD/examples" zwork basic-website default
```

## What It Installs

- `~/.config/zellij/config.kdl`
- `~/.local/bin/zwork`
- `~/.local/bin/zellij-launch-session`
- `~/.local/bin/zellij-open-session`
- `~/.local/bin/zellij-render-layout`
- `~/.local/bin/zellij-saved-session-order`
- `~/.local/bin/zellij-live-tab-order`
- `~/.local/bin/.zellij-agent-tab-watcher`
- a marked shell block in `~/.zshrc` and `~/.bashrc`

If `zellij` is missing, the installer downloads pinned Zellij `0.44.3` for Linux/macOS arm64 or x86_64. Set `ZELLIJ_INSTALL_BINARY=0` to skip that step.

The config keeps mouse wheel scrolling enabled, disables Ctrl-wheel pane resizing, and uses focus-follows-mouse so the pane under the pointer receives scroll focus.

Generated layouts keep the top tab bar visible and hide Zellij's bottom status/control bar.

Links are easiest to open with the terminal's modified-click gesture, usually `Shift`+click or Command-click depending on the terminal. Zellij keeps OSC8 hyperlinks enabled and mouse click-through on, but when mouse mode is active the terminal may still require `Shift` to bypass Zellij mouse capture.

Serialized sessions restore panes as shells instead of foreground apps. This keeps tabs alive when `Ctrl+C` exits tools such as Codex.

Inside Zellij, the installer wraps `codex` with `--no-alt-screen` so Codex output lands in normal Zellij scrollback. It also disables terminal XON/XOFF flow control so `Ctrl+s` can enter Zellij scroll mode instead of freezing terminal output.

Text selection does not copy automatically. Use `Super c`, `Alt c`, or `Ctrl y` to copy the active Zellij selection. On macOS, Command-key shortcuts only work when the terminal passes them through as Super; otherwise the terminal app handles Command+C/Command+V itself. Configure Option to send Meta/Esc for `Alt c` if Super is unavailable.

For the most Mac-like editing behavior, let the terminal app keep standard Command shortcuts such as Command+C, Command+V, Command+L, and Command+Left/Right. Configure Option as Meta/Esc so Option+Left/Right reaches the shell for word movement. The Zellij config unbinds the common Alt navigation shortcuts that would otherwise steal those keys.

## Profiles

A profile is a directory with a `profile.conf` file and one or more `<workspace>.tabs` files:

```text
profiles/my-site/
  profile.conf
  backend.tabs
  frontend.tabs
```

`profile.conf` is parsed as inert `key=value` data, not sourced as shell code. Supported keys:

```text
root=/workspace
```

Tab files are the source of truth for workspace layout. Layout KDL is generated from the tab file at launch time.

## Sessions

`zwork my-site backend` opens or resumes `backend` with the tabs listed in `profiles/my-site/backend.tabs`.

When an existing session is resumed, the launcher moves these named tabs back into layout order and saves the corrected session. Extra ad-hoc tabs are left after the named layout tabs.

Pass a session name to either launcher to create or attach to a named variant:

```bash
zwork my-site backend backend-test
```

When run from inside an existing Zellij client, these launchers switch sessions in place instead of nesting a second Zellij client.

## Agent Tab Status

The hidden watcher marks tabs with `🤖` while an agent pane reports active work. When work finishes on a background tab, it switches to `🔔` until that tab is viewed. It polls every `0.25s` by default.

The watcher supports Codex spinner titles, Gemini's dynamic working title (`✦`), and Claude Code's in-pane working status.

Debug current watcher status:

```bash
ZELLIJ_SESSION_NAME=backend ~/.local/bin/.zellij-agent-tab-watcher --status
ZELLIJ_SESSION_NAME=backend ~/.local/bin/.zellij-agent-tab-watcher --log 40
ZELLIJ_SESSION_NAME=backend ~/.local/bin/.zellij-agent-tab-watcher --watcher-log 40
```

Clear stale robot or bell markers:

```bash
ZELLIJ_SESSION_NAME=backend ~/.local/bin/.zellij-agent-tab-watcher --reset
```

Restart the watcher after changing this setup:

```bash
ZELLIJ_SESSION_NAME=backend ~/.local/bin/.zellij-agent-tab-watcher --restart
```

Tune polling:

```bash
ZELLIJ_AGENT_TAB_WATCHER_POLL_SECONDS=0.5 zwork my-site backend
```

Log every title change:

```bash
ZELLIJ_AGENT_TAB_WATCHER_DEBUG_TITLES=1 zwork my-site backend
```

## Maintenance Checks

Run these after changing the zellij setup:

```bash
bash -n bin/* install.sh tests/*.sh
bash tests/zellij-install-files.test.sh
bash tests/zellij-launch-session.test.sh
bash tests/zellij-agent-tab-watcher.test.sh
bash tests/zellij-session-tab-order.test.sh
bash tests/zellij-session-specs.test.sh
```
