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
