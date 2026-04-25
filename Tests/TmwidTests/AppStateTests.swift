import XCTest
@testable import Tmwid

@MainActor
final class AppStateTests: XCTestCase {
    func testCountsByStatus() {
        let state = AppState()
        state.update(with: [
            SessionState(sessionId: "a", status: .working, cwd: "", pid: 1, ts: 0),
            SessionState(sessionId: "b", status: .working, cwd: "", pid: 2, ts: 0),
            SessionState(sessionId: "c", status: .done, cwd: "", pid: 3, ts: 0),
            SessionState(sessionId: "d", status: .ask, cwd: "", pid: 4, ts: 0),
        ])
        XCTAssertEqual(state.workingCount, 2)
        XCTAssertEqual(state.doneCount, 1)
        XCTAssertEqual(state.askCount, 1)
    }

    func testIsEmptyWhenNoSessions() {
        let state = AppState()
        state.update(with: [])
        XCTAssertTrue(state.isEmpty)
    }

    func testIsNotEmptyWithSessions() {
        let state = AppState()
        state.update(with: [
            SessionState(sessionId: "a", status: .working, cwd: "", pid: 1, ts: 0)
        ])
        XCTAssertFalse(state.isEmpty)
    }

    func testSessionsForStatus() {
        let state = AppState()
        let s1 = SessionState(sessionId: "a", status: .working, cwd: "/x", pid: 1, ts: 0)
        let s2 = SessionState(sessionId: "b", status: .working, cwd: "/y", pid: 2, ts: 0)
        state.update(with: [s1, s2])
        XCTAssertEqual(state.sessions(for: .working).count, 2)
        XCTAssertEqual(state.sessions(for: .done).count, 0)
    }
}
