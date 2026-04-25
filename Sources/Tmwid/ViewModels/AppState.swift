import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var sessions: [SessionState] = []

    var workingCount: Int { sessions.filter { $0.status == .working }.count }
    var doneCount: Int { sessions.filter { $0.status == .done }.count }
    var askCount: Int { sessions.filter { $0.status == .ask }.count }
    var isEmpty: Bool { sessions.isEmpty }

    func sessions(for kind: StatusKind) -> [SessionState] {
        sessions.filter { $0.status == kind }
    }

    func update(with newSessions: [SessionState]) {
        self.sessions = newSessions.sorted { $0.sessionId < $1.sessionId }
    }
}
