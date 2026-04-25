# TellMeWhenItsDone — 菜单栏 App 设计文档

## 概述

一个 macOS 菜单栏 App，以无边框毛玻璃窗口 + 帧动画的形式展示 Claude Code 会话状态。后台监听本地状态文件，当有状态变化时弹出对应动画，点击可跳回对应的终端窗口。解决多窗口场景下用户无法实时感知 AI 进度的问题。

## 架构

### 通信机制

**本地文件监听**。每个 Claude Code 窗口通过注入的 Hook 向共享状态目录写入 JSON 文件。

- 状态目录：`~/.tmwid/state/`
- 每个会话一个文件：`{session_id}.json`
- App 监听该目录的文件系统事件（`DispatchSourceFileSystemObject`）

### 状态文件格式

```json
{
  "sessionId": "unique-session-id",
  "status": "working",
  "cwd": "/path/to/project",
  "pid": 12345,
  "ts": 1777129857
}
```

`status` 取值：
- `working` — AI 正在工作
- `done` — 任务完成
- `ask` — 需要用户确认/审批

字段说明：
- `sessionId` — Claude Code 会话的 UUID，全局唯一
- `pid` — Claude Code 进程 PID（从 hook 的 `$PPID` 获取），用于健康检查
- `ts` — Unix 秒级时间戳，用于检测 stale session
- `cwd` — 项目路径，用于展示和点击跳转

## Hook 注入机制（方案 A：内嵌 shell 脚本）

### 目标文件

**只操作 `~/.claude/settings.json`**（标准 Claude Code 全局配置）。

**不需要兼容的文件**：
- `~/.claude/zyb-settings.json` — zcode（作业帮 Claude Code fork）私有配置，不包含 hooks 字段
- `~/.claude/settings.local.json` — 本地覆盖配置，hooks 较少使用
- 项目级 `.claude/settings.json` — 每项目单独注入成本高，全局注入覆盖 99% 场景

### Hook 事件映射

| 状态 | Hook 事件 | matcher | 说明 |
|------|----------|---------|------|
| `working` | `UserPromptSubmit` | — | 用户提交 prompt，AI 开始干活 |
| `done` | `Stop` | — | AI 完成响应 |
| `ask` | `PreToolUse` | `AskUserQuestion` | 主动向用户提问 |
| `ask` | `Notification` | `permission_prompt` | 请求权限确认 |
| 清理 | `SessionEnd` | — | 会话结束，删除状态文件 |

**不使用 `SessionStart`**：会话打开 ≠ AI 在工作，使用 `UserPromptSubmit` 更准确。

### Marker 机制

每条注入的 hook 条目的 `command` 字段以固定 marker 起头：

```
# tmwid-v1-hook
<shell 脚本>
```

Marker 带版本号（`v1`），便于未来升级识别旧版本并替换。

### 注入流程

App 启动时：

1. 读取 `~/.claude/settings.json`
2. 备份到 `~/.tmwid/backups/settings-{timestamp}.json`（保留最近 5 份）
3. 遍历 `hooks.{Event}.hooks[]`，查找带 `tmwid-v1-hook` marker 的条目
4. 分类处理：
   - **不存在** → 追加新条目
   - **存在且内容一致** → 跳过
   - **存在但 marker 过时**（`tmwid-v0-hook` 等旧版本） → 替换为新版
5. 用临时文件 + `rename()` 原子写入 settings.json
6. 写入失败 → 保留原文件，App UI 提示"注入失败"并给出手动修复指引

**幂等性**：重复运行注入流程不会产生重复条目。

### Hook Command 内容

以 `working` 状态为例：

```bash
# tmwid-v1-hook
input=$(cat)
sid=$(printf '%s' "$input" | /usr/bin/jq -r '.session_id // empty')
cwd=$(printf '%s' "$input" | /usr/bin/jq -r '.cwd // empty')
[ -z "$sid" ] && exit 0
dir="$HOME/.tmwid/state"
mkdir -p "$dir"
tmp="$dir/$sid.json.tmp.$$"
printf '{"sessionId":"%s","status":"working","cwd":"%s","pid":%d,"ts":%d}\n' \
  "$sid" "$cwd" "$PPID" "$(date +%s)" > "$tmp" && mv "$tmp" "$dir/$sid.json"
exit 0
```

