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

## 菜单栏图标位置

Tmwid 默认显示在第三方应用图标区，受启动顺序和你装了多少其他菜单栏工具影响，**有时会被挤到比较靠左、容易被忽略甚至被刘海挡住的位置**。

> **建议把图标拖到偏右边的位置（靠近时钟那侧）**：按住 ⌘ 拖动 Tmwid 图标即可，系统会记住位置。

如果用了 Bartender / Hidden Bar 之类的菜单栏整理工具，记得把 Tmwid 设为常驻显示。

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
