# Embedding Zellij Workspaces

This repo is split into generic scripts and project-local profiles. To embed it in another project, keep this shape:

```text
zellij-workspaces/
  bin/
    zwork
    zellij-agent-tab-watcher
    zellij-launch-session
    zellij-open-session
    zellij-render-layout
    zellij-session-tab-order
    zellij-live-tab-order
    zellij-saved-session-order
    goob
    zellij-workspace-init
    zellij-workspace-doctor
  examples/
    basic-website/
  tests/
    goob-create.test.sh
  install.sh
  README.md
```

Keep project-specific tab lists in profile directories:

```text
config/zellij/
  profile.conf
  main.tabs
```

Do not source `profile.conf`; parse it as inert `key=value` data.
