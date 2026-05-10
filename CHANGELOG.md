# Changelog / 更新日志

## 1.3.15 - 2026-05-10

### 新增 / Added

- 新增 Codex hook 支持，可与 Claude Code 同时工作，并自动设置 Codex feature flag 与 hook 文件。
- Added Codex hook support alongside Claude Code, including Codex feature-flag setup and hook file creation.
- 新增 API Error / 接口异常状态，包括专属 `apiErr` 动画、菜单栏数量、泡泡状态项、菜单项和声音优先级。
- Added API-error status support with a dedicated `apiErr` animation, menu bar count, bubble item, menu item, and sound priority.
- 悬浮泡泡支持 hover 展开会话列表，每个状态都可以查看对应会话。
- Added hover session lists in the floating bubble so each status can reveal the matching sessions.
- 动画资源加载增加 fallback，支持 release bundle 中的 flat PNG 和 imageset 布局。
- Added a resource lookup fallback for flat PNG and imageset-style animation assets.

### 变更 / Changed

- 调整悬浮泡泡布局：可见内容固定在稳定宿主窗口的左上角。
- Updated the floating bubble layout so visible content is pinned to the top-left of a stable host window.
- 外层窗口预留展开尺寸，鼠标移入/移出时不再改变 macOS 窗口外框。
- Reserved the expanded bubble host frame up front, preventing hover enter/leave from resizing the outer macOS window.
- 移除 hover 导致的图标偏移和窗口 resize 插值动画，避免边缘看起来漂移。
- Removed hover-driven icon offsets and resize interpolation that could make the bubble edge appear to drift.
- README 改为中英双语，并补充 Claude Code、Codex、接口异常状态和稳定悬浮泡泡说明。
- Updated README installation and behavior documentation for Claude Code, Codex, API-error status, and the stable bubble.

### 修复 / Fixed

- 修复 hover 展开/收起时，SwiftUI 内容被 `NSWindow` 中间尺寸裁切导致的闪烁。
- Fixed hover expansion and collapse flicker where SwiftUI content could be clipped by an intermediate `NSWindow` size.
- 修复悬浮泡泡在 hover 过渡中顶部和左侧边缘不稳定的问题。
- Fixed top and left edge instability during bubble hover transitions.
- 修复 release 包中 API-error 动画帧加载失败的问题。
- Fixed packaged API-error frame loading by supporting the resource layout used inside the release bundle.

### 验证 / Verified

- `swift test` 通过：97 个测试。
- `swift test` passes: 97 tests.
- `packaging/build-release.sh 1.3.15` 成功生成 `dist/Tmwid-1.3.15.dmg`。
- `packaging/build-release.sh 1.3.15` produces `dist/Tmwid-1.3.15.dmg`.

## 1.2.2 - 2026-04-30

- 上一个公开版本。
- Previous public release.
