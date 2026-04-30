import Foundation

public struct Paths {
    public let home: String

    public init(home: String = NSHomeDirectory()) {
        self.home = home
    }

    public var claudeSettings: String { "\(home)/.claude/settings.json" }
    public var stateDir: String { "\(home)/.tmwid/state" }
    public var backupsDir: String { "\(home)/.tmwid/backups" }
    public var appLog: String { "\(home)/.tmwid/app.log" }
    public var claudeProjectsDir: String { "\(home)/.claude/projects" }
    public var codexConfigDir: String { "\(home)/.codex" }
    public var codexHooksJSON: String { "\(home)/.codex/hooks.json" }
    public var codexConfigTOML: String { "\(home)/.codex/config.toml" }

    public func stateFile(for sessionId: String) -> String {
        "\(stateDir)/\(sessionId).json"
    }
}
