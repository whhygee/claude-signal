import Foundation

/// `claude-signal init` — installs the session-state hooks into ~/.claude/settings.json.
/// Idempotent: replaces any previous claude-signal hook entries, preserves everything else.
enum InitCommand {
    private static let eventStates: [(event: String, state: String)] = [
        // `start` marks the session ready AND captures its terminal window.
        ("SessionStart", "start"),
        ("UserPromptSubmit", "running"),
        // `notify` escalates to waiting only mid-turn; idle notifications
        // after a finished turn keep the session green.
        ("Notification", "notify"),
        // First tool run after an approved permission clears the red state.
        ("PostToolUse", "running"),
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

        let executable = Executable.currentPath()
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

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("claude-signal init: \(message)\n".utf8))
        exit(1)
    }
}
