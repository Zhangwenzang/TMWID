import Foundation

enum HookMarker {
    static let current = "# tmwid-v2-hook"
    static let legacyPrefixes = ["# tmwid-v0-hook", "# tmwid-v1-hook"]
}

enum HookTemplate {
    static func scriptForStatus(_ status: String) -> String {
        """
        \(HookMarker.current)
        input=$(cat)
        sid=$(printf '%s' "$input" | /usr/bin/jq -r '.session_id // empty')
        cwd=$(printf '%s' "$input" | /usr/bin/jq -r '.cwd // empty')
        [ -z "$sid" ] && exit 0
        dir="$HOME/.tmwid/state"
        mkdir -p "$dir"
        tmp="$dir/$sid.json.tmp.$$"
        printf '{"sessionId":"%s","status":"\(status)","cwd":"%s","pid":%d,"ts":%d}\\n' \
          "$sid" "$cwd" "$PPID" "$(date +%s)" > "$tmp" && mv "$tmp" "$dir/$sid.json"
        exit 0
        """
    }

    static let cleanupScript = """
    \(HookMarker.current)
    input=$(cat)
    sid=$(printf '%s' "$input" | /usr/bin/jq -r '.session_id // empty')
    [ -n "$sid" ] && rm -f "$HOME/.tmwid/state/$sid.json"
    exit 0
    """

    static let preMarkerScript = """
    \(HookMarker.current)
    input=$(cat)
    sid=$(printf '%s' "$input" | /usr/bin/jq -r '.session_id // empty')
    [ -z "$sid" ] && exit 0
    mkdir -p "$HOME/.tmwid/state"
    printf '%d' "$(date +%s)" > "$HOME/.tmwid/state/$sid.pre"
    exit 0
    """

    static let postToolResetScript = """
    \(HookMarker.current)
    input=$(cat)
    sid=$(printf '%s' "$input" | /usr/bin/jq -r '.session_id // empty')
    cwd=$(printf '%s' "$input" | /usr/bin/jq -r '.cwd // empty')
    [ -z "$sid" ] && exit 0
    dir="$HOME/.tmwid/state"
    rm -f "$dir/$sid.pre"
    tmp="$dir/$sid.json.tmp.$$"
    printf '{"sessionId":"%s","status":"working","cwd":"%s","pid":%d,"ts":%d}\\n' \
      "$sid" "$cwd" "$PPID" "$(date +%s)" > "$tmp" && mv "$tmp" "$dir/$sid.json"
    exit 0
    """

    static let errorScript = """
    \(HookMarker.current)
    input=$(cat)
    sid=$(printf '%s' "$input" | /usr/bin/jq -r '.session_id // empty')
    cwd=$(printf '%s' "$input" | /usr/bin/jq -r '.cwd // empty')
    error=$(printf '%s' "$input" | /usr/bin/jq -r '.error // empty')
    [ -z "$sid" ] && exit 0
    case "$error" in
      *rate*limit*|*quota*|*429*|*503*|*timeout*|*network*|*connection*)
        dir="$HOME/.tmwid/state"
        mkdir -p "$dir"
        tmp="$dir/$sid.json.tmp.$$"
        printf '{"sessionId":"%s","status":"apiErr","cwd":"%s","pid":%d,"ts":%d}\\n' \
          "$sid" "$cwd" "$PPID" "$(date +%s)" > "$tmp" && mv "$tmp" "$dir/$sid.json"
        ;;
    esac
    exit 0
    """
}

public final class SettingsInjector {
    public typealias SettingsJSON = [String: Any]

    public let paths: Paths
    public init(paths: Paths) { self.paths = paths }

    public static func isCurrentTmwidHook(_ command: String) -> Bool {
        command.hasPrefix(HookMarker.current)
    }

    public static func isLegacyTmwidHook(_ command: String) -> Bool {
        HookMarker.legacyPrefixes.contains { command.hasPrefix($0) }
    }

    // MARK: - Read & Backup

