import XCTest
@testable import Tmwid

@MainActor
final class FrameAnimatorTests: XCTestCase {
    func testInitialFrameIsZero() {
        let anim = FrameAnimator(prefix: "working", count: 14, fps: 10)
        XCTAssertEqual(anim.currentFrameName, "working-001")
    }

    func testAdvanceWraps() {
        let anim = FrameAnimator(prefix: "working", count: 3, fps: 10)
        anim.advance(); XCTAssertEqual(anim.currentFrameName, "working-002")
        anim.advance(); XCTAssertEqual(anim.currentFrameName, "working-003")
        anim.advance(); XCTAssertEqual(anim.currentFrameName, "working-001")
    }

    func testFrameNameFormat() {
        let anim = FrameAnimator(prefix: "ask", count: 12, fps: 8)
        XCTAssertEqual(anim.frameName(at: 0), "ask-001")
        XCTAssertEqual(anim.frameName(at: 11), "ask-012")
    }
}
