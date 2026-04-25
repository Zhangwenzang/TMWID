# TellMeWhenItsDone 实施进度

> **恢复上下文的方法**：读取这个文件 + `docs/superpowers/plans/2026-04-25-tellmewhenitsdone.md` + `docs/superpowers/specs/2026-04-25-tellmewhenitsdone-desktop-bubble-design.md`，即可无损恢复。

## 工作区

- **Worktree**：`/Users/zhangwencang/CodeBuddy/Tellmewhenitsdone/.worktrees/tmwid-impl`
- **Branch**：`tmwid-impl`
- **所有后续命令都在此 worktree 内执行**

## 环境约束（重要）

1. **Agent 子代理不可用** —— `CLAUDE_CODE_SUBAGENT_MODEL=claude-opus-4-6` 被网关拒绝，所有 `Agent` 工具调用返回 400。后续只能在主会话执行。
2. **Xcode 未安装** —— 机器只有 Command Line Tools，`swift test` 因缺少 XCTest 失败。**library + executable 构建可通过**（`swift build` OK）。测试需要用户装 Xcode 后自己跑 `swift test` 验证。
3. **主会话模型**：`zyb-high[1m]`（网关 `ccproxy.zuoyebang.cc`）

## 状态快照

| # | Task | 状态 | Commit |
|---|------|------|--------|
| 0 | Worktree 创建 | ✅ | — |
| 1 | Swift Package 初始化 | 🟡 代码写完, build ✅, test 因环境阻塞 | 未提交 |
| 2 | SessionState + StatusKind | ⏳ | — |
| 3 | Paths 常量 | ⏳ | — |
| 4 | SettingsInjector markers | ⏳ | — |
| 5 | SettingsInjector read+backup | ⏳ | — |
| 6 | SettingsInjector install | ⏳ | — |
| 7 | SettingsInjector uninstall | ⏳ | — |
| 8 | StateFileWatcher | ⏳ | — |
| 9 | HealthChecker | ⏳ | — |
| 10 | AppState | ⏳ | — |
| 11 | Assets 导入 | ⏳ | — |
| 12 | FrameAnimator | ⏳ | — |
| 13 | StatusItemView | ⏳ | — |
| 14 | BubbleContent | ⏳ | — |
| 15 | BubbleWindow | ⏳ | — |
| 16 | App 组装 | ⏳ | — |
| 17 | 端到端手动测试 | ⏳ | — |
| 18 | README | ⏳ | — |

## 关键决策与偏离原计划的调整

### Task 1 调整

- 原计划：单一 executable target `Tmwid`，测试 target 依赖它
- 问题：executable target 里 `@main App` 导致 `@testable import Tmwid` 在 Xcode 缺失环境下无法编译测试
- 调整：**拆成两个 target**
  - `Tmwid` (library) — `Sources/Tmwid/` 放所有可测代码
  - `TmwidApp` (executable) — `Sources/TmwidApp/` 只放 `App.swift`
  - `TmwidTests` 依赖 library `Tmwid`
- 影响：后续所有代码文件放在 `Sources/Tmwid/` 下（不是 `Sources/TmwidApp/`），App.swift 单独放 `Sources/TmwidApp/`。

### 测试执行策略

- 缺 Xcode，`swift test` 本地跑不通
- 策略：代码照常写 + 写测试文件，但**跳过 "运行测试看失败/通过" 步骤**，全部批量提交后，用户装完 Xcode 自己跑 `swift test`
- 每个 Task 只做：写代码 + 写测试文件 + `swift build` 验证语法 + commit

## 待办（按优先级）

1. 把 Task 1 的代码 commit（现在未提交）
2. 继续 Task 2 - SessionState + StatusKind
3. ...（按 plan 顺序）

## 恢复上下文 Checklist

当你在新会话接手时，按顺序做：

1. `cd /Users/zhangwencang/CodeBuddy/Tellmewhenitsdone/.worktrees/tmwid-impl`
2. `git log --oneline -20` 看已提交的任务
3. 读本文件 "状态快照" 章节
4. 读 `docs/superpowers/plans/2026-04-25-tellmewhenitsdone.md` 找下一个 ⏳ 任务的详细步骤
5. 执行那个任务 → 更新本文件的状态表 → commit
6. 如果已完成 2-3 个任务，提醒用户 `/compact`

## 开发规则

- **所有路径用绝对路径或从 worktree 根目录的相对路径**
- **每完成一个 Task 必须 commit**（plan 里定义的 commit message）
- **commit message 前缀**：`feat: ` / `docs: ` / `fix: `
- **写代码时**：遵循 Tmwid library / TmwidApp executable 的分割