关键点：
- `mv` 原子写入，避免 UI 读到半写状态
- `exit 0` 保证 hook 失败不阻塞 Claude Code
- `jq` 使用绝对路径 `/usr/bin/jq`，避免 PATH 污染
- `$$` 作为 tmp 后缀，防止并发冲突

`done` 和 `ask` 脚本结构相同，仅 status 字段不同。

`SessionEnd` 只需一行：`rm -f "$HOME/.tmwid/state/$sid.json"`。

### 还原

App 设置界面提供"卸载"按钮：
- 遍历所有 hooks，移除带 `tmwid-v1-hook` marker 的条目
- 空的 hooks 对象清理掉
- 保留用户自己的其他 hooks 不动

## 监听机制

### 文件系统事件

App 用 `DispatchSourceFileSystemObject` 监听 `~/.tmwid/state/` 目录：

```swift
let fd = open(stateDir, O_EVTONLY)
let src = DispatchSource.makeFileSystemObjectSource(
  fileDescriptor: fd,
  eventMask: [.write, .delete, .rename],
  queue: .main
)
src.setEventHandler { rescan() }
src.resume()
```

零 polling，内核级通知，几乎无开销。

### 状态聚合

每次事件触发时：

1. 读取目录内所有 `.json` 文件
2. 逐个解析为 `SessionState` 对象
3. 跳过解析失败的文件（损坏文件在纠错阶段清理）
4. 按 `status` 分组计算 working/done/ask 的 count
5. 用 diff 更新 UI，避免全量刷新引起的闪烁

## 纠错机制（防失准）

### 1. Claude Code 进程崩溃 → 卡在 working

**对策**：健康检查定时器，每 15 秒扫描所有 `working` 状态 session：

- `session.ts < now - 600` → stale（超过 10 分钟未更新）
- `kill(pid, 0) != 0` → 进程已死

stale/dead 的 session：
- 删除对应 `~/.tmwid/state/{id}.json`
- UI 计数自动减少

### 2. 用户手动编辑 settings.json 删掉 hook

**对策**：
- App 启动时校验 marker 存在性，缺失则重新注入
- 后台每小时做一次轻量校验
- 不打断用户使用

### 3. 状态文件损坏/磁盘异常

**对策**：
- JSON 解析失败的文件 → 自动删除
- 写入用 `mv` 原子操作，天然防"写一半"
- UI 用固定排序 + diff 更新，避免闪烁

### 4. 多窗口并发

`session_id` 是 Claude Code 会话全局唯一 UUID，不冲突。
同一 session 内串行触发 hook 时，`mv` 的原子性保证读到的是完整版本。

### 5. Hook 格式/schema 变更

**对策**：
- Marker 带版本号（`tmwid-v1-hook` → `tmwid-v2-hook`）
- App 启动时检测旧版 marker，替换为新版
- 保留旧版兼容至少一个版本周期

### 6. zcode 与标准 Claude Code 并存

**对策**：zcode 也读 `~/.claude/settings.json`，hook 机制相同，一次注入两个都生效。
zyb-settings.json 不触碰，不会影响 zcode 的登录/更新等功能。

## App 架构

### 菜单栏 App 模式

- 使用 `MenuBarExtra`（macOS 13+）实现菜单栏图标
- 点击菜单栏图标或收到新状态时，弹出无边框毛玻璃窗口
- 窗口样式：`.windowStyle(.hiddenTitleBar)`、`.background(.ultraThinMaterial)`、`NSWindow.Level.floating`

### UI 组件

