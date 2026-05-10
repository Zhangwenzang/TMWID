# Release Notes / 发布说明

## Tmwid 1.3.15

发布日期：2026-05-10

Release date: 2026-05-10

### 亮点 / Highlights

Tmwid 1.3.15 增加了 Codex 支持，在 Claude Code 之外也能追踪会话状态；新增接口异常状态；并彻底稳定了悬浮泡泡的 hover 展开/收起效果，避免出现被裁切或跳动的中间帧。

Tmwid 1.3.15 expands support beyond Claude Code by adding Codex hook integration, introduces a dedicated API-error state, and stabilizes the floating bubble so hover enter/leave no longer produces clipped or jumpy intermediate frames.

### 用户可见变化 / User-Facing Changes

- Claude Code 和 Codex 会话都可以把状态写入 Tmwid。
- Claude Code and Codex sessions can both write status into Tmwid.
- API、额度或请求失败会作为独立的“接口异常”状态展示，并使用专属动画。
- API and credit-limit failures are surfaced as a separate status with their own animation.
- 菜单栏和悬浮泡泡状态图标现在会显示数量。
- The menu bar and bubble status icons now show counts.
- 鼠标悬停在泡泡状态上，可以展开查看对应会话列表。
- Hovering a bubble status reveals the matching session list.
- 点击会话行可以激活对应应用窗口。
- Clicking a listed session activates its app window.
- 悬浮泡泡在展开和收起时保持左上角稳定，不再出现边缘抖动。
- The floating bubble keeps its top-left edge stable during hover expansion and collapse.

### 修复 / Fixes

- 移除了 SwiftUI 内容变化和 AppKit 窗口 resize 不同步导致的 hover 闪烁。
- Removed the hover flicker caused by SwiftUI content changing size while the AppKit host window was still resizing.
- 防止收起时出现“窄而高”的裁切中间帧。
- Prevented the narrow-and-tall clipped intermediate frame seen during bubble collapse.
- 修复 release 包内动画资源加载，包含 `apiErr` 帧。
- Fixed animation loading for packaged release resources, including `apiErr` frames.

### 安装 / Install

打开 `Tmwid-1.3.15.dmg`，把 `Tmwid.app` 拖到 `/Applications`。

Open `Tmwid-1.3.15.dmg` and drag `Tmwid.app` to `/Applications`.

### 验证 / Verification

```bash
swift test
packaging/build-release.sh 1.3.15
```

release 构建成功，测试套件 97 个测试全部通过。

The release build completed successfully and the test suite passed with 97 tests.
