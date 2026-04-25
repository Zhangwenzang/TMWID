# TellMeWhenItsDone Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个 macOS 菜单栏 App，通过 Hook 注入+文件监听实时展示多个 Claude Code 会话的工作状态（working/done/ask），用帧动画+毛玻璃气泡显示。

**Architecture:** Swift Package Manager 管理的 SwiftUI macOS App。Hook 写入 JSON 到 `~/.tmwid/state/` → FSEvent 监听 → AppState 聚合 → MenuBarExtra + 无边框毛玻璃窗口展示。

**Tech Stack:** Swift 5.9+, SwiftUI, MenuBarExtra (macOS 13+), DispatchSourceFileSystemObject (FSEvent), XCTest, swift-format。

---

## File Structure

```
Tellmewhenitsdone/
├── Package.swift                          # SPM manifest
├── Sources/
│   └── Tmwid/
│       ├── App.swift                      # App 入口 + MenuBarExtra
│       ├── Models/
│       │   ├── SessionState.swift         # JSON 解析 + 数据模型
│       │   └── StatusKind.swift           # working/done/ask enum
│       ├── Core/
│       │   ├── StateFileWatcher.swift     # FSEvent 监听
│       │   ├── SettingsInjector.swift     # Hook 注入/卸载
│       │   ├── HealthChecker.swift        # Stale session 清理
│       │   └── Paths.swift                # 路径常量（~/.tmwid/*）
│       ├── ViewModels/
│       │   └── AppState.swift             # ObservableObject 聚合状态
│       ├── Views/
│       │   ├── MenuBarView.swift          # 菜单栏小图标视图
│       │   ├── BubbleWindow.swift         # 无边框毛玻璃窗口
│       │   ├── BubbleContent.swift        # 气泡内容（状态项列表）
│       │   └── StatusItemView.swift       # 单个状态项（帧动画+数字）
│       ├── Animation/
│       │   └── FrameAnimator.swift        # 帧动画 ObservableObject
│       └── Resources/
│           └── Assets.xcassets/           # PNG 关键帧资源
└── Tests/
    └── TmwidTests/
        ├── SessionStateTests.swift
        ├── SettingsInjectorTests.swift
        ├── HealthCheckerTests.swift
        └── AppStateTests.swift
```

**单元职责**：
- `SessionState` — JSON 模型，纯数据，无副作用
- `Paths` — 所有路径常量集中在一处，方便测试 override
- `StateFileWatcher` — 只负责监听并发出变更信号，不做聚合
- `SettingsInjector` — 只负责 settings.json 读写，不关心 UI
- `HealthChecker` — 只负责检测和清理 stale session
- `AppState` — 汇聚前三者，对外暴露 `@Published` 属性
- View 层 — 只读 AppState，不直接操作 Core

---

## Task 1: 初始化 Swift Package

**Files:**
- Create: `Package.swift`
- Create: `Sources/Tmwid/App.swift`
- Create: `Tests/TmwidTests/SmokeTest.swift`

- [ ] **Step 1: 创建 Package.swift**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Tmwid",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Tmwid", targets: ["Tmwid"]),
    ],
    targets: [
        .executableTarget(
            name: "Tmwid",
            path: "Sources/Tmwid",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "TmwidTests",
            dependencies: ["Tmwid"],
            path: "Tests/TmwidTests"
        ),
    ]
)
```

- [ ] **Step 2: 创建最小 App 入口**

```swift
// Sources/Tmwid/App.swift
import SwiftUI

@main
struct TmwidApp: App {
    var body: some Scene {
        MenuBarExtra("Tmwid", systemImage: "hare") {
            Text("Hello Tmwid")
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)
    }
}
```

- [ ] **Step 3: 创建 smoke test**

```swift
// Tests/TmwidTests/SmokeTest.swift
import XCTest
@testable import Tmwid

final class SmokeTest: XCTestCase {
    func testPackageCompiles() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 4: 运行构建和测试**

Run: `swift build && swift test`
Expected: Build success, 1 test passes.

- [ ] **Step 5: 创建 .gitignore**

```
.build/
.swiftpm/
*.xcodeproj/
DerivedData/
*.DS_Store
```

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources Tests .gitignore
git commit -m "feat: init swift package with menu bar skeleton"
```

---

## Task 2: 定义数据模型（SessionState + StatusKind）

**Files:**
- Create: `Sources/Tmwid/Models/StatusKind.swift`
- Create: `Sources/Tmwid/Models/SessionState.swift`
- Create: `Tests/TmwidTests/SessionStateTests.swift`

- [ ] **Step 1: 写 StatusKind 测试**

```swift
// Tests/TmwidTests/SessionStateTests.swift
import XCTest
@testable import Tmwid

final class StatusKindTests: XCTestCase {
    func testDecodeFromRawStrings() throws {
        XCTAssertEqual(StatusKind(rawValue: "working"), .working)
        XCTAssertEqual(StatusKind(rawValue: "done"), .done)
        XCTAssertEqual(StatusKind(rawValue: "ask"), .ask)
        XCTAssertNil(StatusKind(rawValue: "unknown"))
    }
}
```

- [ ] **Step 2: 运行测试，应该失败**

Run: `swift test --filter StatusKindTests`
Expected: FAIL — `StatusKind` undefined.

- [ ] **Step 3: 实现 StatusKind**

```swift
// Sources/Tmwid/Models/StatusKind.swift
import Foundation

enum StatusKind: String, Codable, CaseIterable, Hashable {
    case working
    case done
    case ask
}
```

- [ ] **Step 4: 运行测试，应该通过**

Run: `swift test --filter StatusKindTests`
Expected: PASS.

- [ ] **Step 5: 写 SessionState 解析测试**

```swift
// 追加到 Tests/TmwidTests/SessionStateTests.swift
final class SessionStateTests: XCTestCase {
    func testDecodeFromJSON() throws {
        let json = #"{"sessionId":"abc","status":"working","cwd":"/tmp","pid":123,"ts":1777000000}"#
        let data = json.data(using: .utf8)!
        let session = try JSONDecoder().decode(SessionState.self, from: data)
        XCTAssertEqual(session.sessionId, "abc")
        XCTAssertEqual(session.status, .working)
        XCTAssertEqual(session.cwd, "/tmp")
        XCTAssertEqual(session.pid, 123)
        XCTAssertEqual(session.ts, 1_777_000_000)
    }

