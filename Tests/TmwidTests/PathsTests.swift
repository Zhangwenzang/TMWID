import XCTest
@testable import Tmwid

final class PathsTests: XCTestCase {
    func testClaudeSettings() {
        let paths = Paths(home: "/Users/test")
        XCTAssertEqual(paths.claudeSettings, "/Users/test/.claude/settings.json")
    }

    func testStateDir() {
        let paths = Paths(home: "/Users/test")
        XCTAssertEqual(paths.stateDir, "/Users/test/.tmwid/state")
    }

    func testBackupsDir() {
        let paths = Paths(home: "/Users/test")
        XCTAssertEqual(paths.backupsDir, "/Users/test/.tmwid/backups")
    }

    func testAppLog() {
        let paths = Paths(home: "/Users/test")
        XCTAssertEqual(paths.appLog, "/Users/test/.tmwid/app.log")
    }

    func testClaudeProjectsDir() {
        let paths = Paths(home: "/Users/test")
        XCTAssertEqual(paths.claudeProjectsDir, "/Users/test/.claude/projects")
    }

    func testStateFile() {
        let paths = Paths(home: "/Users/test")
        XCTAssertEqual(paths.stateFile(for: "abc123"), "/Users/test/.tmwid/state/abc123.json")
    }

    func testCodeXConfigDir() {
        let paths = Paths(home: "/Users/test")
        XCTAssertEqual(paths.codexConfigDir, "/Users/test/.codex")
    }

    func testCodeXHooksJSON() {
        let paths = Paths(home: "/Users/test")
        XCTAssertEqual(paths.codexHooksJSON, "/Users/test/.codex/hooks.json")
    }

    func testCodeXConfigTOML() {
        let paths = Paths(home: "/Users/test")
        XCTAssertEqual(paths.codexConfigTOML, "/Users/test/.codex/config.toml")
    }
}
