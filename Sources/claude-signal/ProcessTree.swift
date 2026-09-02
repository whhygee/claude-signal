import Darwin
import Foundation

enum ProcessTree {
    /// Walks up from this process to find the enclosing `claude` CLI process.
    /// The hook runs as `claude` → shell → `claude-signal`, so a few hops suffice.
    static func findClaudePID() -> pid_t? {
        var pid = getppid()
        for _ in 0..<10 {
            guard pid > 1, let process = info(of: pid) else { return nil }
            if isClaude(process) {
                return pid
            }
            pid = process.parent
        }
        return nil
    }

    /// PIDs from `pid` up toward launchd, `pid` itself included.
    static func ancestry(of pid: pid_t) -> [pid_t] {
        var chain: [pid_t] = []
        var current = pid
        for _ in 0..<15 {
            guard current > 1 else { break }
            chain.append(current)
            guard let process = info(of: current) else { break }
            current = process.parent
        }
        return chain
    }

    private struct Info {
        let parent: pid_t
        let command: String
        let executablePath: String?
    }

    /// The claude CLI executes a version-named binary, so its kernel comm
    /// is e.g. "2.1.252" — only the executable path reliably identifies it.
    /// "node" covers installs that run the CLI through Node directly.
    private static func isClaude(_ process: Info) -> Bool {
        if process.command == "claude" || process.command == "node" {
            return true
        }
        return process.executablePath?.localizedCaseInsensitiveContains("claude") ?? false
    }

    private static func info(of pid: pid_t) -> Info? {
        var proc = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &proc, &size, nil, 0) == 0, size > 0 else { return nil }

        let command = withUnsafePointer(to: proc.kp_proc.p_comm) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) {
                String(cString: $0)
            }
        }
        return Info(parent: proc.kp_eproc.e_ppid, command: command, executablePath: executablePath(of: pid))
    }

    private static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }
}