    func testDecodeWithMissingCwd() throws {
        let json = #"{"sessionId":"abc","status":"done","pid":123,"ts":1777000000}"#
        let data = json.data(using: .utf8)!
        let session = try JSONDecoder().decode(SessionState.self, from: data)
        XCTAssertEqual(session.cwd, "")
    }
}
```

- [ ] **Step 6: 运行测试，应该失败**

Run: `swift test --filter SessionStateTests`
Expected: FAIL — `SessionState` undefined.

- [ ] **Step 7: 实现 SessionState**

```swift
// Sources/Tmwid/Models/SessionState.swift
import Foundation

struct SessionState: Codable, Equatable, Identifiable {
    let sessionId: String
    let status: StatusKind
    let cwd: String
    let pid: Int32
    let ts: TimeInterval

    var id: String { sessionId }

    enum CodingKeys: String, CodingKey {
        case sessionId, status, cwd, pid, ts
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try c.decode(String.self, forKey: .sessionId)
        status = try c.decode(StatusKind.self, forKey: .status)
        cwd = (try? c.decode(String.self, forKey: .cwd)) ?? ""
        pid = try c.decode(Int32.self, forKey: .pid)
        ts = try c.decode(TimeInterval.self, forKey: .ts)
    }

    init(sessionId: String, status: StatusKind, cwd: String, pid: Int32, ts: TimeInterval) {
        self.sessionId = sessionId
        self.status = status
        self.cwd = cwd
        self.pid = pid
        self.ts = ts
    }
}
```

- [ ] **Step 8: 运行测试，全部通过**

Run: `swift test`
Expected: PASS (3 tests).

- [ ] **Step 9: Commit**

```bash
git add Sources/Tmwid/Models Tests/TmwidTests/SessionStateTests.swift
git commit -m "feat: add SessionState + StatusKind models"
```

---

## Task 3: 路径常量（Paths）

**Files:**
- Create: `Sources/Tmwid/Core/Paths.swift`
- Create: `Tests/TmwidTests/PathsTests.swift`

- [ ] **Step 1: 写测试**

```swift
// Tests/TmwidTests/PathsTests.swift
import XCTest
@testable import Tmwid

final class PathsTests: XCTestCase {
    func testDefaultPaths() {
        let paths = Paths(home: "/Users/test")
        XCTAssertEqual(paths.claudeSettings, "/Users/test/.claude/settings.json")
        XCTAssertEqual(paths.stateDir, "/Users/test/.tmwid/state")
        XCTAssertEqual(paths.backupsDir, "/Users/test/.tmwid/backups")
        XCTAssertEqual(paths.appLog, "/Users/test/.tmwid/app.log")
    }

    func testStateFile() {
        let paths = Paths(home: "/Users/test")
        XCTAssertEqual(paths.stateFile(for: "abc"), "/Users/test/.tmwid/state/abc.json")
    }
}
```

- [ ] **Step 2: 运行测试，应该失败**

Run: `swift test --filter PathsTests`
Expected: FAIL.

- [ ] **Step 3: 实现 Paths**

```swift
// Sources/Tmwid/Core/Paths.swift
import Foundation

struct Paths {
    let home: String

    init(home: String = NSHomeDirectory()) {
        self.home = home
    }

    var claudeSettings: String { "\(home)/.claude/settings.json" }
    var stateDir: String { "\(home)/.tmwid/state" }
    var backupsDir: String { "\(home)/.tmwid/backups" }
    var appLog: String { "\(home)/.tmwid/app.log" }

    func stateFile(for sessionId: String) -> String {
        "\(stateDir)/\(sessionId).json"
    }
}
```

- [ ] **Step 4: 运行测试，应该通过**

Run: `swift test --filter PathsTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/Tmwid/Core/Paths.swift Tests/TmwidTests/PathsTests.swift
git commit -m "feat: add Paths struct for all filesystem locations"
```

---

## Task 4: SettingsInjector — Marker 识别与幂等注入

**Files:**
- Create: `Sources/Tmwid/Core/SettingsInjector.swift`
- Create: `Tests/TmwidTests/SettingsInjectorTests.swift`

- [ ] **Step 1: 定义 hook marker 常量和 shell 脚本模板**

在 `SettingsInjector.swift` 最上方写：

```swift
// Sources/Tmwid/Core/SettingsInjector.swift
import Foundation

enum HookMarker {
    static let current = "# tmwid-v1-hook"
    static let legacyPrefixes = ["# tmwid-v0-hook"]
}

enum HookTemplate {
    static func scriptForStatus(_ status: String) -> String {
        """
        \(HookMarker.current)
        input=$(cat)
        sid=$(printf '%s' "$input" | /usr/bin/jq -r '.session_id // empty')
        cwd=$(printf '%s' "$input" | /usr/bin/jq -r '.cwd // empty')
        [ -z "$sid" ] && exit 0
        dir="$HOME/.tmwid/state"
        mkdir -p "$dir"
        tmp="$dir/$sid.json.tmp.$$"
        printf '{"sessionId":"%s","status":"\(status)","cwd":"%s","pid":%d,"ts":%d}\\n' \\
          "$sid" "$cwd" "$PPID" "$(date +%s)" > "$tmp" && mv "$tmp" "$dir/$sid.json"
        exit 0
        """
    }

    static let cleanupScript = """
    \(HookMarker.current)
    input=$(cat)
    sid=$(printf '%s' "$input" | /usr/bin/jq -r '.session_id // empty')
    [ -n "$sid" ] && rm -f "$HOME/.tmwid/state/$sid.json"
    exit 0
    """
}
```

- [ ] **Step 2: 写 marker 识别测试**

```swift
// Tests/TmwidTests/SettingsInjectorTests.swift
import XCTest
@testable import Tmwid

final class SettingsInjectorTests: XCTestCase {
    func testIsCurrentTmwidHook() {
        XCTAssertTrue(SettingsInjector.isCurrentTmwidHook("# tmwid-v1-hook\necho hi"))
        XCTAssertFalse(SettingsInjector.isCurrentTmwidHook("afplay /System/Library/Sounds/Glass.aiff"))
    }

    func testIsLegacyTmwidHook() {
        XCTAssertTrue(SettingsInjector.isLegacyTmwidHook("# tmwid-v0-hook\necho hi"))
        XCTAssertFalse(SettingsInjector.isLegacyTmwidHook("# tmwid-v1-hook\necho hi"))
    }
}
```

- [ ] **Step 3: 运行测试，应该失败**

Run: `swift test --filter SettingsInjectorTests`
Expected: FAIL — `SettingsInjector` undefined.

- [ ] **Step 4: 实现 SettingsInjector 骨架**

追加到 `SettingsInjector.swift`：

```swift
final class SettingsInjector {
    let paths: Paths
    init(paths: Paths) { self.paths = paths }

    static func isCurrentTmwidHook(_ command: String) -> Bool {
        command.hasPrefix(HookMarker.current)
    }

