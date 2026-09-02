import AppKit

/// `claude-signal` (default) — runs the menu bar app.
enum MenuBarCommand {
    static func run() -> Never {
        // Single instance: Spotlight and the LaunchAgent can both launch us;
        // the second copy would draw a duplicate menu bar item.
        let lockPath = NSString(string: "~/.claude/session-status/.menubar.lock").expandingTildeInPath
        FileManager.default.createFile(atPath: lockPath, contents: nil)
        let lockFD = open(lockPath, O_WRONLY)
        if lockFD < 0 || flock(lockFD, LOCK_EX | LOCK_NB) != 0 {
            exit(0) // Another instance holds the lock (released on its exit).
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
        exit(0)
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = StatusItemController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
    }
}
