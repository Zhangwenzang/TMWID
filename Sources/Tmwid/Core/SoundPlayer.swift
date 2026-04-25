import AppKit

@MainActor
public final class SoundPlayer {
    private var sounds: [StatusKind: NSSound] = [:]
    private var previousSessions: [SessionState] = []

    public init() {
        if let url = Bundle.module.url(forResource: "Glass", withExtension: "aiff"),
           let sound = NSSound(contentsOf: url, byReference: false) {
            sounds[.done] = sound
        }
        if let url = Bundle.module.url(forResource: "Hero", withExtension: "aiff"),
           let sound = NSSound(contentsOf: url, byReference: false) {
            sounds[.ask] = sound
        }
    }

    /// Pure function: determines which status sound to play given a session diff.
    /// Returns nil if no sound should play. Prioritizes ask > done.
    public static func statusToPlay(
        previous: [SessionState],
        current: [SessionState]
    ) -> StatusKind? {
        let oldMap = Dictionary(uniqueKeysWithValues: previous.map { ($0.sessionId, $0.status) })
        var changed: Set<StatusKind> = []

        for session in current {
            let oldStatus = oldMap[session.sessionId]
            // New session or status changed
            if oldStatus != session.status {
                if session.status != .working {
                    changed.insert(session.status)
                }
            }
        }
        // Priority: ask > done
        if changed.contains(.ask) { return .ask }
        if changed.contains(.done) { return .done }
        return nil
    }

    public func playIfNeeded(currentSessions: [SessionState], enabled: Bool) {
        defer { previousSessions = currentSessions }
        guard enabled else { return }

        if let kind = Self.statusToPlay(previous: previousSessions, current: currentSessions) {
            sounds[kind]?.stop()
            sounds[kind]?.play()
        }
    }
}