    static func isLegacyTmwidHook(_ command: String) -> Bool {
        HookMarker.legacyPrefixes.contains { command.hasPrefix($0) }
    }
}
```

- [ ] **Step 5: 运行测试，应该通过**

Run: `swift test --filter SettingsInjectorTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/Tmwid/Core/SettingsInjector.swift Tests/TmwidTests/SettingsInjectorTests.swift
git commit -m "feat: add SettingsInjector with hook marker constants"
```

---

## Task 5: SettingsInjector — 读取 + 备份

**Files:**
- Modify: `Sources/Tmwid/Core/SettingsInjector.swift`
- Modify: `Tests/TmwidTests/SettingsInjectorTests.swift`

- [ ] **Step 1: 写读取测试**

追加到 `SettingsInjectorTests.swift`：

```swift
func testReadNonExistentSettings() throws {
    let tmp = makeTempDir()
    let injector = SettingsInjector(paths: Paths(home: tmp))
    let settings = try injector.readSettings()
    XCTAssertTrue(settings.isEmpty)
}

func testReadExistingSettings() throws {
    let tmp = makeTempDir()
    try FileManager.default.createDirectory(
        atPath: "\(tmp)/.claude", withIntermediateDirectories: true)
    let json = #"{"model":"claude-opus","hooks":{}}"#
    try json.write(toFile: "\(tmp)/.claude/settings.json", atomically: true, encoding: .utf8)
    let injector = SettingsInjector(paths: Paths(home: tmp))
    let settings = try injector.readSettings()
    XCTAssertEqual(settings["model"] as? String, "claude-opus")
}

private func makeTempDir() -> String {
    let dir = NSTemporaryDirectory() + "tmwid-test-\(UUID().uuidString)"
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    return dir
}
```

- [ ] **Step 2: 运行测试，应该失败**

Run: `swift test --filter SettingsInjectorTests`
Expected: FAIL — `readSettings` undefined.

- [ ] **Step 3: 实现 readSettings 和 backup**

在 `SettingsInjector` 类中追加：

```swift
typealias SettingsJSON = [String: Any]

func readSettings() throws -> SettingsJSON {
    let url = URL(fileURLWithPath: paths.claudeSettings)
    guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
    let data = try Data(contentsOf: url)
    let json = try JSONSerialization.jsonObject(with: data)
    return json as? SettingsJSON ?? [:]
}

func backupSettings() throws {
    guard FileManager.default.fileExists(atPath: paths.claudeSettings) else { return }
    try FileManager.default.createDirectory(
        atPath: paths.backupsDir, withIntermediateDirectories: true)
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withFullDate, .withTime]
    let ts = fmt.string(from: Date()).replacingOccurrences(of: ":", with: "-")
    let dest = "\(paths.backupsDir)/settings-\(ts).json"
    try FileManager.default.copyItem(atPath: paths.claudeSettings, toPath: dest)
    pruneBackups(keeping: 5)
}

private func pruneBackups(keeping n: Int) {
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(atPath: paths.backupsDir) else { return }
    let sorted = files.sorted().filter { $0.hasPrefix("settings-") }
    let excess = sorted.dropLast(n)
    for f in excess {
        try? fm.removeItem(atPath: "\(paths.backupsDir)/\(f)")
    }
}
```

- [ ] **Step 4: 运行测试，应该通过**

Run: `swift test --filter SettingsInjectorTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/Tmwid/Core/SettingsInjector.swift Tests/TmwidTests/SettingsInjectorTests.swift
git commit -m "feat: add settings read + backup logic"
```

---

## Task 6: SettingsInjector — 注入逻辑

**Files:**
- Modify: `Sources/Tmwid/Core/SettingsInjector.swift`
- Modify: `Tests/TmwidTests/SettingsInjectorTests.swift`

- [ ] **Step 1: 写注入测试**

追加到 `SettingsInjectorTests.swift`：

```swift
func testInjectIntoEmptySettings() throws {
    let tmp = makeTempDir()
    let injector = SettingsInjector(paths: Paths(home: tmp))
    try injector.install()
    let settings = try injector.readSettings()
    let hooks = settings["hooks"] as? [String: Any]
    XCTAssertNotNil(hooks?["UserPromptSubmit"])
    XCTAssertNotNil(hooks?["Stop"])
    XCTAssertNotNil(hooks?["PreToolUse"])
    XCTAssertNotNil(hooks?["Notification"])
    XCTAssertNotNil(hooks?["SessionEnd"])
}

func testInjectIsIdempotent() throws {
    let tmp = makeTempDir()
    let injector = SettingsInjector(paths: Paths(home: tmp))
    try injector.install()
    try injector.install()
    let settings = try injector.readSettings()
    let hooks = settings["hooks"] as? [String: Any]
    let stopArr = (hooks?["Stop"] as? [[String: Any]])?.first?["hooks"] as? [[String: Any]]
    let tmwidCount = stopArr?.filter {
        let cmd = $0["command"] as? String ?? ""
        return SettingsInjector.isCurrentTmwidHook(cmd)
    }.count ?? 0
    XCTAssertEqual(tmwidCount, 1)
}

func testInjectPreservesUserHooks() throws {
    let tmp = makeTempDir()
    try FileManager.default.createDirectory(atPath: "\(tmp)/.claude", withIntermediateDirectories: true)
    let existing = """
    {
      "hooks": {
        "Stop": [{"hooks": [{"type":"command","command":"afplay /System/Library/Sounds/Glass.aiff"}]}]
      }
    }
    """
    try existing.write(toFile: "\(tmp)/.claude/settings.json", atomically: true, encoding: .utf8)
    let injector = SettingsInjector(paths: Paths(home: tmp))
    try injector.install()
    let settings = try injector.readSettings()
    let stopGroups = settings["hooks"] as? [String: Any]
    let stopArr = stopGroups?["Stop"] as? [[String: Any]]
    let allCmds = stopArr?.flatMap { ($0["hooks"] as? [[String: Any]]) ?? [] }
        .compactMap { $0["command"] as? String } ?? []
    XCTAssertTrue(allCmds.contains { $0.contains("Glass.aiff") })
    XCTAssertTrue(allCmds.contains { SettingsInjector.isCurrentTmwidHook($0) })
}
```

- [ ] **Step 2: 运行测试，应该失败**

Run: `swift test --filter SettingsInjectorTests`
Expected: FAIL — `install()` undefined.

- [ ] **Step 3: 实现 install()**

在 `SettingsInjector` 类中追加：

```swift
func install() throws {
    try backupSettings()
    var settings = try readSettings()
    var hooks = (settings["hooks"] as? SettingsJSON) ?? [:]

    let injections: [(event: String, matcher: String?, status: String?)] = [
        ("UserPromptSubmit", nil, "working"),
        ("Stop", nil, "done"),
        ("PreToolUse", "AskUserQuestion", "ask"),
        ("Notification", "permission_prompt", "ask"),
        ("SessionEnd", nil, nil),  // cleanup
    ]

    for inj in injections {
        let script = inj.status.map { HookTemplate.scriptForStatus($0) } ?? HookTemplate.cleanupScript
        hooks = upsertHook(
            into: hooks,
            event: inj.event,
            matcher: inj.matcher,
            command: script
        )
    }

    settings["hooks"] = hooks
    try writeSettings(settings)
}

