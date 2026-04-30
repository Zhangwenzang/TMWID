import XCTest
@testable import Tmwid

final class CodeXInjectorTests: XCTestCase {
    func testInitWithPaths() {
        let paths = Paths(home: "/tmp/test")
        let injector = CodeXInjector(paths: paths)
        XCTAssertNotNil(injector)
    }

    func testEnableHooksFeatureCreatesConfigTOML() throws {
        let tmp = makeTempDir()
        let injector = CodeXInjector(paths: Paths(home: tmp))
        try injector.enableHooksFeature()

        let tomlPath = "\(tmp)/.codex/config.toml"
        XCTAssertTrue(FileManager.default.fileExists(atPath: tomlPath))

        let content = try String(contentsOfFile: tomlPath, encoding: .utf8)
        XCTAssertTrue(content.contains("[features]"))
        XCTAssertTrue(content.contains("codex_hooks = true"))
    }

    func testEnableHooksFeatureIsIdempotent() throws {
        let tmp = makeTempDir()
        let injector = CodeXInjector(paths: Paths(home: tmp))

        try injector.enableHooksFeature()
        let firstContent = try String(contentsOfFile: "\(tmp)/.codex/config.toml", encoding: .utf8)

        try injector.enableHooksFeature()
        let secondContent = try String(contentsOfFile: "\(tmp)/.codex/config.toml", encoding: .utf8)

        XCTAssertEqual(firstContent, secondContent, "重复调用不应修改文件")
    }

    func testWriteHooksJSONCreatesFile() throws {
        let tmp = makeTempDir()
        let injector = CodeXInjector(paths: Paths(home: tmp))
        try injector.writeHooksJSON()

        let hooksPath = "\(tmp)/.codex/hooks.json"
        XCTAssertTrue(FileManager.default.fileExists(atPath: hooksPath))

        let data = try Data(contentsOf: URL(fileURLWithPath: hooksPath))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let hooks = json?["hooks"] as? [String: Any]

        XCTAssertNotNil(hooks?["UserPromptSubmit"])
        XCTAssertNotNil(hooks?["Stop"])
        XCTAssertNotNil(hooks?["PermissionRequest"])
    }

    func testWriteHooksJSONThrowsIfExists() throws {
        let tmp = makeTempDir()
        try FileManager.default.createDirectory(atPath: "\(tmp)/.codex", withIntermediateDirectories: true)
        let existing = #"{"hooks":{"Custom":[{"hooks":[{"command":"echo test"}]}]}}"#
        try existing.write(toFile: "\(tmp)/.codex/hooks.json", atomically: true, encoding: .utf8)

        let injector = CodeXInjector(paths: Paths(home: tmp))

        XCTAssertThrowsError(try injector.writeHooksJSON())
    }

    func testWriteHooksJSONCleansUpTmpFileOnFailure() throws {
        let tmp = makeTempDir()
        let codexDir = "\(tmp)/.codex"
        try FileManager.default.createDirectory(atPath: codexDir, withIntermediateDirectories: true)

        let tmpFile = "\(codexDir)/hooks.json.tmp.\(getpid())"

        // 用作用域触发 defer
        do {
            let hooksStructure: [String: Any] = ["hooks": [:]]
            let data = try JSONSerialization.data(withJSONObject: hooksStructure, options: [])
            let badTarget = "\(codexDir)/nonexistent/hooks.json"

            defer { try? FileManager.default.removeItem(atPath: tmpFile) }
            try data.write(to: URL(fileURLWithPath: tmpFile), options: .atomic)

            let result = rename(tmpFile, badTarget)
            XCTAssertNotEqual(result, 0, "rename 应该失败")
        }

        // defer 已执行，验证临时文件被清理
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmpFile))
    }

    func testInstallEnablesBothFeatureAndHooks() throws {
        let tmp = makeTempDir()
        let injector = CodeXInjector(paths: Paths(home: tmp))
        try injector.install()

        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(tmp)/.codex/config.toml"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(tmp)/.codex/hooks.json"))
    }

    func testUninstallRemovesHooksJSON() throws {
        let tmp = makeTempDir()
        let injector = CodeXInjector(paths: Paths(home: tmp))
        try injector.install()
        try injector.uninstall()

        XCTAssertFalse(FileManager.default.fileExists(atPath: "\(tmp)/.codex/hooks.json"))
    }

    func testInstallIsIdempotent() throws {
        let tmp = makeTempDir()
        let injector = CodeXInjector(paths: Paths(home: tmp))

        try injector.install()
        let firstHooksContent = try String(contentsOfFile: "\(tmp)/.codex/hooks.json", encoding: .utf8)

        try injector.install()
        let secondHooksContent = try String(contentsOfFile: "\(tmp)/.codex/hooks.json", encoding: .utf8)

        XCTAssertEqual(firstHooksContent, secondHooksContent, "重复 install 不应修改 hooks.json")
    }

    func testCodeXAndClaudeCodeCoexist() throws {
        let tmp = makeTempDir()

        let claudeInj = SettingsInjector(paths: Paths(home: tmp))
        try claudeInj.install()

        let codexInj = CodeXInjector(paths: Paths(home: tmp))
        try codexInj.install()

        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(tmp)/.claude/settings.json"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(tmp)/.codex/hooks.json"))
    }

    func testUninstallOneDoesNotAffectOther() throws {
        let tmp = makeTempDir()

        let claudeInj = SettingsInjector(paths: Paths(home: tmp))
        try claudeInj.install()

        let codexInj = CodeXInjector(paths: Paths(home: tmp))
        try codexInj.install()

        try codexInj.uninstall()

        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(tmp)/.claude/settings.json"))
    }

    private func makeTempDir() -> String {
        let dir = NSTemporaryDirectory() + "tmwid-codex-test-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }
}
