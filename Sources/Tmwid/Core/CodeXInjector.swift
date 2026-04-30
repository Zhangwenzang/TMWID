import Foundation

enum CodeXInjectorError: Error {
    case hooksFileExists
}

public final class CodeXInjector {
    public let paths: Paths

    public init(paths: Paths) {
        self.paths = paths
    }

    public func enableHooksFeature() throws {
        try FileManager.default.createDirectory(
            atPath: paths.codexConfigDir,
            withIntermediateDirectories: true
        )

        let tomlPath = paths.codexConfigTOML

        // 检查是否已启用
        if FileManager.default.fileExists(atPath: tomlPath) {
            let content = try String(contentsOfFile: tomlPath, encoding: .utf8)
            let pattern = #"(?m)^\s*codex_hooks\s*=\s*true"#
            if content.range(of: pattern, options: .regularExpression) != nil {
                return
            }
        }

        // 追加模式：不解析现有内容，直接追加
        let append = "\n\n[features]\ncodex_hooks = true\n"

        if !FileManager.default.fileExists(atPath: tomlPath) {
            try append.write(toFile: tomlPath, atomically: true, encoding: .utf8)
        } else {
            let existing = try String(contentsOfFile: tomlPath, encoding: .utf8)
            try (existing + append).write(toFile: tomlPath, atomically: true, encoding: .utf8)
        }
    }

    public func writeHooksJSON() throws {
        if FileManager.default.fileExists(atPath: paths.codexHooksJSON) {
            throw CodeXInjectorError.hooksFileExists
        }

        try FileManager.default.createDirectory(
            atPath: paths.codexConfigDir,
            withIntermediateDirectories: true
        )

        let hooksStructure: [String: Any] = [
            "hooks": [
                "UserPromptSubmit": [
                    ["hooks": [["type": "command", "command": HookTemplate.scriptForStatus("working")]]]
                ],
                "Stop": [
                    ["hooks": [["type": "command", "command": HookTemplate.scriptForStatus("done")]]]
                ],
                "PermissionRequest": [
                    ["hooks": [["type": "command", "command": HookTemplate.scriptForStatus("ask")]]]
                ]
            ]
        ]

        let data = try JSONSerialization.data(
            withJSONObject: hooksStructure,
            options: [.prettyPrinted, .sortedKeys]
        )

        let tmp = paths.codexHooksJSON + ".tmp.\(getpid())"
        try data.write(to: URL(fileURLWithPath: tmp), options: .atomic)
        _ = rename(tmp, paths.codexHooksJSON)
    }
}