private func upsertHook(
    into hooks: SettingsJSON,
    event: String,
    matcher: String?,
    command: String
) -> SettingsJSON {
    var hooks = hooks
    var eventGroups = (hooks[event] as? [[String: Any]]) ?? []

    // Find a group matching matcher (or no matcher)
    let groupIdx = eventGroups.firstIndex { group in
        let m = group["matcher"] as? String
        return m == matcher
    }

    var targetGroup: [String: Any]
    if let idx = groupIdx {
        targetGroup = eventGroups[idx]
    } else {
        targetGroup = [:]
        if let m = matcher { targetGroup["matcher"] = m }
    }

    var inner = (targetGroup["hooks"] as? [[String: Any]]) ?? []
    let existingIdx = inner.firstIndex { entry in
        let cmd = (entry["command"] as? String) ?? ""
        return Self.isCurrentTmwidHook(cmd) || Self.isLegacyTmwidHook(cmd)
    }
    let newEntry: [String: Any] = ["type": "command", "command": command]
    if let idx = existingIdx {
        inner[idx] = newEntry
    } else {
        inner.append(newEntry)
    }
    targetGroup["hooks"] = inner

    if let idx = groupIdx {
        eventGroups[idx] = targetGroup
    } else {
        eventGroups.append(targetGroup)
    }
    hooks[event] = eventGroups
    return hooks
}

private func writeSettings(_ settings: SettingsJSON) throws {
    try FileManager.default.createDirectory(
        atPath: (paths.claudeSettings as NSString).deletingLastPathComponent,
        withIntermediateDirectories: true
    )
    let data = try JSONSerialization.data(
        withJSONObject: settings,
        options: [.prettyPrinted, .sortedKeys]
    )
    let tmp = paths.claudeSettings + ".tmp.\(getpid())"
    try data.write(to: URL(fileURLWithPath: tmp), options: .atomic)
    _ = rename(tmp, paths.claudeSettings)
}
```

- [ ] **Step 4: 运行测试，应该全部通过**

Run: `swift test --filter SettingsInjectorTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/Tmwid/Core/SettingsInjector.swift Tests/TmwidTests/SettingsInjectorTests.swift
git commit -m "feat: idempotent hook injection into settings.json"
```

---

## Task 7: SettingsInjector — 卸载

**Files:**
- Modify: `Sources/Tmwid/Core/SettingsInjector.swift`
- Modify: `Tests/TmwidTests/SettingsInjectorTests.swift`

- [ ] **Step 1: 写卸载测试**

```swift
func testUninstallRemovesTmwidHooks() throws {
    let tmp = makeTempDir()
    let injector = SettingsInjector(paths: Paths(home: tmp))
    try injector.install()
    try injector.uninstall()
    let settings = try injector.readSettings()
    let hooks = (settings["hooks"] as? [String: Any]) ?? [:]
    for (_, value) in hooks {
        let groups = value as? [[String: Any]] ?? []
        for g in groups {
            let inner = g["hooks"] as? [[String: Any]] ?? []
            for entry in inner {
                let cmd = entry["command"] as? String ?? ""
                XCTAssertFalse(SettingsInjector.isCurrentTmwidHook(cmd))
            }
        }
    }
}

func testUninstallKeepsUserHooks() throws {
    let tmp = makeTempDir()
    try FileManager.default.createDirectory(atPath: "\(tmp)/.claude", withIntermediateDirectories: true)
    let existing = #"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"afplay /System/Library/Sounds/Glass.aiff"}]}]}}"#
    try existing.write(toFile: "\(tmp)/.claude/settings.json", atomically: true, encoding: .utf8)

    let injector = SettingsInjector(paths: Paths(home: tmp))
    try injector.install()
    try injector.uninstall()

    let settings = try injector.readSettings()
    let hooks = settings["hooks"] as? [String: Any]
    let stopArr = hooks?["Stop"] as? [[String: Any]]
    let allCmds = stopArr?.flatMap { ($0["hooks"] as? [[String: Any]]) ?? [] }
        .compactMap { $0["command"] as? String } ?? []
    XCTAssertTrue(allCmds.contains { $0.contains("Glass.aiff") })
}
```

- [ ] **Step 2: 运行测试，应该失败**

Run: `swift test --filter SettingsInjectorTests`
Expected: FAIL — `uninstall()` undefined.

- [ ] **Step 3: 实现 uninstall()**

在 `SettingsInjector` 类中追加：

```swift
func uninstall() throws {
    try backupSettings()
    var settings = try readSettings()
    guard var hooks = settings["hooks"] as? SettingsJSON else { return }

    for event in hooks.keys {
        guard var groups = hooks[event] as? [[String: Any]] else { continue }
        for i in 0..<groups.count {
            var group = groups[i]
            var inner = (group["hooks"] as? [[String: Any]]) ?? []
            inner.removeAll { entry in
                let cmd = (entry["command"] as? String) ?? ""
                return Self.isCurrentTmwidHook(cmd) || Self.isLegacyTmwidHook(cmd)
            }
            group["hooks"] = inner
            groups[i] = group
        }
        // Remove empty groups (no inner hooks and no matcher-specific purpose)
        groups.removeAll { ($0["hooks"] as? [[String: Any]])?.isEmpty ?? true }
        if groups.isEmpty {
            hooks.removeValue(forKey: event)
        } else {
            hooks[event] = groups
        }
    }

    if hooks.isEmpty {
        settings.removeValue(forKey: "hooks")
    } else {
        settings["hooks"] = hooks
    }
    try writeSettings(settings)
}
```

- [ ] **Step 4: 运行测试，应该通过**

Run: `swift test --filter SettingsInjectorTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/Tmwid/Core/SettingsInjector.swift Tests/TmwidTests/SettingsInjectorTests.swift
git commit -m "feat: uninstall preserves user hooks"
```

---

## Task 8: StateFileWatcher — 目录监听

**Files:**
- Create: `Sources/Tmwid/Core/StateFileWatcher.swift`
- Create: `Tests/TmwidTests/StateFileWatcherTests.swift`

- [ ] **Step 1: 写测试**

```swift
// Tests/TmwidTests/StateFileWatcherTests.swift
import XCTest
@testable import Tmwid

