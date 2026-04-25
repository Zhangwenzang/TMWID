# TellMeWhenItsDone — 桌面气泡设计文档

## 概述

一个基于 SwiftUI + Lottie 的 macOS 桌面气泡应用，实时监控多个 Claude Code 窗口的任务状态，通过三种动画（Working / Done / Ask）告知用户当前进度。解决多窗口场景下用户无法实时感知 AI 进度的问题。

## 架构

### 通信机制

**本地文件监听**。每个 Claude Code 窗口通过 Hook 向共享状态目录写入 JSON 文件。

- 状态目录：`~/.tellmewhenitsdone/state/`
- 每个会话一个文件：`{session_id}.json`
- 气泡应用监听该目录的文件系统事件（FSEvent）

### 状态文件格式

```json
{
  "sessionId": "unique-session-id",
  "status": "working",
  "timestamp": 1777129857,
  "windowTitle": "Claude - project-name"
}
```

`status` 取值：
- `working` — AI 正在工作
- `done` — 任务完成
- `ask` — 需要用户确认/审批

### Hook 配置

气泡应用启动时自动编辑 Claude Code 的 `settings.json` hooks，注入以下条目：

| Hook 事件 | 匹配条件 | 动作 |
|-----------|---------|------|
| `Start` | — | 写入 `{"status": "working", ...}` |
| `Stop` | — | 写入 `{"status": "done", ...}` |
| `PreToolUse` | `AskUserQuestion` | 写入 `{"status": "ask", ...}` |
| `Notification` | `permission_prompt` | 写入 `{"status": "ask", ...}` |

写入命令示例（通过 `echo` 追加到状态文件，原子写入避免竞态）：
```bash
echo '{"sessionId":"abc","status":"done","timestamp":1777129857}' > ~/.tellmewhenitsdone/state/abc.json
```

## 气泡应用架构

### SwiftUI 组件

```
TellMeWhenItsDoneApp
├── AppState (ObservableObject)
│   ├── sessions: [SessionState]
│   └── workingCount / doneCount / askCount
├── ContentView
│   ├── StatusBarBubble (可收起模式)
│   │   ├── CollapsedView (菜单栏小图标/小挂栏)
│   │   └── ExpandedView (展开的气泡)
│   │       ├── StatusCard(.working)
│   │       │   ├── Lottie animation (WORKING)
│   │       │   └── count badge
│   │       ├── StatusCard(.done)
│   │       │   ├── Lottie animation (workdone)
│   │       │   └── count badge
│   │       └── StatusCard(.ask)
│   │           ├── Lottie animation (AUQ)
│   │           └── count badge
│   └── SessionListSheet (展开后可选)
└── StateFileWatcher
    └── FSEventStream → parse JSON → update AppState
```

### Lottie 动画

三个 MP4 文件需转换为 Lottie JSON 格式：
- `WORKING.mp4` → `working.json`（循环播放）
- `workdone.mp4` → `done.json`（播放一次）
- `AUQ.mp4` → `ask.json`（播放一次，带突出效果）

转换方式：使用 `lottie-ios` 提供的 `LottieConverter` 或通过 Lottie Files CLI 工具。

## UI 行为

### 三种状态卡片

每种状态独立显示为一个卡片模块：
- 有数据时才显示，无数据时隐藏
- 最多同时显示三个卡片
- 每个卡片包含：Lottie 动画 + 计数数字 + 状态标签

### 尺寸与常驻

- 默认小尺寸展开，能看清动画内容
- 支持收起为菜单栏小图标/小挂栏
- 支持展开为完整气泡
- 始终浮动在其他窗口上方（`NSWindow.Level.floating`）

### 状态优先级

当状态发生变化时：
- `ask` 状态卡片有额外的高亮/脉冲效果以突出
- 三种状态卡片独立显示，不互相覆盖
- Done 状态在用户确认后自动消失（从文件列表移除对应 session）

## 错误处理

- 状态文件不存在/损坏：跳过该 session，记录日志
- 状态目录不存在：自动创建
- Hook 已存在：不重复注入，检测已有配置
- 气泡应用崩溃重启：重新扫描状态目录恢复状态

## 测试

- 单元测试：状态文件解析、计数聚合逻辑
- 集成测试：模拟多个 session 文件写入，验证气泡状态更新
- UI 测试：Lottie 动画播放、窗口浮动层级、收起/展开交互
