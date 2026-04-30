import XCTest
@testable import Tmwid

final class SessionActivatorTests: XCTestCase {
    func testAppIconReturnsIconForValidPid() {
        let activator = SessionActivator()
        let currentPid = ProcessInfo.processInfo.processIdentifier

        let icon = activator.appIcon(for: currentPid)

        XCTAssertNotNil(icon)
    }

    func testAppIconReturnsNilForInvalidPid() {
        let activator = SessionActivator()

        let icon = activator.appIcon(for: -1)

        XCTAssertNil(icon)
    }
}
