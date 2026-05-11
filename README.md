# Claude Dash

A tiny Mac dashboard for your Claude Code sessions. Lists recent projects, marks the ones that are currently running, and resumes them in [Ghostty](https://ghostty.org) with one click.

## Requirements

- macOS 14+
- Swift 5.9+ toolchain
- Ghostty installed at `/Applications/Ghostty.app`

## Build & run

```
./build_app.sh && open ClaudeDash.app
```

## What it does

- Scans `~/.claude/projects/` for session JSONL files
- Polls running `claude` processes every 5s to mark active sessions green
- Right-click a row to rename a project; names persist under `~/Library/Application Support/ClaudeDash/`
- Resume launches `claude --resume <id>` in a new Ghostty window
- Lives in the menu bar too, with a popover of the same data
