import XCTest
@testable import Tmwid

final class SettingsInjectorTests: XCTestCase {

    // MARK: - Marker tests (Task 4)

    func testIsCurrentTmwidHook() {
        XCTAssertTrue(SettingsInjector.isCurrentTmwidHook("# tmwid-v1-hook\necho hi"))
        XCTAssertFalse(SettingsInjector.isCurrentTmwidHook("afplay /System/Library/Sounds/Glass.aiff"))
    }

    func testIsLegacyTmwidHook() {
        XCTAssertTrue(SettingsInjector.isLegacyTmwidHook("# tmwid-v0-hook\necho hi"))
        XCTAssertFalse(SettingsInjector.isLegacyTmwidHook("# tmwid-v1-hook\necho hi"))
    }

    // MARK: - Read tests (Task 5)

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

    // MARK: - Install tests (Task 6)

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

    // MARK: - Uninstall tests (Task 7)

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

    // MARK: - Pre-tool marker script tests

    func testPreMarkerScriptContainsMarker() {
        XCTAssertTrue(HookTemplate.preMarkerScript.hasPrefix(HookMarker.current))
    }

    func testPreMarkerScriptWritesPreFile() {
        XCTAssertTrue(HookTemplate.preMarkerScript.contains(".pre"))
        XCTAssertTrue(HookTemplate.preMarkerScript.contains("date +%s"))
    }

    func testPostToolResetScriptContainsMarker() {
        XCTAssertTrue(HookTemplate.postToolResetScript.hasPrefix(HookMarker.current))
    }

    func testPostToolResetScriptDeletesPreFile() {
        XCTAssertTrue(HookTemplate.postToolResetScript.contains("rm -f"))
        XCTAssertTrue(HookTemplate.postToolResetScript.contains(".pre"))
    }

    func testPostToolResetScriptWritesWorkingStatus() {
        XCTAssertTrue(HookTemplate.postToolResetScript.contains("\"working\""))
    }

    // MARK: - Generic hook injection tests

    func testInjectCreatesGenericPreToolUse() throws {
        let tmp = makeTempDir()
        let injector = SettingsInjector(paths: Paths(home: tmp))
        try injector.install()
        let settings = try injector.readSettings()
        let hooks = settings["hooks"] as? [String: Any]
        let preToolGroups = hooks?["PreToolUse"] as? [[String: Any]] ?? []
        // Should have two groups: one with matcher "AskUserQuestion", one without
        let noMatcherGroup = preToolGroups.first { $0["matcher"] == nil }
        XCTAssertNotNil(noMatcherGroup, "Generic PreToolUse group should exist")
        let inner = (noMatcherGroup?["hooks"] as? [[String: Any]])?.first
        let cmd = inner?["command"] as? String ?? ""
        XCTAssertTrue(cmd.contains(".pre"), "Generic PreToolUse should write .pre file")
    }

    func testInjectCreatesGenericPostToolUse() throws {
        let tmp = makeTempDir()
        let injector = SettingsInjector(paths: Paths(home: tmp))
        try injector.install()
        let settings = try injector.readSettings()
        let hooks = settings["hooks"] as? [String: Any]
        let postToolGroups = hooks?["PostToolUse"] as? [[String: Any]] ?? []
        let noMatcherGroup = postToolGroups.first { $0["matcher"] == nil }
        XCTAssertNotNil(noMatcherGroup, "Generic PostToolUse group should exist")
        let inner = (noMatcherGroup?["hooks"] as? [[String: Any]])?.first
        let cmd = inner?["command"] as? String ?? ""
        XCTAssertTrue(cmd.contains("rm -f"), "Generic PostToolUse should delete .pre file")
        XCTAssertTrue(cmd.contains("\"working\""), "Generic PostToolUse should write working status")
    }

    func testGenericAndSpecificHooksCoexist() throws {
        let tmp = makeTempDir()
        let injector = SettingsInjector(paths: Paths(home: tmp))
        try injector.install()
        let settings = try injector.readSettings()
        let hooks = settings["hooks"] as? [String: Any]

        let preToolGroups = hooks?["PreToolUse"] as? [[String: Any]] ?? []
        XCTAssertEqual(preToolGroups.count, 2, "PreToolUse should have specific + generic groups")
        let preMatchers = Set(preToolGroups.compactMap { $0["matcher"] as? String })
        XCTAssertTrue(preMatchers.contains("AskUserQuestion"))

        let postToolGroups = hooks?["PostToolUse"] as? [[String: Any]] ?? []
        XCTAssertEqual(postToolGroups.count, 2, "PostToolUse should have specific + generic groups")
    }

    func testIdempotentInstallNoGenericDuplicates() throws {
        let tmp = makeTempDir()
        let injector = SettingsInjector(paths: Paths(home: tmp))
        try injector.install()
        try injector.install()
        try injector.install()
        let settings = try injector.readSettings()
        let hooks = settings["hooks"] as? [String: Any]
        let preToolGroups = hooks?["PreToolUse"] as? [[String: Any]] ?? []
        for group in preToolGroups {
            let inner = (group["hooks"] as? [[String: Any]]) ?? []
            let tmwidCount = inner.filter {
                SettingsInjector.isCurrentTmwidHook($0["command"] as? String ?? "")
            }.count
            XCTAssertEqual(tmwidCount, 1, "Each group should have exactly 1 tmwid hook after multiple installs")
        }
    }

    func testUninstallRemovesGenericHooks() throws {
        let tmp = makeTempDir()
        let injector = SettingsInjector(paths: Paths(home: tmp))
        try injector.install()
        try injector.uninstall()
        let settings = try injector.readSettings()
        let hooks = (settings["hooks"] as? [String: Any]) ?? [:]
        XCTAssertTrue(hooks.isEmpty, "All hooks should be removed after uninstall (no user hooks exist)")
    }

    // MARK: - Helpers

    private func makeTempDir() -> String {
        let dir = NSTemporaryDirectory() + "tmwid-test-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }
}
