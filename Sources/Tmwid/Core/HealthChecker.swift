import Foundation

public final class HealthChecker {
    public let directory: String
    public let staleThreshold: TimeInterval
    public let processExists: (Int32) -> Bool

    private var timer: DispatchSourceTimer?

    public init(
        directory: String,
        staleThreshold: TimeInterval = 600,
        processExists: @escaping (Int32) -> Bool = HealthChecker.defaultProcessExists
    ) {
        self.directory = directory
        self.staleThreshold = staleThreshold
        self.processExists = processExists
    }

    public static func defaultProcessExists(pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno != ESRCH
    }

    public func startPeriodic(interval: TimeInterval = 15) {
        let t = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        t.schedule(deadline: .now() + interval, repeating: interval)
        t.setEventHandler { [weak self] in self?.runOnce() }
        t.resume()
        timer = t
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    public func runOnce() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: directory) else { return }
        let now = Date().timeIntervalSince1970

        var validSessionIds: Set<String> = []

        for f in files where f.hasSuffix(".json") {
            let path = "\(directory)/\(f)"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let s = try? JSONDecoder().decode(SessionState.self, from: data)
            else { continue }

            let isDead = !processExists(s.pid)
            let isStale = s.status == .working && (now - s.ts) > staleThreshold
            if isDead || isStale {
                try? fm.removeItem(atPath: path)
                try? fm.removeItem(atPath: "\(directory)/\(s.sessionId).pre")
            } else {
                validSessionIds.insert(s.sessionId)
            }
        }

        // Remove orphaned .pre files (no matching .json)
        for f in files where f.hasSuffix(".pre") {
            let sid = String(f.dropLast(4))
            if !validSessionIds.contains(sid) {
                try? fm.removeItem(atPath: "\(directory)/\(f)")
            }
        }
    }
}