```
TmwidApp
├── AppState (ObservableObject)
│   ├── sessions: [SessionState]
│   └── workingCount / doneCount / askCount
├── MenuBarExtra (系统菜单栏图标)
│   └── CollapsedView (图标 + 计数)
├── FloatingWindow (无边框毛玻璃弹窗)
│   └── BubbleContentView
│       ├── StatusCard(.working) — 帧动画 + count（仅 count > 0 时显示）
│       ├── StatusCard(.done) — 帧动画 + count
│       └── StatusCard(.ask) — 帧动画 + count
├── StateFileWatcher — FSEvent 监听
├── SettingsInjector — hook 注入/卸载
└── HealthChecker — 15 秒定时器，stale session 清理
```

### 帧动画

三个 MP4 文件已抽帧为 PNG 关键帧，不使用 Lottie：

- `assets/frames/working_key/` — 14 帧（打字动作，10fps 循环）
- `assets/frames/workdone_key/` — 10 帧（摸鱼动作，6fps 循环）
- `assets/frames/auq_key/` — 12 帧（招手提问，8fps 循环）

SwiftUI 用 `Image(name) + Timer` 切换帧。总资源体积约 490KB。

### 核心功能

1. **后台监听**：FSEvent 监听 `~/.tmwid/state/` 变化，实时更新
2. **弹窗动画**：状态变化时弹出/更新窗口，播放对应帧动画
3. **点击跳回**：点击卡片 → 通过 `pid` 或 `cwd` 激活对应终端窗口（`NSRunningApplication` 或 `osascript`）

## UI 行为

### 状态展示

- 三种状态独立显示（有数据才出现），按 working / ask / done 顺序排列
- **单层视觉结构**：毛玻璃容器直接承载动画+数字，不加内层卡片背景
- 每个状态项：帧动画（48×48，像素风格）+ 计数数字（垂直布局）
- 数字统一用 `#ffffff`（白色带轻微阴影），不区分颜色
- 状态项之间用 `gap: 14px` 做间距区分
- Ask 状态的挥手动作本身已足够吸引注意，**不加外围脉冲**

### 窗口行为

- 默认：菜单栏显示图标 + 各状态小计数
- 收到新状态时：自动弹出气泡窗口
- 点击状态项：激活对应终端窗口
- 无活跃会话时：气泡窗口自动隐藏（菜单栏图标仍在）

## 目录结构

```
~/.claude/
  └── settings.json             ← 用户原配置 + 注入的 tmwid hooks

~/.tmwid/
  ├── state/                    ← 会话状态文件（由 hook 写入）
  │   ├── abc-123.json
  │   └── def-456.json
  ├── backups/                  ← settings.json 备份（最近 5 份）
  │   └── settings-2026-04-25-14-30-22.json
  └── app.log                   ← JSON Lines 调试日志
```

## 错误处理

- 状态文件不存在/损坏：跳过该 session，记录日志，定时清理
- 状态目录不存在：自动创建
- Hook 已存在：通过 marker 识别幂等处理
- settings.json 写入失败：保留原文件 + UI 提示
- App 崩溃重启：重新扫描状态目录恢复状态
- 终端窗口已关闭：点击时静默不跳转

## 测试

- 单元测试：
  - 状态文件解析、计数聚合
  - Hook marker 识别与注入幂等性
  - stale session 判定逻辑
- 集成测试：
  - 模拟多个 session 并发写入，验证 UI 状态更新
  - 模拟 Claude Code 崩溃（kill -9），验证 health check 清理
  - 模拟 settings.json 被用户手动修改后重新注入
- UI 测试：
  - 帧动画播放流畅度
  - 窗口浮动层级、毛玻璃效果
  - 点击跳转行为

## 未来扩展（非本期范围）

以下功能在 MVP 稳定后再规划，**不写入本期实施计划**：

- **付费购买**：License 校验层、支付渠道选择、购买恢复等。预计作为独立 App 层加入，与核心架构解耦。
- **多平台支持**：Windows / Linux 客户端
- **Claude Code 以外的 AI 工具适配**：Cursor、Aider 等
- **会话列表详情**：展开气泡后显示每个会话的标题、路径、运行时长
- **声音自定义**：替换当前 hook 里的系统音效
- **云端同步**：跨设备同步会话状态（需要服务端）
