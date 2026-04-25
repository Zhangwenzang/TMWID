import Foundation

public struct SessionState: Codable, Equatable, Identifiable {
    public let sessionId: String
    public let status: StatusKind
    public let cwd: String
    public let pid: Int32
    public let ts: TimeInterval

    public var id: String { sessionId }

    enum CodingKeys: String, CodingKey {
        case sessionId, status, cwd, pid, ts
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try c.decode(String.self, forKey: .sessionId)
        status = try c.decode(StatusKind.self, forKey: .status)
        cwd = (try? c.decode(String.self, forKey: .cwd)) ?? ""
        pid = try c.decode(Int32.self, forKey: .pid)
        ts = try c.decode(TimeInterval.self, forKey: .ts)
    }

    public init(sessionId: String, status: StatusKind, cwd: String, pid: Int32, ts: TimeInterval) {
        self.sessionId = sessionId
        self.status = status
        self.cwd = cwd
        self.pid = pid
        self.ts = ts
    }
}
