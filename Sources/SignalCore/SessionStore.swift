import Foundation

/// Reads and writes per-session state files in `~/.claude/session-status/`.
/// The hook CLI writes; the menu bar app reads and prunes.
public enum SessionStore {
    public static let directory = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/session-status", isDirectory: true)

    /// Sessions with no PID recorded are pruned after this long without an update.
    /// Sessions with a PID are pruned as soon as the process is gone.
    private static let staleInterval: TimeInterval = 12 * 60 * 60

    private static func fileURL(for id: String) -> URL {
        directory.appendingPathComponent(id).appendingPathExtension("json")
    }

    public static func read(id: String) -> Session? {
        guard let data = try? Data(contentsOf: fileURL(for: id)) else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    public static func write(_ session: Session) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(session)
        try data.write(to: fileURL(for: session.id), options: .atomic)
    }

    public static func remove(id: String) {
        try? FileManager.default.removeItem(at: fileURL(for: id))
    }

    /// Loads all live sessions, deleting state files of dead or stale ones.
    /// Result is sorted most-urgent first, ties broken by recency.
    public static func loadLive() -> [Session] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return [] }

        let decoder = JSONDecoder()
        var sessions: [Session] = []
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let session = try? decoder.decode(Session.self, from: data)
            else { continue }

            if isDead(session) {
                try? fm.removeItem(at: file)
                continue
            }
            sessions.append(session)
        }
        return sessions.sorted {
            $0.state.severity != $1.state.severity
                ? $0.state.severity < $1.state.severity
                : $0.timestamp > $1.timestamp
        }
    }

    private static func isDead(_ session: Session) -> Bool {
        if let pid = session.pid {
            // kill(pid, 0) probes existence without signaling; ESRCH means gone.
            return kill(pid, 0) != 0 && errno == ESRCH
        }
        return Date().timeIntervalSince1970 - session.timestamp > staleInterval
    }
}
