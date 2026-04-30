import Foundation
import SwiftUI

@MainActor
public final class AppState: ObservableObject {
    @Published public private(set) var sessions: [SessionState] = []

    public var workingCount: Int { sessions.filter { $0.status == .working }.count }
    public var doneCount: Int { sessions.filter { $0.status == .done }.count }
    public var askCount: Int { sessions.filter { $0.status == .ask }.count }
    public var apiErrCount: Int { sessions.filter { $0.status == .apiErr }.count }
    public var isEmpty: Bool { sessions.isEmpty }

    public init() {}

    public func sessions(for kind: StatusKind) -> [SessionState] {
        sessions.filter { $0.status == kind }
    }

    public func update(with newSessions: [SessionState]) {
        self.sessions = newSessions.sorted { $0.sessionId < $1.sessionId }
    }
}
