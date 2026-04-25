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
