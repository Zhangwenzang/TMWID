import XCTest
@testable import Tmwid

final class SessionListViewTests: XCTestCase {
    func testRendersSessionList() {
        let sessions = [
            SessionState(sessionId: "abc-123", status: .working, cwd: "/project-a", pid: 1000, ts: Date().timeIntervalSince1970),
            SessionState(sessionId: "def-456", status: .working, cwd: "/project-b", pid: 1001, ts: Date().timeIntervalSince1970)
        ]

        let view = SessionListView(sessions: sessions, activator: SessionActivator(), onTap: { _ in })

        XCTAssertNotNil(view)
    }
}
