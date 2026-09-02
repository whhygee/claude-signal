import Foundation

/// `claude-signal init` — installs the session-state hooks into ~/.claude/settings.json.
/// Idempotent: replaces any previous claude-signal hook entries, preserves everything else.
enum InitCommand {
    private static let eventStates: [(event: String, state: String)] = [
        ("SessionStart", "done"),
        ("UserPromptSubmit", "running"),
        ("Notification", "waiting"),
        ("Stop", "done"),
        ("SessionEnd", "end"),
    ]

    /// Substrings identifying hook commands owned by claude-signal (or its predecessors),
    /// so re-running init upgrades in place instead of stacking duplicates.
    private static let ownedCommandMarkers = ["claude-signal", "marshal", "claude-traffic-light"]

    static func run() {
        let settingsURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")

        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsURL) {
            guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                fail("could not parse \(settingsURL.path) — fix or move it, then re-run")
            }
            root = parsed
        }

        let executable = resolvedExecutablePath()
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for (event, state) in eventStates {
            var entries = hooks[event] as? [[String: Any]] ?? []
            entries.removeAll(where: isOwnedEntry)
            entries.append([
                "hooks": [
                    [
                        "type": "command",
                        "command": "\"\(executable)\" hook \(state)",
                        "async": true,
                    ]
                ]
            ])
            hooks[event] = entries
        }
        root["hooks"] = hooks

        do {
            let data = try JSONSerialization.data(
                withJSONObject: root,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            )
            try FileManager.default.createDirectory(
                at: settingsURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            fail("could not write \(settingsURL.path): \(error.localizedDescription)")
        }

        print("Installed claude-signal hooks into \(settingsURL.path)")
        print("New Claude Code sessions will now report their state.")
        print("Run the menu bar app with: claude-signal   (or: brew services start claude-signal)")
    }

    private static func isOwnedEntry(_ entry: [String: Any]) -> Bool {
        guard let hookList = entry["hooks"] as? [[String: Any]] else { return false }
        return hookList.contains { hook in
            guard let command = hook["command"] as? String else { return false }
            return ownedCommandMarkers.contains { command.contains($0) }
        }
    }

    /// Absolute path callers should use to invoke this binary. Prefers the
    /// PATH-visible location (e.g. the stable Homebrew symlink) over the
    /// physical path, which changes on every versioned upgrade.
    private static func resolvedExecutablePath() -> String {
        let argv0 = CommandLine.arguments[0]
        if argv0.contains("/") {
            return URL(fileURLWithPath: argv0).standardizedFileURL.path
        }
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in path.split(separator: ":") {
            let candidate = "\(directory)/\(argv0)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return Bundle.main.executablePath ?? argv0
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("claude-signal init: \(message)\n".utf8))
        exit(1)
    }
}
