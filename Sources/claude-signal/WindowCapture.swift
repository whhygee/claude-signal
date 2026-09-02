import AppKit
import CoreGraphics

/// Captures which terminal window a session lives in. Terminal apps like
/// Alacritty host every window in one process, so the PID alone cannot name
/// a window — but at session start the session's window is the frontmost
/// window of its terminal app, and CGWindowList reports windows in
/// front-to-back order.
enum WindowCapture {
    /// CGWindowID of the frontmost standard window of the GUI app hosting
    /// this process (the terminal, or the IDE for embedded terminals).
    static func currentWindowID() -> UInt32? {
        guard let appPID = guiAncestorPID() else { return nil }
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return nil }

        for entry in list {
            guard let owner = entry[kCGWindowOwnerPID as String] as? Int32, owner == appPID,
                  let layer = entry[kCGWindowLayer as String] as? Int, layer == 0,
                  let number = entry[kCGWindowNumber as String] as? UInt32
            else { continue }
            return number
        }
        return nil
    }

    private static func guiAncestorPID() -> pid_t? {
        ProcessTree.ancestry(of: getppid()).first { pid in
            NSRunningApplication(processIdentifier: pid)?.activationPolicy == .regular
        }
    }
}
