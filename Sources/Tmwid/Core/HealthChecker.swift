import Foundation

final class HealthChecker {
    let directory: String
    let staleThreshold: TimeInterval
    let processExists: (Int32) -> Bool

    private var timer: DispatchSourceTimer?

    init(
        directory: String,
        staleThreshold: TimeInterval = 600,
        processExists: @escaping (Int32) -> Bool = HealthChecker.defaultProcessExists
    ) {
        self.directory = directory
        self.staleThreshold = staleThreshold
        self.processExists = processExists
    }

    static func defaultProcessExists(pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno != ESRCH
    }

    func startPeriodic(interval: TimeInterval = 15) {
        let t = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        t.schedule(deadline: .now() + interval, repeating: interval)
        t.setEventHandler { [weak self] in self?.runOnce() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func runOnce() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: directory) else { return }
        let now = Date().timeIntervalSince1970
        for f in files where f.hasSuffix(".json") {
            let path = "\(directory)/\(f)"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let s = try? JSONDecoder().decode(SessionState.self, from: data)
            else { continue }

            guard s.status == .working else { continue }
            let isStale = (now - s.ts) > staleThreshold
            let isDead = !processExists(s.pid)
            if isStale || isDead {
                try? fm.removeItem(atPath: path)
            }
        }
    }
}
