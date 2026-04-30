import Foundation

public final class SessionDiscovery {
    private let stateDir: String
    private let claudeProjectsDir: String
    let runShell: (String) -> String?
    private var watchers: [DispatchSourceFileSystemObject] = []
    private var pidPollTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "tmwid.discovery")
    private var scanScheduled = false

    /// Called on main queue when new sessions are discovered and written to stateDir
    public var onDiscovered: () -> Void = {}

    public init(
        stateDir: String,
        claudeProjectsDir: String,
        shell: @escaping (String) -> String? = SessionDiscovery.defaultShell
    ) {
        self.stateDir = stateDir
        self.claudeProjectsDir = claudeProjectsDir
        self.runShell = shell
    }

    deinit { stop() }

    // MARK: - Public

    /// One-shot scan at startup
    public func scanOnce() {
        queue.async { [weak self] in self?.runScan() }
    }

    /// Start watching for new sessions: FSEvents + periodic PID scan
    public func startWatching() {
        let fm = FileManager.default

        // Watch the parent dir for new project directories
        addWatch(on: claudeProjectsDir)

        // Watch each existing project directory for new .jsonl files
        guard let projects = try? fm.contentsOfDirectory(atPath: claudeProjectsDir) else { return }
        for project in projects {
            let path = "\(claudeProjectsDir)/\(project)"
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                addWatch(on: path)
            }
        }

        // Periodic PID scan to catch new processes (no FS event for process creation)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler { [weak self] in self?.runScan() }
        timer.resume()
        pidPollTimer = timer
    }

    public func stop() {
        for w in watchers { w.cancel() }
        watchers.removeAll()
        pidPollTimer?.cancel()
        pidPollTimer = nil
    }

    // MARK: - Watching

    private func addWatch(on path: String) {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write],
            queue: queue
        )
        src.setEventHandler { [weak self] in self?.scheduleScan() }
        src.setCancelHandler { close(fd) }
        src.resume()
        watchers.append(src)
    }

    private func scheduleScan() {
        guard !scanScheduled else { return }
        scanScheduled = true
        queue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.scanScheduled = false
            self?.runScan()
        }
    }

    // MARK: - Scanning

    private func runScan() {
        let stateFiles = readAllStateFiles()
        let existingIds = Set(stateFiles.map(\.sessionId))
        let existingPids = Set(stateFiles.map(\.pid))
        var created = false

        // Phase 1: Match resumed sessions by --resume flag (real session ID)
        let resumed = findResumedSessions()
        for s in resumed where !existingIds.contains(s.sessionId) {
            writeStateFile(s)
            created = true
        }

        // Phase 2: Create synthetic state files for untracked claude PIDs
        let allPids = findAllClaudePids()
        let knownPids = existingPids.union(Set(resumed.map(\.pid)))
        for pid in allPids where !knownPids.contains(pid) {
            writeSyntheticStateFile(pid: pid)
            created = true
        }

        // Phase 3: Clean up synthetic files superseded by real hook-created files
        cleanupSyntheticDuplicates()

        if created {
            DispatchQueue.main.async { [weak self] in self?.onDiscovered() }
        }
    }

    // MARK: - State file reading

    struct StateFileInfo {
        let sessionId: String
        let pid: Int32
    }

    func readAllStateFiles() -> [StateFileInfo] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: stateDir) else { return [] }
        return files.compactMap { f -> StateFileInfo? in
            guard f.hasSuffix(".json") else { return nil }
            let path = "\(stateDir)/\(f)"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sid = json["sessionId"] as? String,
                  let pid = json["pid"] as? Int else { return nil }
            return StateFileInfo(sessionId: sid, pid: Int32(pid))
        }
    }

    // MARK: - Process discovery

    struct DiscoveredSession {
        let sessionId: String
        let pid: Int32
        let cwd: String
    }

    /// Find sessions that have --resume <uuid> in their args
    func findResumedSessions() -> [DiscoveredSession] {
        guard let output = runShell("ps -eo pid,args") else { return [] }
        return output.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.contains("claude"), trimmed.contains("--resume") else { return nil }
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard parts.count == 2, let pid = Int32(parts[0]) else { return nil }
            guard let sid = extractResumeId(from: String(parts[1])) else { return nil }
            return DiscoveredSession(sessionId: sid, pid: pid, cwd: "")
        }
    }

    /// Find ALL claude process PIDs that are likely interactive terminal sessions.
    /// Excludes IDE/CodeBuddy processes (which have --output-format in args and are tracked by hooks)
    /// and their child processes.
    func findAllClaudePids() -> [Int32] {
        guard let output = runShell("ps -eo pid,ppid,args") else { return [] }
        // First pass: collect all lines and build parent-child map
        struct ProcInfo {
            let pid: Int32
            let ppid: Int32
            let args: String
        }
        var procs = [ProcInfo]()
        var idePids = Set<Int32>()

        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: " ", maxSplits: 2)
            guard parts.count >= 2,
                  let pid = Int32(parts[0]),
                  let ppid = Int32(parts[1]) else { continue }
            let args = parts.count > 2 ? String(parts[2]) : ""
            procs.append(ProcInfo(pid: pid, ppid: ppid, args: args))
            // Track IDE processes (by --output-format flag or zcode wrapper)
            if args.contains("--output-format") || args.contains("zcode") {
                idePids.insert(pid)
            }
        }

        return procs.compactMap { proc -> Int32? in
            let args = proc.args
            // Must be a claude binary
            guard args.contains("claude") else { return nil }
            // Skip IDE/CodeBuddy processes
            guard !args.contains("--output-format") else { return nil }
            // Skip if parent is an IDE process (child of zcode wrapper etc.)
            guard !idePids.contains(proc.ppid) else { return nil }
            // Skip wrapper scripts
            guard !args.hasPrefix("/bin/bash"),
                  !args.hasPrefix("/bin/zsh"),
                  !args.hasPrefix("bash"),
                  !args.hasPrefix("zsh") else { return nil }
            // Skip non-claude binaries
            guard !args.hasPrefix("tail"),
                  !args.hasPrefix("node") else { return nil }
            // The binary name must end with "claude"
            let binary = args.split(separator: " ").first.map(String.init) ?? ""
            guard binary.hasSuffix("claude") else { return nil }
            return proc.pid
        }
    }

    // MARK: - Synthetic state files

    static let syntheticPrefix = "pid-"

    private func writeSyntheticStateFile(pid: Int32) {
        let syntheticId = "\(Self.syntheticPrefix)\(pid)"
        let ts = Int(Date().timeIntervalSince1970)
        let json = """
        {"sessionId":"\(syntheticId)","status":"working","cwd":"","pid":\(pid),"ts":\(ts)}
        """
        let path = "\(stateDir)/\(syntheticId).json"
        let tmp = "\(path).tmp.\(getpid())"
        try? json.trimmingCharacters(in: .whitespacesAndNewlines)
            .data(using: .utf8)?
            .write(to: URL(fileURLWithPath: tmp))
        _ = rename(tmp, path)
    }

    /// Remove synthetic files when a real hook-created file exists with the same PID
    private func cleanupSyntheticDuplicates() {
        let allFiles = readAllStateFiles()
        let realPids = Set(allFiles.filter { !$0.sessionId.hasPrefix(Self.syntheticPrefix) }.map(\.pid))
        let fm = FileManager.default
        for file in allFiles where file.sessionId.hasPrefix(Self.syntheticPrefix) {
            if realPids.contains(file.pid) {
                try? fm.removeItem(atPath: "\(stateDir)/\(file.sessionId).json")
            }
        }
    }

    // MARK: - Helpers

    func extractResumeId(from args: String) -> String? {
        guard let range = args.range(of: "--resume ") else { return nil }
        let id = String(args[range.upperBound...].prefix(while: { $0 != " " }))
        return isUUIDLike(id) ? id : nil
    }

    func isUUIDLike(_ s: String) -> Bool {
        s.count >= 36 && s.contains("-")
    }

    private func writeStateFile(_ session: DiscoveredSession) {
        let ts = Int(Date().timeIntervalSince1970)
        let cwd = session.cwd.replacingOccurrences(of: "\"", with: "\\\"")
        let json = """
        {"sessionId":"\(session.sessionId)","status":"working","cwd":"\(cwd)","pid":\(session.pid),"ts":\(ts)}
        """
        let path = "\(stateDir)/\(session.sessionId).json"
        let tmp = "\(path).tmp.\(getpid())"
        try? json.trimmingCharacters(in: .whitespacesAndNewlines)
            .data(using: .utf8)?
            .write(to: URL(fileURLWithPath: tmp))
        _ = rename(tmp, path)
    }

    public static func defaultShell(_ command: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try? task.run()
        // Read pipe BEFORE waitUntilExit to avoid pipe buffer deadlock
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
