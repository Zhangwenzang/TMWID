import Foundation

final class StateFileWatcher {
    let directory: String
    var onChange: ([SessionState]) -> Void = { _ in }

    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private let queue = DispatchQueue(label: "tmwid.watcher")

    init(directory: String) {
        self.directory = directory
    }

    func start() {
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
        // Fire once initially
        let initial = self.scan()
        DispatchQueue.main.async { self.onChange(initial) }
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    func scan() -> [SessionState] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: directory) else { return [] }
        var results: [SessionState] = []
        for f in files where f.hasSuffix(".json") {
            let path = "\(directory)/\(f)"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { continue }
            if let s = try? JSONDecoder().decode(SessionState.self, from: data) {
                results.append(s)
            } else {
                try? fm.removeItem(atPath: path)
            }
        }
        return results
    }
}
