import Foundation

/// Lifecycle state of a Claude Code session, as reported by its hooks.
public enum SessionState: String, Codable, Sendable {
    /// Blocked on the user: a permission prompt or an idle "waiting for input" notification.
    case waiting
    /// Claude is actively working on a prompt.
    case running
    /// The turn finished; results are ready to read.
    case done

    /// Lower value = more urgent. Used to pick the aggregate signal.
    public var severity: Int {
        switch self {
        case .waiting: return 0
        case .running: return 1
        case .done: return 2
        }
    }
}

/// One Claude Code session's last reported state.
public struct Session: Codable, Sendable {
    public let id: String
    public let state: SessionState
    /// PID of the session's `claude` process, used to detect dead sessions.
    public let pid: Int32?
    /// Working directory the session last reported.
    public let cwd: String
    /// Unix timestamp of the last state change.
    public let timestamp: TimeInterval
    /// CGWindowID of the terminal window hosting the session, captured at
    /// session start (frontmost window of the terminal app at that moment).
    public let windowID: UInt32?

    private enum CodingKeys: String, CodingKey {
        case id = "session_id"
        case state
        case pid
        case cwd
        case timestamp = "ts"
        case windowID = "window_id"
    }

    public init(
        id: String,
        state: SessionState,
        pid: Int32?,
        cwd: String,
        timestamp: TimeInterval,
        windowID: UInt32? = nil
    ) {
        self.id = id
        self.state = state
        self.pid = pid
        self.cwd = cwd
        self.timestamp = timestamp
        self.windowID = windowID
    }
}