    public func readSettings() throws -> SettingsJSON {
        let url = URL(fileURLWithPath: paths.claudeSettings)
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data)
        return json as? SettingsJSON ?? [:]
    }

    public func backupSettings() throws {
        guard FileManager.default.fileExists(atPath: paths.claudeSettings) else { return }
        try FileManager.default.createDirectory(
            atPath: paths.backupsDir, withIntermediateDirectories: true)
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate, .withTime]
        let ts = fmt.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let suffix = String(format: "%04x", UInt16.random(in: 0...UInt16.max))
        let dest = "\(paths.backupsDir)/settings-\(ts)-\(suffix).json"
        try FileManager.default.copyItem(atPath: paths.claudeSettings, toPath: dest)
        pruneBackups(keeping: 5)
    }

    private func pruneBackups(keeping n: Int) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: paths.backupsDir) else { return }
        let sorted = files.sorted().filter { $0.hasPrefix("settings-") }
        let excess = sorted.dropLast(n)
        for f in excess {
            try? fm.removeItem(atPath: "\(paths.backupsDir)/\(f)")
        }
    }

    // MARK: - Install

    public func install() throws {
        try backupSettings()
        var settings = try readSettings()
        var hooks = (settings["hooks"] as? SettingsJSON) ?? [:]

        let injections: [(event: String, matcher: String?, script: String)] = [
            ("UserPromptSubmit", nil, HookTemplate.scriptForStatus("working")),
            ("Stop", nil, HookTemplate.scriptForStatus("done")),
            ("PreToolUse", "AskUserQuestion", HookTemplate.scriptForStatus("ask")),
            ("PreToolUse", nil, HookTemplate.preMarkerScript),
            ("PostToolUse", "AskUserQuestion", HookTemplate.scriptForStatus("working")),
            ("PostToolUse", nil, HookTemplate.postToolResetScript),
            ("Notification", "permission_prompt", HookTemplate.scriptForStatus("ask")),
            ("Notification", "error", HookTemplate.errorScript),
            ("SessionEnd", nil, HookTemplate.cleanupScript),
        ]

        for inj in injections {
            hooks = upsertHook(
                into: hooks,
                event: inj.event,
                matcher: inj.matcher,
                command: inj.script
            )
        }

        settings["hooks"] = hooks
        try writeSettings(settings)
    }

    // MARK: - Uninstall

    public func uninstall() throws {
        try backupSettings()
        var settings = try readSettings()
        guard var hooks = settings["hooks"] as? SettingsJSON else { return }

        for event in hooks.keys {
            guard var groups = hooks[event] as? [[String: Any]] else { continue }
            for i in 0..<groups.count {
                var group = groups[i]
                var inner = (group["hooks"] as? [[String: Any]]) ?? []
                inner.removeAll { entry in
                    let cmd = (entry["command"] as? String) ?? ""
                    return Self.isCurrentTmwidHook(cmd) || Self.isLegacyTmwidHook(cmd)
                }
                group["hooks"] = inner
                groups[i] = group
            }
            // Remove empty groups
            groups.removeAll { ($0["hooks"] as? [[String: Any]])?.isEmpty ?? true }
            if groups.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = groups
            }
        }

        if hooks.isEmpty {
            settings.removeValue(forKey: "hooks")
        } else {
            settings["hooks"] = hooks
        }
        try writeSettings(settings)
    }

    // MARK: - Private

    private func upsertHook(
        into hooks: SettingsJSON,
        event: String,
        matcher: String?,
        command: String
    ) -> SettingsJSON {
        var hooks = hooks
        var eventGroups = (hooks[event] as? [[String: Any]]) ?? []

        let groupIdx = eventGroups.firstIndex { group in
            let m = group["matcher"] as? String
            return m == matcher
        }

        var targetGroup: [String: Any]
        if let idx = groupIdx {
            targetGroup = eventGroups[idx]
        } else {
            targetGroup = [:]
            if let m = matcher { targetGroup["matcher"] = m }
        }

        var inner = (targetGroup["hooks"] as? [[String: Any]]) ?? []
        let existingIdx = inner.firstIndex { entry in
            let cmd = (entry["command"] as? String) ?? ""
            return Self.isCurrentTmwidHook(cmd) || Self.isLegacyTmwidHook(cmd)
        }
        let newEntry: [String: Any] = ["type": "command", "command": command]
        if let idx = existingIdx {
            inner[idx] = newEntry
        } else {
            inner.append(newEntry)
        }
        targetGroup["hooks"] = inner

        if let idx = groupIdx {
            eventGroups[idx] = targetGroup
        } else {
            eventGroups.append(targetGroup)
        }
        hooks[event] = eventGroups
        return hooks
    }

    private func writeSettings(_ settings: SettingsJSON) throws {
        try FileManager.default.createDirectory(
            atPath: (paths.claudeSettings as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]
        )
        let tmp = paths.claudeSettings + ".tmp.\(getpid())"
        try data.write(to: URL(fileURLWithPath: tmp), options: .atomic)
        _ = rename(tmp, paths.claudeSettings)
    }
}
