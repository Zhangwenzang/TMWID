import Foundation

struct Paths {
    let home: String

    init(home: String = NSHomeDirectory()) {
        self.home = home
    }

    var claudeSettings: String { "\(home)/.claude/settings.json" }
    var stateDir: String { "\(home)/.tmwid/state" }
    var backupsDir: String { "\(home)/.tmwid/backups" }
    var appLog: String { "\(home)/.tmwid/app.log" }

    func stateFile(for sessionId: String) -> String {
        "\(stateDir)/\(sessionId).json"
    }
}
