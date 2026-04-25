import Foundation

struct SessionState: Codable, Equatable, Identifiable {
    let sessionId: String
    let status: StatusKind
    let cwd: String
    let pid: Int32
    let ts: TimeInterval

    var id: String { sessionId }

    enum CodingKeys: String, CodingKey {
        case sessionId, status, cwd, pid, ts
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try c.decode(String.self, forKey: .sessionId)
        status = try c.decode(StatusKind.self, forKey: .status)
        cwd = (try? c.decode(String.self, forKey: .cwd)) ?? ""
        pid = try c.decode(Int32.self, forKey: .pid)
        ts = try c.decode(TimeInterval.self, forKey: .ts)
    }

    init(sessionId: String, status: StatusKind, cwd: String, pid: Int32, ts: TimeInterval) {
        self.sessionId = sessionId
        self.status = status
        self.cwd = cwd
        self.pid = pid
        self.ts = ts
    }
}
