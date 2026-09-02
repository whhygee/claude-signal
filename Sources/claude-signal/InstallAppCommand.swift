import Foundation

/// `claude-signal install-app` — assembles "Claude Signal.app" in
/// ~/Applications so Spotlight can launch the menu bar app, and points the
/// LaunchAgent at the bundle so login starts and Spotlight starts share one
/// binary (and one preferences domain).
enum InstallAppCommand {
    private static let bundleID = "com.whygee.claude-signal"
    private static let agentLabel = "com.whygee.claude-signal"

    static func run() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let appURL = home.appendingPathComponent("Applications/Claude Signal.app")
        let macOSDir = appURL.appendingPathComponent("Contents/MacOS")
        let bundledBinary = macOSDir.appendingPathComponent("claude-signal")

        do {
            try fm.createDirectory(at: macOSDir, withIntermediateDirectories: true)
            try infoPlist.write(
                to: appURL.appendingPathComponent("Contents/Info.plist"),
                atomically: true,
                encoding: .utf8
            )
            // Remove before copying: overwriting a Mach-O in place invalidates
            // the kernel's cached code signature (execs die with SIGKILL).
            try? fm.removeItem(at: bundledBinary)
            try fm.copyItem(at: URL(fileURLWithPath: Executable.currentPath()), to: bundledBinary)
        } catch {
            fail("could not assemble \(appURL.path): \(error.localizedDescription)")
        }

        installLaunchAgent(executable: bundledBinary.path, home: home)

        print("Installed \(appURL.path)")
        print("Spotlight: search “Claude Signal”. Login start: LaunchAgent \(agentLabel) (reloaded).")
    }

    private static func installLaunchAgent(executable: String, home: URL) {
        let agentURL = home.appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(agentLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executable)</string>
                <string>menubar</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <dict>
                <key>SuccessfulExit</key>
                <false/>
            </dict>
        </dict>
        </plist>
        """
        do {
            try FileManager.default.createDirectory(
                at: agentURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try plist.write(to: agentURL, atomically: true, encoding: .utf8)
        } catch {
            fail("could not write \(agentURL.path): \(error.localizedDescription)")
        }

        let uid = getuid()
        launchctl(["bootout", "gui/\(uid)/\(agentLabel)"]) // may fail if not loaded; fine
        Thread.sleep(forTimeInterval: 1)
        launchctl(["bootstrap", "gui/\(uid)", agentURL.path])
    }

    @discardableResult
    private static func launchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    private static var infoPlist: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>\(bundleID)</string>
            <key>CFBundleName</key>
            <string>Claude Signal</string>
            <key>CFBundleDisplayName</key>
            <string>Claude Signal</string>
            <key>CFBundleExecutable</key>
            <string>claude-signal</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
            <key>CFBundleShortVersionString</key>
            <string>0.0.2</string>
            <key>LSMinimumSystemVersion</key>
            <string>13.0</string>
            <key>LSUIElement</key>
            <true/>
            <key>NSHighResolutionCapable</key>
            <true/>
        </dict>
        </plist>
        """
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("claude-signal install-app: \(message)\n".utf8))
        exit(1)
    }
}
