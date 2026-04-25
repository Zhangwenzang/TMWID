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
