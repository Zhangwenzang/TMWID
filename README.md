# TellMeWhenItsDone

macOS menu bar app that shows your Claude Code sessions' status via pixel-art animations.

## Install

```bash
swift build -c release
cp .build/release/Tmwid /usr/local/bin/tmwid
tmwid &
```

First launch will inject hooks into `~/.claude/settings.json`. Existing hooks are preserved.

## Uninstall

Click menu bar icon -> "Uninstall hooks".

## States

- Working -- AI is processing
- Ask -- Needs your input (approval / question)
- Done -- Task completed

## Files

- `~/.tmwid/state/` -- session state files (cleaned automatically)
- `~/.tmwid/backups/` -- settings.json backups (last 5)
- `~/.claude/settings.json` -- where hooks are injected (with `# tmwid-v1-hook` marker)

## Development

```bash
swift build        # debug build
swift test         # run tests (requires Xcode)
swift build -c release  # production build
```
