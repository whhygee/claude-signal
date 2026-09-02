import AppKit

/// `claude-signal` (default) — runs the menu bar app.
enum MenuBarCommand {
    static func run() -> Never {
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
