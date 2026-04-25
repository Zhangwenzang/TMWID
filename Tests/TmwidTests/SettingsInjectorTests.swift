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

    // MARK: - Helpers

    private func makeTempDir() -> String {
        let dir = NSTemporaryDirectory() + "tmwid-test-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }
}
