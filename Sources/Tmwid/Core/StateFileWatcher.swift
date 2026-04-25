import Foundation

public final class StateFileWatcher {
    public let directory: String
    public let preToolThreshold: TimeInterval
    public var onChange: ([SessionState]) -> Void = { _ in }

    private var source: DispatchSourceFileSystemObject?
    private var pollTimer: DispatchSourceTimer?
    private var fd: Int32 = -1
    private let queue = DispatchQueue(label: "tmwid.watcher")

    public init(directory: String, preToolThreshold: TimeInterval = 2.0) {
        self.directory = directory
        self.preToolThreshold = preToolThreshold
    }

    public func start() {
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        fd = open(directory, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: queue
        )
        src.setEventHandler { [weak self] in
            guard let self = self else { return }
            let sessions = self.scan()
            DispatchQueue.main.async { self.onChange(sessions) }
        }
        src.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fd >= 0 { close(self.fd); self.fd = -1 }
        }
        src.resume()
        source = src

        // Periodic poll as fallback (every 5s)
        let poll = DispatchSource.makeTimerSource(queue: queue)
        poll.schedule(deadline: .now() + 5, repeating: 5)
        poll.setEventHandler { [weak self] in
            guard let self = self else { return }
            let sessions = self.scan()
            DispatchQueue.main.async { self.onChange(sessions) }
        }
        poll.resume()
        pollTimer = poll

        // Fire once initially
        let initial = self.scan()
        DispatchQueue.main.async { self.onChange(initial) }
    }

    public func stop() {
        source?.cancel()
        source = nil
        pollTimer?.cancel()
        pollTimer = nil
    }

    public func scan() -> [SessionState] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: directory) else { return [] }

        // First pass: collect .pre file timestamps keyed by session ID
        var preTimestamps: [String: TimeInterval] = [:]
        for f in files where f.hasSuffix(".pre") {
            let sid = String(f.dropLast(4)) // remove ".pre"
            let path = "\(directory)/\(f)"
            guard let content = try? String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
                  let ts = TimeInterval(content) else { continue }
            preTimestamps[sid] = ts
        }

        let now = Date().timeIntervalSince1970

        // Second pass: read .json session files, apply .pre override
        var results: [SessionState] = []
        for f in files where f.hasSuffix(".json") {
            let path = "\(directory)/\(f)"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { continue }
            if var s = try? JSONDecoder().decode(SessionState.self, from: data) {
                let sid = s.sessionId
                if let preTs = preTimestamps[sid],
                   s.status != .ask,
                   (now - preTs) > preToolThreshold {
                    s = SessionState(sessionId: sid, status: .ask, cwd: s.cwd, pid: s.pid, ts: s.ts)
                }
                results.append(s)
            } else {
                try? fm.removeItem(atPath: path)
            }
        }
        return results
    }
}
