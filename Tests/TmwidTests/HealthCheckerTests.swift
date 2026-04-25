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

    func testRemovesNonWorkingSessionsWithDeadPid() throws {
        let tmp = NSTemporaryDirectory() + "tmwid-health-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        let oldDone = #"{"sessionId":"a","status":"done","cwd":"","pid":1,"ts":1}"#
        try oldDone.write(toFile: "\(tmp)/a.json", atomically: true, encoding: .utf8)

        let checker = HealthChecker(directory: tmp, staleThreshold: 600, processExists: { _ in false })
        checker.runOnce()
        XCTAssertFalse(FileManager.default.fileExists(atPath: "\(tmp)/a.json"))
    }

    func testKeepsNonWorkingSessionsWithAlivePid() throws {
        let tmp = NSTemporaryDirectory() + "tmwid-health-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        let oldDone = #"{"sessionId":"a","status":"done","cwd":"","pid":1,"ts":1}"#
        try oldDone.write(toFile: "\(tmp)/a.json", atomically: true, encoding: .utf8)

        let checker = HealthChecker(directory: tmp, staleThreshold: 600, processExists: { _ in true })
        checker.runOnce()
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(tmp)/a.json"))
    }

    func testRemovesPreFileWhenSessionDead() throws {
        let tmp = NSTemporaryDirectory() + "tmwid-health-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        let json = #"{"sessionId":"a","status":"working","cwd":"","pid":1,"ts":\#(Date().timeIntervalSince1970)}"#
        try json.write(toFile: "\(tmp)/a.json", atomically: true, encoding: .utf8)
        try "12345".write(toFile: "\(tmp)/a.pre", atomically: true, encoding: .utf8)

        let checker = HealthChecker(directory: tmp, staleThreshold: 600, processExists: { _ in false })
        checker.runOnce()
        XCTAssertFalse(FileManager.default.fileExists(atPath: "\(tmp)/a.json"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: "\(tmp)/a.pre"), ".pre file should be removed with dead session")
    }

    func testRemovesOrphanedPreFile() throws {
        let tmp = NSTemporaryDirectory() + "tmwid-health-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        try "12345".write(toFile: "\(tmp)/orphan.pre", atomically: true, encoding: .utf8)

        let checker = HealthChecker(directory: tmp, staleThreshold: 600, processExists: { _ in true })
        checker.runOnce()
        XCTAssertFalse(FileManager.default.fileExists(atPath: "\(tmp)/orphan.pre"), "Orphaned .pre should be removed")
    }

    func testKeepsPreFileForHealthySession() throws {
        let tmp = NSTemporaryDirectory() + "tmwid-health-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        let json = #"{"sessionId":"a","status":"working","cwd":"","pid":1,"ts":\#(Date().timeIntervalSince1970)}"#
        try json.write(toFile: "\(tmp)/a.json", atomically: true, encoding: .utf8)
        try "12345".write(toFile: "\(tmp)/a.pre", atomically: true, encoding: .utf8)

        let checker = HealthChecker(directory: tmp, staleThreshold: 600, processExists: { _ in true })
        checker.runOnce()
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(tmp)/a.json"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(tmp)/a.pre"), ".pre file should be kept for healthy session")
    }
}
