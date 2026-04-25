# TellMeWhenItsDone — 菜单栏 App 设计文档

## 概述

一个 macOS 菜单栏 App，以无边框透明窗口 + Lottie 动画的形式展示 Claude Code 会话状态。后台监听本地状态文件，当有状态变化时弹出对应动画，点击可跳回对应的终端窗口。解决多窗口场景下用户无法实时感知 AI 进度的问题。

## 架构

### 通信机制

**本地文件监听**。每个 Claude Code 窗口通过 Hook 向共享状态目录写入 JSON 文件。

- 状态目录：`~/.tellmewhenitsdone/state/`
- 每个会话一个文件：`{session_id}.json`
- App 监听该目录的文件系统事件（`DispatchSourceFileSystemObject`）

### 状态文件格式

```json
{
  "sessionId": "unique-session-id",
  "status": "working",
  "timestamp": 1777129857,
  "terminalPid": 12345
}
```

`status` 取值：
- `working` — AI 正在工作
- `done` — 任务完成
- `ask` — 需要用户确认/审批

### Hook 配置

App 首次启动时自动编辑 Claude Code 的 `~/.claude/settings.json` hooks，注入以下条目：

| Hook 事件 | 匹配条件 | 动作 |
|-----------|---------|------|
| `Start` | — | 写入 `{"status": "working", ...}` |
| `Stop` | — | 写入 `{"status": "done", ...}` |
| `PreToolUse` | `AskUserQuestion` | 写入 `{"status": "ask", ...}` |
| `Notification` | `permission_prompt` | 写入 `{"status": "ask", ...}` |

写入命令示例：
```bash
echo '{"sessionId":"abc","status":"done","timestamp":1777129857}' > ~/.tellmewhenitsdone/state/abc.json
```

## App 架构

### macOS 菜单栏 App 模式

- 使用 `MenuBarExtra`（macOS 13+）或自定义 `NSStatusItem` 实现菜单栏图标
- 点击菜单栏图标或收到新状态时，弹出无边框窗口

### 弹出窗口

```
SwiftUI Window
├── .windowStyle(.hiddenTitleBar)
├── .background(.clear) / .opacity(0)
├── .resizable(false)
└── ContentView
    ├── AnimationDisplay (当前活跃状态)
    │   ├── LottieView(working.json) — 循环播放
    │   ├── LottieView(done.json) — 播放一次
    │   └── LottieView(ask.json) — 播放一次
    ├── CountBadges (各状态计数)
    │   ├── WorkingBadge (count)
    │   ├── DoneBadge (count)
    │   └── AskBadge (count, 脉冲高亮)
    └── ClickHandler → 跳回对应终端窗口
```

### Lottie 动画

三个 MP4 文件需转换为 Lottie JSON（`.lottie` 或 `.json`）格式：
- `WORKING.mp4` → `working.json`（循环播放）
- `workdone.mp4` → `done.json`（播放一次）
- `AUQ.mp4` → `ask.json`（播放一次，带突出效果）

转换方案：
1. **AE + Bodymovin**：设计师用 After Effects 重新制作动画，导出为 Lottie
2. **MP4 → GIF → Lottie**：通过 LottieFiles CLI 或第三方工具链（如 `lottie-converter` npm 包）
3. **手动制作**：在 LottieFiles 上找相似动画，微调替换

使用 `lottie-ios`（`Lottie` SPM 包）在 SwiftUI 中播放。

### 核心功能

1. **后台监听**：监听 `~/.tellmewhenitsdone/state/` 目录变化，实时更新内部状态
2. **弹窗动画**：状态变化时弹出/更新窗口，播放对应 Lottie 动画
3. **点击跳回**：点击动画窗口时，通过 `terminalPid` 或 `osascript` 激活对应的终端窗口

## UI 行为

### 状态展示

- 三种状态独立显示计数 badge（有数据才出现）
- 动画在窗口中央播放，计数在下方或侧边排列
- `ask` 状态有额外脉冲高亮效果

### 窗口行为

- 默认：菜单栏显示状态图标
- 收到新状态时：自动弹出动画窗口
- 点击窗口：激活对应终端窗口
- 无活跃会话时：窗口自动隐藏

## 错误处理

- 状态文件不存在/损坏：跳过该 session，记录日志
- 状态目录不存在：自动创建
- Hook 已存在：不重复注入，检测已有配置
- App 崩溃重启：重新扫描状态目录恢复状态
- 终端窗口已关闭：点击时不执行跳转

## 测试

- 单元测试：状态文件解析、计数聚合逻辑
- 集成测试：模拟多个 session 文件写入，验证窗口状态更新
- UI 测试：Lottie 动画播放、窗口透明度、点击跳转行为