final class StateFileWatcherTests: XCTestCase {
    func testScanReturnsAllValidSessions() throws {
        let tmp = NSTemporaryDirectory() + "tmwid-watch-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        let s1 = #"{"sessionId":"a","status":"working","cwd":"","pid":1,"ts":1}"#
        let s2 = #"{"sessionId":"b","status":"done","cwd":"","pid":2,"ts":2}"#
        try s1.write(toFile: "\(tmp)/a.json", atomically: true, encoding: .utf8)
        try s2.write(toFile: "\(tmp)/b.json", atomically: true, encoding: .utf8)

        let watcher = StateFileWatcher(directory: tmp)
        let sessions = watcher.scan()
        XCTAssertEqual(sessions.count, 2)
        XCTAssertTrue(sessions.contains { $0.sessionId == "a" })
        XCTAssertTrue(sessions.contains { $0.sessionId == "b" })
    }

    func testScanSkipsCorruptedFiles() throws {
        let tmp = NSTemporaryDirectory() + "tmwid-watch-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        try "not json".write(toFile: "\(tmp)/corrupt.json", atomically: true, encoding: .utf8)
        let good = #"{"sessionId":"a","status":"working","cwd":"","pid":1,"ts":1}"#
        try good.write(toFile: "\(tmp)/a.json", atomically: true, encoding: .utf8)

        let watcher = StateFileWatcher(directory: tmp)
        let sessions = watcher.scan()
        XCTAssertEqual(sessions.count, 1)
    }

    func testStartTriggersCallbackOnFileChange() throws {
        let tmp = NSTemporaryDirectory() + "tmwid-watch-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)

        let watcher = StateFileWatcher(directory: tmp)
        let expectation = XCTestExpectation(description: "callback fires")
        watcher.onChange = { _ in expectation.fulfill() }
        watcher.start()

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            let s = #"{"sessionId":"a","status":"working","cwd":"","pid":1,"ts":1}"#
            try? s.write(toFile: "\(tmp)/a.json", atomically: true, encoding: .utf8)
        }
        wait(for: [expectation], timeout: 2.0)
        watcher.stop()
    }
}
```

- [ ] **Step 2: 运行测试，应该失败**

Run: `swift test --filter StateFileWatcherTests`
Expected: FAIL — `StateFileWatcher` undefined.

- [ ] **Step 3: 实现 StateFileWatcher**

```swift
// Sources/Tmwid/Core/StateFileWatcher.swift
import Foundation

final class StateFileWatcher {
    let directory: String
    var onChange: ([SessionState]) -> Void = { _ in }

    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private let queue = DispatchQueue(label: "tmwid.watcher")

    init(directory: String) {
        self.directory = directory
    }

    func start() {
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        fd = open(directory, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: queue
        )
        src.setEventHandler { [weak self] in
            guard let self = self else { return }
            let sessions = self.scan()
            DispatchQueue.main.async { self.onChange(sessions) }
        }
        src.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fd >= 0 { close(self.fd); self.fd = -1 }
        }
        src.resume()
        source = src
        // Fire once initially
        let initial = self.scan()
        DispatchQueue.main.async { self.onChange(initial) }
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    func scan() -> [SessionState] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: directory) else { return [] }
        var results: [SessionState] = []
        for f in files where f.hasSuffix(".json") {
            let path = "\(directory)/\(f)"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { continue }
            if let s = try? JSONDecoder().decode(SessionState.self, from: data) {
                results.append(s)
            } else {
                // Corrupted file: delete it
                try? fm.removeItem(atPath: path)
            }
        }
        return results
    }
}
```

- [ ] **Step 4: 运行测试，应该通过**

Run: `swift test --filter StateFileWatcherTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/Tmwid/Core/StateFileWatcher.swift Tests/TmwidTests/StateFileWatcherTests.swift
git commit -m "feat: add StateFileWatcher with FSEvent"
```

---

## Task 9: HealthChecker — 清理 stale session

**Files:**
- Create: `Sources/Tmwid/Core/HealthChecker.swift`
- Create: `Tests/TmwidTests/HealthCheckerTests.swift`

- [ ] **Step 1: 写测试**

```swift
// Tests/TmwidTests/HealthCheckerTests.swift
import XCTest
@testable import Tmwid

final class HealthCheckerTests: XCTestCase {
    func testRemovesStaleWorkingSessions() throws {
        let tmp = NSTemporaryDirectory() + "tmwid-health-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        let oldTs = Date().timeIntervalSince1970 - 1000
        let stale = #"{"sessionId":"a","status":"working","cwd":"","pid":1,"ts":\#(oldTs)}"#
        try stale.write(toFile: "\(tmp)/a.json", atomically: true, encoding: .utf8)

        let checker = HealthChecker(directory: tmp, staleThreshold: 600, processExists: { _ in true })
        checker.runOnce()
        XCTAssertFalse(FileManager.default.fileExists(atPath: "\(tmp)/a.json"))
    }

