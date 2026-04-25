import XCTest
@testable import Tmwid

@MainActor
final class SoundPlayerTests: XCTestCase {

    // Helper to create sessions
    private func session(_ id: String, _ status: StatusKind) -> SessionState {
        SessionState(sessionId: id, status: status, cwd: "", pid: 1, ts: 0)
    }

    func testNoChangeNoSound() {
        let old = [session("a", .working)]
        let new = [session("a", .working)]
        XCTAssertNil(SoundPlayer.statusToPlay(previous: old, current: new))
    }

    func testWorkingToDonePlaysGlass() {
        let old = [session("a", .working)]
        let new = [session("a", .done)]
        XCTAssertEqual(SoundPlayer.statusToPlay(previous: old, current: new), .done)
    }

    func testWorkingToAskPlaysAsk() {
        let old = [session("a", .working)]
        let new = [session("a", .ask)]
        XCTAssertEqual(SoundPlayer.statusToPlay(previous: old, current: new), .ask)
    }

    func testAskTakesPriorityOverDone() {
        let old = [session("a", .working), session("b", .working)]
        let new = [session("a", .done), session("b", .ask)]
        XCTAssertEqual(SoundPlayer.statusToPlay(previous: old, current: new), .ask)
    }

    func testWorkingStatusNoSound() {
        let old = [session("a", .done)]
        let new = [session("a", .working)]
        XCTAssertNil(SoundPlayer.statusToPlay(previous: old, current: new))
    }

    func testSessionRemovedNoSound() {
        let old = [session("a", .working)]
        let new: [SessionState] = []
        XCTAssertNil(SoundPlayer.statusToPlay(previous: old, current: new))
    }

    func testNewSessionWorkingNoSound() {
        let old: [SessionState] = []
        let new = [session("a", .working)]
        XCTAssertNil(SoundPlayer.statusToPlay(previous: old, current: new))
    }

    func testNewSessionAskPlaysAsk() {
        let old: [SessionState] = []
        let new = [session("a", .ask)]
        XCTAssertEqual(SoundPlayer.statusToPlay(previous: old, current: new), .ask)
    }

    func testNewSessionDonePlaysDone() {
        let old: [SessionState] = []
        let new = [session("a", .done)]
        XCTAssertEqual(SoundPlayer.statusToPlay(previous: old, current: new), .done)
    }

    func testMultipleSameStatusDeduplicated() {
        let old = [session("a", .working), session("b", .working), session("c", .working)]
        let new = [session("a", .done), session("b", .done), session("c", .done)]
        // Should return .done (one sound, not three)
        XCTAssertEqual(SoundPlayer.statusToPlay(previous: old, current: new), .done)
    }
}
