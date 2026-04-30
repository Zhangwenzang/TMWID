import XCTest
@testable import Tmwid

final class SessionDiscoveryTests: XCTestCase {

    private func makeTmpDir() throws -> String {
        let dir = NSTemporaryDirectory() + "tmwid-discovery-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - extractResumeId

    func testExtractResumeId() {
        let d = SessionDiscovery(stateDir: "/tmp", claudeProjectsDir: "/tmp")
        let args = "/usr/bin/claude --output-format json --resume 7382a933-6f49-4caa-8e76-1b909809037a --verbose"
        XCTAssertEqual(
            d.extractResumeId(from: args),
            "7382a933-6f49-4caa-8e76-1b909809037a"
        )
    }

    func testExtractResumeIdAtEnd() {
        let d = SessionDiscovery(stateDir: "/tmp", claudeProjectsDir: "/tmp")
        let args = "/usr/bin/claude --resume abcdef01-2345-6789-abcd-ef0123456789"
        XCTAssertEqual(
            d.extractResumeId(from: args),
            "abcdef01-2345-6789-abcd-ef0123456789"
        )
    }

    func testExtractResumeIdMissing() {
        let d = SessionDiscovery(stateDir: "/tmp", claudeProjectsDir: "/tmp")
        XCTAssertNil(d.extractResumeId(from: "/usr/bin/claude --verbose"))
    }

    func testExtractResumeIdTooShort() {
        let d = SessionDiscovery(stateDir: "/tmp", claudeProjectsDir: "/tmp")
        XCTAssertNil(d.extractResumeId(from: "/usr/bin/claude --resume short"))
    }

    // MARK: - isUUIDLike

    func testIsUUIDLike() {
        let d = SessionDiscovery(stateDir: "/tmp", claudeProjectsDir: "/tmp")
        XCTAssertTrue(d.isUUIDLike("7382a933-6f49-4caa-8e76-1b909809037a"))
        XCTAssertFalse(d.isUUIDLike("short"))
        XCTAssertFalse(d.isUUIDLike("abcdef0123456789abcdef0123456789abcdef01"))
    }

    // MARK: - findResumedSessions

    func testFindResumedSessionsParsesPsOutput() {
        let psOutput = """
          PID ARGS
        12345 /usr/bin/claude --resume 7382a933-6f49-4caa-8e76-1b909809037a --verbose
        99999 /usr/bin/node something
        67890 /usr/bin/claude --output-format json --verbose
        """
        let d = SessionDiscovery(stateDir: "/tmp", claudeProjectsDir: "/tmp") { _ in psOutput }
        let sessions = d.findResumedSessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].sessionId, "7382a933-6f49-4caa-8e76-1b909809037a")
        XCTAssertEqual(sessions[0].pid, 12345)
    }

    func testFindResumedSessionsMultiple() {
        let psOutput = """
        12345 /usr/bin/claude --resume aaaa1111-2222-3333-4444-555566667777 --verbose
        67890 /usr/bin/claude --resume bbbb1111-2222-3333-4444-555566667777 --verbose
        """
        let d = SessionDiscovery(stateDir: "/tmp", claudeProjectsDir: "/tmp") { _ in psOutput }
        XCTAssertEqual(d.findResumedSessions().count, 2)
    }

    func testFindResumedSessionsEmpty() {
        let d = SessionDiscovery(stateDir: "/tmp", claudeProjectsDir: "/tmp") { _ in "" }
        XCTAssertTrue(d.findResumedSessions().isEmpty)
    }

    // MARK: - findAllClaudePids

    func testFindAllClaudePids() {
        let psOutput = """
          PID  PPID ARGS
        12345     1 /usr/bin/claude --verbose
        67890     1 /long/path/to/native-binary/claude
        99999     1 /usr/bin/node something
        11111     1 claude
        22222     1 claudette --verbose
        33333     1 /usr/bin/claude --output-format stream-json --verbose
        44444     1 bash /usr/local/bin/zcode claude
        55555     1 tail -f /path/to/.claude/something
        66666 44444 claude
        """
        let d = SessionDiscovery(stateDir: "/tmp", claudeProjectsDir: "/tmp") { _ in psOutput }
        let pids = d.findAllClaudePids()
        XCTAssertEqual(Set(pids), Set([12345, 67890, 11111]))
        XCTAssertFalse(pids.contains(99999), "node is not claude")
        XCTAssertFalse(pids.contains(22222), "claudette is not claude")
        XCTAssertFalse(pids.contains(33333), "IDE process with --output-format should be excluded")
        XCTAssertFalse(pids.contains(44444), "bash wrapper should be excluded")
        XCTAssertFalse(pids.contains(55555), "tail command should be excluded")
        XCTAssertFalse(pids.contains(66666), "child of zcode wrapper should be excluded")
    }

    func testFindAllClaudePidsEmpty() {
        let d = SessionDiscovery(stateDir: "/tmp", claudeProjectsDir: "/tmp") { _ in "" }
        XCTAssertTrue(d.findAllClaudePids().isEmpty)
    }

    // MARK: - readAllStateFiles

    func testReadAllStateFiles() throws {
        let stateDir = try makeTmpDir()
        let json1 = #"{"sessionId":"aaa","status":"working","cwd":"","pid":100,"ts":1}"#
        let json2 = #"{"sessionId":"bbb","status":"done","cwd":"","pid":200,"ts":2}"#
        try json1.write(toFile: "\(stateDir)/aaa.json", atomically: true, encoding: .utf8)
        try json2.write(toFile: "\(stateDir)/bbb.json", atomically: true, encoding: .utf8)

        let d = SessionDiscovery(stateDir: stateDir, claudeProjectsDir: "/tmp")
        let files = d.readAllStateFiles()
        XCTAssertEqual(files.count, 2)
        XCTAssertTrue(files.contains(where: { $0.sessionId == "aaa" && $0.pid == 100 }))
        XCTAssertTrue(files.contains(where: { $0.sessionId == "bbb" && $0.pid == 200 }))
    }

    // MARK: - Synthetic state file creation

    func testCreatesStatesForUntrackedPids() throws {
        let stateDir = try makeTmpDir()
        // Pre-existing state file for PID 100
        let existing = #"{"sessionId":"real-uuid","status":"working","cwd":"","pid":100,"ts":1}"#
        try existing.write(toFile: "\(stateDir)/real-uuid.json", atomically: true, encoding: .utf8)

        let psOutput = """
          PID  PPID ARGS
        100     1 claude
        200     1 claude
        300     1 claude
        """

        let d = SessionDiscovery(stateDir: stateDir, claudeProjectsDir: "/tmp") { _ in psOutput }

        let expectation = XCTestExpectation(description: "onDiscovered")
        d.onDiscovered = { expectation.fulfill() }
        d.scanOnce()
        wait(for: [expectation], timeout: 3.0)

        // PID 100 already has a state file, should NOT get a synthetic one
        // PID 200 and 300 should get synthetic state files
        let files = try FileManager.default.contentsOfDirectory(atPath: stateDir)
            .filter { $0.hasSuffix(".json") }
        XCTAssertEqual(files.count, 3) // real-uuid + pid-200 + pid-300

        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(stateDir)/pid-200.json"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(stateDir)/pid-300.json"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(stateDir)/real-uuid.json"))
    }

    func testSkipsPidsAlreadyTracked() throws {
        let stateDir = try makeTmpDir()
        let existing = #"{"sessionId":"my-session","status":"done","cwd":"","pid":100,"ts":1}"#
        try existing.write(toFile: "\(stateDir)/my-session.json", atomically: true, encoding: .utf8)

        let d = SessionDiscovery(stateDir: stateDir, claudeProjectsDir: "/tmp") { _ in
            "100 1 claude\n"
        }

        d.scanOnce()
        // Give async scan time
        let exp = XCTestExpectation(description: "wait")
        exp.isInverted = true
        wait(for: [exp], timeout: 1.0)

        let files = try FileManager.default.contentsOfDirectory(atPath: stateDir)
            .filter { $0.hasSuffix(".json") }
        XCTAssertEqual(files.count, 1) // only original, no synthetic
    }

    // MARK: - Synthetic cleanup

    func testCleansSyntheticWhenRealAppears() throws {
        let stateDir = try makeTmpDir()
        // Simulate: synthetic file exists, then hook creates real file with same PID
        let synthetic = #"{"sessionId":"pid-200","status":"working","cwd":"","pid":200,"ts":1}"#
        let real = #"{"sessionId":"real-abc","status":"done","cwd":"/foo","pid":200,"ts":2}"#
        try synthetic.write(toFile: "\(stateDir)/pid-200.json", atomically: true, encoding: .utf8)
        try real.write(toFile: "\(stateDir)/real-abc.json", atomically: true, encoding: .utf8)

        let d = SessionDiscovery(stateDir: stateDir, claudeProjectsDir: "/tmp") { _ in
            "200 1 claude\n"
        }

        let expectation = XCTestExpectation(description: "scan done")
        expectation.isInverted = true
        d.scanOnce()
        wait(for: [expectation], timeout: 1.5)

        // Synthetic should be removed, real should remain
        XCTAssertFalse(FileManager.default.fileExists(atPath: "\(stateDir)/pid-200.json"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(stateDir)/real-abc.json"))
    }

    // MARK: - Resume takes priority over synthetic

    func testResumeSessionPreventsSynthetic() throws {
        let stateDir = try makeTmpDir()

        let psOutput = "500 1 /usr/bin/claude --resume aaaa1111-2222-3333-4444-555566667777 --verbose\n"
        let d = SessionDiscovery(stateDir: stateDir, claudeProjectsDir: "/tmp") { _ in psOutput }

        let expectation = XCTestExpectation(description: "onDiscovered")
        d.onDiscovered = { expectation.fulfill() }
        d.scanOnce()
        wait(for: [expectation], timeout: 3.0)

        let files = try FileManager.default.contentsOfDirectory(atPath: stateDir)
            .filter { $0.hasSuffix(".json") }
        // Should create real session file, NOT synthetic
        XCTAssertEqual(files.count, 1)
        XCTAssertTrue(files[0].contains("aaaa1111"))
        XCTAssertFalse(files[0].hasPrefix("pid-"))
    }
}
