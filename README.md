# Tell Me When It's Done

Tmwid 是一个 macOS 菜单栏应用，用像素动画、提示音和悬浮毛玻璃泡泡展示 Claude Code 与 Codex 会话状态。

Tmwid is a macOS menu bar app that shows Claude Code and Codex session status with pixel-art animations, sounds, and a floating frosted-glass bubble.

## 安装 / Install

从 GitHub Releases 下载最新 DMG，打开后把 `Tmwid.app` 拖到 `/Applications`。

Download the latest DMG from GitHub Releases, open it, and drag `Tmwid.app` to `/Applications`.

本地开发打包：

```bash
packaging/build-release.sh 1.3.15
open dist/Tmwid-1.3.15.dmg
```

首次启动时，Tmwid 会为支持的工具安装自己的 hooks，同时保留用户原有 hooks：

On first launch, Tmwid installs its own hooks for supported tools while preserving user-authored hooks:

- Claude Code：写入 `~/.claude/settings.json`，使用 `# tmwid-v2-hook` 标记
- Codex：写入 `~/.codex/config.toml` 和 `~/.codex/hooks.json`

## 状态说明 / Statuses

- `Working` / 工作中：AI 会话正在处理任务。
- `Ask` / 需要确认：会话需要你的输入、授权或确认。
- `Done` / 已完成：任务已经完成。
- `API Error` / 接口异常：工具遇到 API、额度或请求失败。

菜单栏和悬浮泡泡都会显示每种状态的数量。鼠标悬停在泡泡里的某个状态上，可以展开查看对应会话；点击会话行可以激活对应的应用窗口。

The menu bar label and floating bubble show a count for each active status. Hover over a status in the bubble to see matching sessions, then click a session row to activate its app window.

## 悬浮泡泡 / Floating Bubble

悬浮泡泡以左上角为稳定锚点。展开和收起时，外层 macOS 窗口尺寸保持稳定，只切换左上角可见内容，避免鼠标移入/移出时出现裁切、抖动或边缘漂移。

The floating bubble is anchored from its top-left edge. Hover expansion keeps the outer window frame stable and changes only the visible content area, preventing clipped intermediate frames or edge jitter during mouse enter/leave.

点击泡泡右上角的最小化按钮可以隐藏悬浮泡泡，菜单栏状态仍会保留。

The minimize button hides the bubble while keeping the menu bar indicator available.

## 菜单栏图标位置 / Menu Bar Icon Position

Tmwid 默认显示在第三方应用图标区，受启动顺序和你装了多少其他菜单栏工具影响，**有时会被挤到比较靠左、容易被忽略甚至被刘海挡住的位置**。

> **建议把图标拖到偏右边的位置（靠近时钟那侧）**：按住 `⌘` 拖动 Tmwid 图标即可，系统会记住位置。

如果用了 Bartender / Hidden Bar 之类的菜单栏整理工具，记得把 Tmwid 设为常驻显示。

Tmwid appears in the third-party app area of the macOS menu bar. If you use Bartender, Hidden Bar, or similar tools, keep Tmwid visible so status changes are easy to notice.

## 卸载 Hooks / Uninstall Hooks

点击菜单栏图标，选择 `Uninstall hooks`。

Click the menu bar icon and choose `Uninstall hooks`.

这个操作只会移除 Tmwid 管理的 hooks，不会删除用户自己写的 hooks。

This removes only Tmwid-managed hooks and leaves user-authored hooks intact.

## 文件位置 / Files

- `~/.tmwid/state/` -- 会话状态文件，会自动清理。
- `~/.tmwid/backups/` -- Claude settings 备份，保留最近 5 份。
- `~/.claude/settings.json` -- Claude Code hook 配置。
- `~/.codex/hooks.json` -- Codex hook 配置。
- `~/.codex/config.toml` -- Codex feature flag 配置。

## 开发 / Development

```bash
swift build
swift test
packaging/build-release.sh 1.3.15
```

Swift package 包含两个 target：

- `Tmwid` -- 可测试的 library，包含 core logic、view model、view、animation 和 resources。
- `TmwidApp` -- macOS app 的轻量启动和 wiring。

The Swift package has two targets:

- `Tmwid` -- testable library code for core logic, view models, views, animation, and resources.
- `TmwidApp` -- thin macOS app wiring.
