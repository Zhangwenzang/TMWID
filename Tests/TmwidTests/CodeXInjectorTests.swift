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

    private func makeTempDir() -> String {
        let dir = NSTemporaryDirectory() + "tmwid-codex-test-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }
}