    func testRemovesSessionsWithDeadPid() throws {
        let tmp = NSTemporaryDirectory() + "tmwid-health-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        let recent = #"{"sessionId":"a","status":"working","cwd":"","pid":99999,"ts":\#(Date().timeIntervalSince1970)}"#
        try recent.write(toFile: "\(tmp)/a.json", atomically: true, encoding: .utf8)

        let checker = HealthChecker(directory: tmp, staleThreshold: 600, processExists: { _ in false })
        checker.runOnce()
        XCTAssertFalse(FileManager.default.fileExists(atPath: "\(tmp)/a.json"))
    }

    func testKeepsHealthySessions() throws {
        let tmp = NSTemporaryDirectory() + "tmwid-health-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        let recent = #"{"sessionId":"a","status":"working","cwd":"","pid":1,"ts":\#(Date().timeIntervalSince1970)}"#
        try recent.write(toFile: "\(tmp)/a.json", atomically: true, encoding: .utf8)

        let checker = HealthChecker(directory: tmp, staleThreshold: 600, processExists: { _ in true })
        checker.runOnce()
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(tmp)/a.json"))
    }

    func testSkipsNonWorkingSessions() throws {
        let tmp = NSTemporaryDirectory() + "tmwid-health-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        let oldDone = #"{"sessionId":"a","status":"done","cwd":"","pid":1,"ts":1}"#
        try oldDone.write(toFile: "\(tmp)/a.json", atomically: true, encoding: .utf8)

        let checker = HealthChecker(directory: tmp, staleThreshold: 600, processExists: { _ in false })
        checker.runOnce()
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(tmp)/a.json"))
    }
}
```

- [ ] **Step 2: 运行测试，应该失败**

Run: `swift test --filter HealthCheckerTests`
Expected: FAIL.

- [ ] **Step 3: 实现 HealthChecker**

```swift
// Sources/Tmwid/Core/HealthChecker.swift
import Foundation

final class HealthChecker {
    let directory: String
    let staleThreshold: TimeInterval
    let processExists: (Int32) -> Bool

    private var timer: DispatchSourceTimer?

    init(
        directory: String,
        staleThreshold: TimeInterval = 600,
        processExists: @escaping (Int32) -> Bool = HealthChecker.defaultProcessExists
    ) {
        self.directory = directory
        self.staleThreshold = staleThreshold
        self.processExists = processExists
    }

    static func defaultProcessExists(pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno != ESRCH
    }

    func startPeriodic(interval: TimeInterval = 15) {
        let t = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        t.schedule(deadline: .now() + interval, repeating: interval)
        t.setEventHandler { [weak self] in self?.runOnce() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func runOnce() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: directory) else { return }
        let now = Date().timeIntervalSince1970
        for f in files where f.hasSuffix(".json") {
            let path = "\(directory)/\(f)"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let s = try? JSONDecoder().decode(SessionState.self, from: data)
            else { continue }

            guard s.status == .working else { continue }
            let isStale = (now - s.ts) > staleThreshold
            let isDead = !processExists(s.pid)
            if isStale || isDead {
                try? fm.removeItem(atPath: path)
            }
        }
    }
}
```

- [ ] **Step 4: 运行测试，应该通过**

Run: `swift test --filter HealthCheckerTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/Tmwid/Core/HealthChecker.swift Tests/TmwidTests/HealthCheckerTests.swift
git commit -m "feat: add HealthChecker for stale session cleanup"
```

---

## Task 10: AppState — 聚合状态

**Files:**
- Create: `Sources/Tmwid/ViewModels/AppState.swift`
- Create: `Tests/TmwidTests/AppStateTests.swift`

- [ ] **Step 1: 写测试**

```swift
// Tests/TmwidTests/AppStateTests.swift
import XCTest
@testable import Tmwid

final class AppStateTests: XCTestCase {
    func testCountsByStatus() {
        let state = AppState()
        state.update(with: [
            SessionState(sessionId: "a", status: .working, cwd: "", pid: 1, ts: 0),
            SessionState(sessionId: "b", status: .working, cwd: "", pid: 2, ts: 0),
            SessionState(sessionId: "c", status: .done, cwd: "", pid: 3, ts: 0),
            SessionState(sessionId: "d", status: .ask, cwd: "", pid: 4, ts: 0),
        ])
        XCTAssertEqual(state.workingCount, 2)
        XCTAssertEqual(state.doneCount, 1)
        XCTAssertEqual(state.askCount, 1)
    }

    func testIsEmptyWhenNoSessions() {
        let state = AppState()
        state.update(with: [])
        XCTAssertTrue(state.isEmpty)
    }

    func testIsNotEmptyWithSessions() {
        let state = AppState()
        state.update(with: [
            SessionState(sessionId: "a", status: .working, cwd: "", pid: 1, ts: 0)
        ])
        XCTAssertFalse(state.isEmpty)
    }

    func testSessionsForStatus() {
        let state = AppState()
        let s1 = SessionState(sessionId: "a", status: .working, cwd: "/x", pid: 1, ts: 0)
        let s2 = SessionState(sessionId: "b", status: .working, cwd: "/y", pid: 2, ts: 0)
        state.update(with: [s1, s2])
        XCTAssertEqual(state.sessions(for: .working).count, 2)
        XCTAssertEqual(state.sessions(for: .done).count, 0)
    }
}
```

- [ ] **Step 2: 运行测试，应该失败**

Run: `swift test --filter AppStateTests`
Expected: FAIL.

- [ ] **Step 3: 实现 AppState**

```swift
// Sources/Tmwid/ViewModels/AppState.swift
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var sessions: [SessionState] = []

    var workingCount: Int { sessions.filter { $0.status == .working }.count }
    var doneCount: Int { sessions.filter { $0.status == .done }.count }
    var askCount: Int { sessions.filter { $0.status == .ask }.count }
    var isEmpty: Bool { sessions.isEmpty }

    func sessions(for kind: StatusKind) -> [SessionState] {
        sessions.filter { $0.status == kind }
    }

    func update(with newSessions: [SessionState]) {
        self.sessions = newSessions.sorted { $0.sessionId < $1.sessionId }
    }
}
```

- [ ] **Step 4: 运行测试，应该通过**

Run: `swift test --filter AppStateTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/Tmwid/ViewModels/AppState.swift Tests/TmwidTests/AppStateTests.swift
git commit -m "feat: add AppState observable for session aggregation"
```

---

## Task 11: 导入帧动画资源到 Assets.xcassets

**Files:**
- Create: `Sources/Tmwid/Resources/Assets.xcassets/Contents.json`
- Create: `Sources/Tmwid/Resources/Assets.xcassets/working-*.imageset/*` (×14)
- Create: `Sources/Tmwid/Resources/Assets.xcassets/done-*.imageset/*` (×10)
- Create: `Sources/Tmwid/Resources/Assets.xcassets/ask-*.imageset/*` (×12)

- [ ] **Step 1: 创建 Assets.xcassets 根 Contents.json**

```bash
mkdir -p Sources/Tmwid/Resources/Assets.xcassets
cat > Sources/Tmwid/Resources/Assets.xcassets/Contents.json <<'EOF'
{
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF
```

- [ ] **Step 2: 用脚本批量生成 imageset 目录**

运行下面的 bash 一次性完成（相对路径为仓库根）：

```bash
SRC_ROOT=assets/frames
DEST=Sources/Tmwid/Resources/Assets.xcassets

import_frames() {
  local kind="$1"
  local src_dir="$2"
  local i=1
  for f in "$src_dir"/*.png; do
    local name=$(printf "%s-%03d" "$kind" "$i")
    local d="$DEST/$name.imageset"
    mkdir -p "$d"
    cp "$f" "$d/$name.png"
    cat > "$d/Contents.json" <<EOF
{
  "images" : [
    { "idiom" : "universal", "filename" : "$name.png" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF
    i=$((i+1))
  done
}

import_frames working "$SRC_ROOT/working_key"
import_frames done    "$SRC_ROOT/workdone_key"
import_frames ask     "$SRC_ROOT/auq_key"
```

- [ ] **Step 3: 验证资源数量**

```bash
ls Sources/Tmwid/Resources/Assets.xcassets | grep -c imageset
```
Expected: 36（14 + 10 + 12）。

- [ ] **Step 4: 运行构建确保资源编译通过**

Run: `swift build`
Expected: Build success.

- [ ] **Step 5: Commit**

```bash
git add Sources/Tmwid/Resources/Assets.xcassets
git commit -m "feat: add frame animation assets (working/done/ask)"
```

---

## Task 12: FrameAnimator — 逐帧切换

**Files:**
- Create: `Sources/Tmwid/Animation/FrameAnimator.swift`
- Create: `Tests/TmwidTests/FrameAnimatorTests.swift`

- [ ] **Step 1: 写测试**

```swift
// Tests/TmwidTests/FrameAnimatorTests.swift
import XCTest
@testable import Tmwid

final class FrameAnimatorTests: XCTestCase {
    func testInitialFrameIsZero() {
        let anim = FrameAnimator(prefix: "working", count: 14, fps: 10)
        XCTAssertEqual(anim.currentFrameName, "working-001")
    }

    func testAdvanceWraps() {
        let anim = FrameAnimator(prefix: "working", count: 3, fps: 10)
        anim.advance(); XCTAssertEqual(anim.currentFrameName, "working-002")
        anim.advance(); XCTAssertEqual(anim.currentFrameName, "working-003")
        anim.advance(); XCTAssertEqual(anim.currentFrameName, "working-001")
    }

    func testFrameNameFormat() {
        let anim = FrameAnimator(prefix: "ask", count: 12, fps: 8)
        XCTAssertEqual(anim.frameName(at: 0), "ask-001")
        XCTAssertEqual(anim.frameName(at: 11), "ask-012")
    }
}
```

- [ ] **Step 2: 运行测试，应该失败**

Run: `swift test --filter FrameAnimatorTests`
Expected: FAIL.

- [ ] **Step 3: 实现 FrameAnimator**

```swift
// Sources/Tmwid/Animation/FrameAnimator.swift
import Foundation
import Combine

@MainActor
final class FrameAnimator: ObservableObject {
    let prefix: String
    let count: Int
    let fps: Double

    @Published private(set) var index: Int = 0

    private var timer: AnyCancellable?

    init(prefix: String, count: Int, fps: Double) {
        self.prefix = prefix
        self.count = max(1, count)
        self.fps = fps
    }

    var currentFrameName: String { frameName(at: index) }

    func frameName(at i: Int) -> String {
        String(format: "%@-%03d", prefix, i + 1)
    }

    func advance() {
        index = (index + 1) % count
    }

    func start() {
        let interval = 1.0 / fps
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.advance() }
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}
```

- [ ] **Step 4: 运行测试，应该通过**

Run: `swift test --filter FrameAnimatorTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/Tmwid/Animation/FrameAnimator.swift Tests/TmwidTests/FrameAnimatorTests.swift
git commit -m "feat: add FrameAnimator for frame-by-frame image cycling"
```

---

## Task 13: StatusItemView — 单个状态项视图

**Files:**
- Create: `Sources/Tmwid/Views/StatusItemView.swift`

- [ ] **Step 1: 实现 StatusItemView**

```swift
// Sources/Tmwid/Views/StatusItemView.swift
import SwiftUI

struct StatusItemView: View {
    let kind: StatusKind
    let count: Int
    @StateObject private var animator: FrameAnimator

    init(kind: StatusKind, count: Int) {
        self.kind = kind
        self.count = count
        let cfg = Self.config(for: kind)
        _animator = StateObject(wrappedValue: FrameAnimator(
            prefix: cfg.prefix, count: cfg.count, fps: cfg.fps))
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(animator.currentFrameName, bundle: .module)
                .resizable()
                .interpolation(.none)  // pixel-perfect
                .frame(width: 48, height: 48)
                .background(Color.white)
                .cornerRadius(6)
            Text("\(count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                .monospacedDigit()
        }
        .onAppear { animator.start() }
        .onDisappear { animator.stop() }
    }

    private static func config(for kind: StatusKind) -> (prefix: String, count: Int, fps: Double) {
        switch kind {
        case .working: return ("working", 14, 10)
        case .done:    return ("done", 10, 6)
        case .ask:     return ("ask", 12, 8)
        }
    }
}
```

- [ ] **Step 2: 运行构建**

Run: `swift build`
Expected: Build success.

- [ ] **Step 3: Commit**

```bash
git add Sources/Tmwid/Views/StatusItemView.swift
git commit -m "feat: add StatusItemView with frame animation"
```

---

## Task 14: BubbleContent — 状态项容器

**Files:**
- Create: `Sources/Tmwid/Views/BubbleContent.swift`

- [ ] **Step 1: 实现 BubbleContent**

```swift
// Sources/Tmwid/Views/BubbleContent.swift
import SwiftUI

struct BubbleContent: View {
    @ObservedObject var state: AppState

    var body: some View {
        HStack(spacing: 14) {
            if state.workingCount > 0 {
                StatusItemView(kind: .working, count: state.workingCount)
            }
            if state.askCount > 0 {
                StatusItemView(kind: .ask, count: state.askCount)
            }
            if state.doneCount > 0 {
                StatusItemView(kind: .done, count: state.doneCount)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }
}
```

- [ ] **Step 2: 运行构建**

Run: `swift build`
Expected: Build success.

- [ ] **Step 3: Commit**

```bash
git add Sources/Tmwid/Views/BubbleContent.swift
git commit -m "feat: add BubbleContent with frosted glass container"
```

---

## Task 15: BubbleWindow — 无边框浮窗

**Files:**
- Create: `Sources/Tmwid/Views/BubbleWindow.swift`

- [ ] **Step 1: 实现 BubbleWindowController**

```swift
// Sources/Tmwid/Views/BubbleWindow.swift
import SwiftUI
import AppKit

final class BubbleWindowController {
    private var window: NSWindow?
    private let state: AppState

    init(state: AppState) {
        self.state = state
    }

    func showIfNeeded() {
        if state.isEmpty {
            hide()
            return
        }
        if window == nil { makeWindow() }
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func makeWindow() {
        let content = BubbleContent(state: state)
        let host = NSHostingView(rootView: content)
        host.frame = NSRect(x: 0, y: 0, width: 240, height: 90)

        let w = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.level = .floating
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.contentView = host
        // Position bottom-right of active screen
        if let screen = NSScreen.main {
            let margin: CGFloat = 20
            let x = screen.visibleFrame.maxX - host.frame.width - margin
            let y = screen.visibleFrame.minY + margin
            w.setFrameOrigin(NSPoint(x: x, y: y))
        }
        window = w
    }
}
```

- [ ] **Step 2: 运行构建**

Run: `swift build`
Expected: Build success.

- [ ] **Step 3: Commit**

```bash
git add Sources/Tmwid/Views/BubbleWindow.swift
git commit -m "feat: add borderless floating bubble window"
```

---

## Task 16: MenuBarView + App 组装

**Files:**
- Create: `Sources/Tmwid/Views/MenuBarView.swift`
- Modify: `Sources/Tmwid/App.swift`

- [ ] **Step 1: 实现 MenuBarView**

```swift
// Sources/Tmwid/Views/MenuBarView.swift
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var state: AppState
    let onQuit: () -> Void
    let onReinject: () -> Void
    let onUninstall: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            if state.isEmpty {
                Text("No active sessions")
            } else {
                if state.workingCount > 0 { Text("Working: \(state.workingCount)") }
                if state.askCount > 0     { Text("Ask: \(state.askCount)") }
                if state.doneCount > 0    { Text("Done: \(state.doneCount)") }
            }
            Divider()
            Button("Re-install hooks", action: onReinject)
            Button("Uninstall hooks", action: onUninstall)
            Divider()
            Button("Quit", action: onQuit)
        }
    }
}
```

- [ ] **Step 2: 组装 App.swift**

```swift
// Sources/Tmwid/App.swift
import SwiftUI

@main
struct TmwidApp: App {
    @StateObject private var state = AppState()
    @State private var paths = Paths()
    @State private var watcher: StateFileWatcher?
    @State private var health: HealthChecker?
    @State private var bubble: BubbleWindowController?
    @State private var injector: SettingsInjector?

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                state: state,
                onQuit: { NSApplication.shared.terminate(nil) },
                onReinject: { try? injector?.install() },
                onUninstall: { try? injector?.uninstall() }
            )
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.menu)
        .onChange(of: state.sessions) { _ in
            bubble?.showIfNeeded()
        }
    }

    private var menuBarLabel: some View {
        Text(labelText)
            .task { setupOnce() }
    }

    private var labelText: String {
        if state.isEmpty { return "💤" }
        var parts: [String] = []
        if state.workingCount > 0 { parts.append("⚙\(state.workingCount)") }
        if state.askCount > 0     { parts.append("❓\(state.askCount)") }
        if state.doneCount > 0    { parts.append("✓\(state.doneCount)") }
        return parts.joined(separator: " ")
    }

    private func setupOnce() {
        let inj = SettingsInjector(paths: paths)
        try? inj.install()
        injector = inj

        let w = StateFileWatcher(directory: paths.stateDir)
        w.onChange = { sessions in
            Task { @MainActor in state.update(with: sessions) }
        }
        w.start()
        watcher = w

        let h = HealthChecker(directory: paths.stateDir)
        h.startPeriodic()
        health = h

        bubble = BubbleWindowController(state: state)
    }
}
```

- [ ] **Step 3: 运行构建**

Run: `swift build`
Expected: Build success.

- [ ] **Step 4: Commit**

```bash
git add Sources/Tmwid/Views/MenuBarView.swift Sources/Tmwid/App.swift
git commit -m "feat: wire up app with menu bar, watcher, and bubble"
```

---

## Task 17: 端到端手动测试

**Files:** N/A（手动验证）

- [ ] **Step 1: 构建 release 版本**

Run: `swift build -c release`
Expected: Build success. 可执行文件位于 `.build/release/Tmwid`。

- [ ] **Step 2: 启动 App**

Run: `.build/release/Tmwid &`
Expected: 菜单栏出现 `💤`（无会话时）。

- [ ] **Step 3: 验证 hook 已注入**

Run: `cat ~/.claude/settings.json | python3 -m json.tool | grep tmwid`
Expected: 输出包含 `# tmwid-v1-hook`。

- [ ] **Step 4: 模拟 working 状态**

```bash
echo '{"sessionId":"manual-test","status":"working","cwd":"/tmp","pid":'$$',"ts":'$(date +%s)'}' > ~/.tmwid/state/manual-test.json
```

Expected: 菜单栏变为 `⚙1`，屏幕右下角出现气泡，Working 动画循环播放。

- [ ] **Step 5: 切换到 ask 状态**

```bash
echo '{"sessionId":"manual-test","status":"ask","cwd":"/tmp","pid":'$$',"ts":'$(date +%s)'}' > ~/.tmwid/state/manual-test.json
```

Expected: 气泡切换为挥手动画，菜单栏变为 `❓1`。

- [ ] **Step 6: 清理 session**

```bash
rm ~/.tmwid/state/manual-test.json
```

Expected: 气泡消失，菜单栏恢复 `💤`。

- [ ] **Step 7: 测试真实 Claude Code 交互**

打开一个 Claude Code 窗口，执行任意 prompt。
Expected: 菜单栏在 AI 执行期间显示 `⚙1`，完成后显示 `✓1`。

- [ ] **Step 8: 测试卸载**

在 App 菜单栏点击 "Uninstall hooks"。

Run: `grep tmwid ~/.claude/settings.json || echo "removed"`
Expected: 输出 "removed"。

- [ ] **Step 9: Commit 任何 fix**

如果发现 bug，修复后提交：

```bash
git add -A
git commit -m "fix: <issue description>"
```

---

## Task 18: 写 README

**Files:**
- Create: `README.md`

- [ ] **Step 1: 写 README**

```markdown
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

Click menu bar icon → "Uninstall hooks".

## States

- ⚙ Working — AI is processing
- ❓ Ask — Needs your input (approval / question)
- ✓ Done — Task completed

## Files

- `~/.tmwid/state/` — session state files (cleaned automatically)
- `~/.tmwid/backups/` — settings.json backups (last 5)
- `~/.claude/settings.json` — where hooks are injected (with `# tmwid-v1-hook` marker)
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README"
```

---

## Self-Review

**Spec coverage:**

| Spec 要求 | 对应 Task |
|----------|----------|
| 状态文件格式 | Task 2 |
| Hook 事件映射 | Task 6 |
| Marker 机制 | Task 4 |
| 注入流程（备份+原子写） | Task 5, 6 |
| 还原/卸载 | Task 7 |
| FSEvent 监听 | Task 8 |
| 状态聚合 | Task 10 |
| stale session 纠错 | Task 9 |
| 菜单栏 App 模式 | Task 16 |
| 无边框毛玻璃窗口 | Task 15 |
| 单层视觉结构 | Task 14 |
| 帧动画 | Task 11, 12, 13 |
| 数字统一白色 | Task 13 |
| 不加脉冲 | Task 13, 14（无脉冲代码） |

**间隙**：
- "点击状态项激活对应终端窗口" — 未实现。可作为后续增量，已在 spec 的未来扩展中，不阻塞 MVP。MVP 让用户手动切 Claude 窗口即可。
- "hourly 重新校验 hooks" — 未单独实现。Task 16 在启动时调用 `install()` 已经覆盖启动时校验；hourly 检查可在后续加入，不是 MVP 必需。

**Placeholder 扫描**：所有 step 均含代码或具体命令，无 TBD/TODO。

**类型一致性**：
- `SessionState` 字段贯穿 Task 2、8、9、10
- `Paths` 使用贯穿 Task 3-9、16
- `AppState.update()` 在 Task 10 定义，Task 16 调用 ✓
- `FrameAnimator(prefix:count:fps:)` Task 12 定义，Task 13 调用 ✓
- 图片资源命名 `working-001` ... 在 Task 11 生成，Task 12/13 引用 ✓

Self-review 通过。
