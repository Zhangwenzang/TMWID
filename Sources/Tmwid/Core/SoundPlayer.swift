import AppKit

/// Returns the resource bundle, trying multiple lookup strategies:
/// 1. Next to executable (packaged .app with bundle in Contents/MacOS/)
/// 2. Contents/Resources/ (standard .app layout)
/// 3. Bundle.module (SPM tests and dev builds)
@MainActor
private func tmwidResourceBundle() -> Bundle? {
    let execURL = Bundle.main.executableURL ?? Bundle.main.bundleURL
    let bundleName = "Tmwid_Tmwid.bundle"

    // Next to executable
    let adjacentURL = execURL.deletingLastPathComponent().appendingPathComponent(bundleName)
    if FileManager.default.fileExists(atPath: adjacentURL.path) {
        return Bundle(url: adjacentURL)
    }

    // Contents/Resources/
    let resourcesURL = execURL.deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Resources")
        .appendingPathComponent(bundleName)
    if FileManager.default.fileExists(atPath: resourcesURL.path) {
        return Bundle(url: resourcesURL)
    }

    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle.main
    #endif
}

@MainActor
public final class SoundPlayer {
    private var sounds: [StatusKind: NSSound] = [:]
    private var previousSessions: [SessionState] = []

    public init() {
        let bundle = tmwidResourceBundle()
        if let url = bundle?.url(forResource: "Glass", withExtension: "aiff"),
           let sound = NSSound(contentsOf: url, byReference: false) {
            sounds[.done] = sound
        }
        if let url = bundle?.url(forResource: "Hero", withExtension: "aiff"),
           let sound = NSSound(contentsOf: url, byReference: false) {
            sounds[.ask] = sound
        }
        if let url = bundle?.url(forResource: "Basso", withExtension: "aiff"),
           let sound = NSSound(contentsOf: url, byReference: false) {
            sounds[.apiErr] = sound
        }
    }

    /// Pure function: determines which status sound to play given a session diff.
    /// Returns nil if no sound should play. Prioritizes ask > apiErr > done.
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
        // Priority: ask > apiErr > done
        if changed.contains(.ask) { return .ask }
        if changed.contains(.apiErr) { return .apiErr }
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
