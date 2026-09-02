import Foundation
import SignalCore

/// `claude-signal hook <state>` — invoked by Claude Code lifecycle hooks.
/// Reads the hook event JSON from stdin and records the session's state.
/// `end` removes the session's state file.
enum HookCommand {
    private struct HookEvent: Decodable {
        let sessionID: String
        let cwd: String?

        private enum CodingKeys: String, CodingKey {
            case sessionID = "session_id"
            case cwd
        }
    }

    static func run(arguments: [String]) {
        guard arguments.count == 1 else {
            FileHandle.standardError.write(Data("usage: claude-signal hook <waiting|running|done|notify|end>\n".utf8))
            exit(64) // EX_USAGE
        }
        let argument = arguments[0]

        let input = FileHandle.standardInput.readDataToEndOfFile()
        guard let event = try? JSONDecoder().decode(HookEvent.self, from: input) else {
            exit(0) // Malformed event; never fail the session over telemetry.
        }

        if argument == "end" {
            SessionStore.remove(id: event.sessionID)
            exit(0)
        }

        // Notifications fire both for permission prompts (session genuinely
        // blocked) and for plain idle after a finished turn. A `done` session
        // is not blocked — only escalate to `waiting` while mid-turn.
        if argument == "notify" {
            if SessionStore.read(id: event.sessionID)?.state == .done {
                exit(0)
            }
            record(state: .waiting, event: event)
            exit(0)
        }

        guard let state = SessionState(rawValue: argument) else {
            FileHandle.standardError.write(Data("claude-signal hook: unknown state '\(argument)'\n".utf8))
            exit(64)
        }
        record(state: state, event: event)
    }

    private static func record(state: SessionState, event: HookEvent) {
        let session = Session(
            id: event.sessionID,
            state: state,
            pid: ProcessTree.findClaudePID(),
            cwd: event.cwd ?? "",
            timestamp: Date().timeIntervalSince1970
        )
        try? SessionStore.write(session)
    }
}
