# Tell Me When It's Done

Tmwid is a macOS menu bar app that shows Claude Code and Codex session status with pixel-art animations, sounds, and a floating frosted-glass bubble.

## Install

Download the latest DMG from Releases, open it, and drag `Tmwid.app` to `/Applications`.

For local development builds:

```bash
packaging/build-release.sh 1.3.15
open dist/Tmwid-1.3.15.dmg
```

On first launch, Tmwid installs its own hooks for supported tools while preserving user-authored hooks:

- Claude Code: `~/.claude/settings.json` with the `# tmwid-v2-hook` marker
- Codex: `~/.codex/config.toml` and `~/.codex/hooks.json`

## What It Shows

- `Working` -- the AI session is processing.
- `Ask` -- the session needs your input or approval.
- `Done` -- the task completed.
- `API Error` -- the tool reported an API or credit-limit failure.

The menu bar label and floating bubble show a count for each active status. Hover over a status in the bubble to see matching sessions, then click a session row to activate its app window.

## Floating Bubble

The floating bubble is anchored from its top-left edge. Hover expansion keeps the outer window frame stable and expands only the visible content area, preventing clipped intermediate frames or edge jitter during mouse enter/leave.

The minimize button hides the bubble while keeping the menu bar indicator available.

## 菜单栏图标位置

Tmwid 默认显示在第三方应用图标区，受启动顺序和你装了多少其他菜单栏工具影响，**有时会被挤到比较靠左、容易被忽略甚至被刘海挡住的位置**。

> **建议把图标拖到偏右边的位置（靠近时钟那侧）**：按住 `⌘` 拖动 Tmwid 图标即可，系统会记住位置。

如果用了 Bartender / Hidden Bar 之类的菜单栏整理工具，记得把 Tmwid 设为常驻显示。

## Uninstall Hooks

Click the menu bar icon and choose `Uninstall hooks`.

This removes only Tmwid-managed hooks and leaves user-authored hooks intact.

## Files

- `~/.tmwid/state/` -- session state files, cleaned automatically.
- `~/.tmwid/backups/` -- Claude settings backups, retaining the latest five.
- `~/.claude/settings.json` -- Claude Code hook configuration.
- `~/.codex/hooks.json` -- Codex hook configuration.
- `~/.codex/config.toml` -- Codex feature flag configuration.

## Development

```bash
swift build
swift test
packaging/build-release.sh 1.3.15
```

The Swift package has two targets:

- `Tmwid` -- testable library code for core logic, view models, views, animation, and resources.
- `TmwidApp` -- thin macOS app wiring.
