import XCTest
@testable import Tmwid

final class CodeXInjectorTests: XCTestCase {
    func testInitWithPaths() {
        let paths = Paths(home: "/tmp/test")
        let injector = CodeXInjector(paths: paths)
        XCTAssertNotNil(injector)
    }

    private func makeTempDir() -> String {
        let dir = NSTemporaryDirectory() + "tmwid-codex-test-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }
}
