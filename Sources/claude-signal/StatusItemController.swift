import AppKit
import SignalCore

/// Owns the menu bar item: one aggregate traffic-light dot plus a
/// per-session dropdown. Refreshes on a timer; the menu itself is
/// rebuilt lazily via NSMenuDelegate so it is never mutated while open.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let floatingLight = FloatingLightController()
    private var timer: Timer?
    private var sessions: [Session] = []

    private static let refreshInterval: TimeInterval = 1.0

    func start() {
        menu.delegate = self
        statusItem.menu = menu
        floatingLight.applyPersistedState()
        refresh()
        let timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = Self.refreshInterval / 4
        self.timer = timer
    }

    // MARK: - Rendering

    private func refresh() {
        sessions = SessionStore.loadLive()
        statusItem.button?.attributedTitle = title(for: sessions)
        floatingLight.update(sessions: sessions)
    }

    /// Aggregate signal: the worst state across sessions wins
    /// (sessions arrive sorted most-urgent first).
    private func title(for sessions: [Session]) -> NSAttributedString {
        let title = NSMutableAttributedString()
        guard let worst = sessions.first else {
            title.append(NSAttributedString(string: "○", attributes: [
                .foregroundColor: NSColor.tertiaryLabelColor,
                .font: NSFont.systemFont(ofSize: 14),
            ]))
            return title
        }
        title.append(NSAttributedString(string: "●", attributes: [
            .foregroundColor: worst.state.color,
            .font: NSFont.systemFont(ofSize: 14),
        ]))
        if sessions.count > 1 {
            title.append(NSAttributedString(string: " \(sessions.count)", attributes: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.systemFont(ofSize: 11),
            ]))
        }
        return title
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if sessions.isEmpty {
            menu.addItem(NSMenuItem(title: "No active Claude sessions", action: nil, keyEquivalent: ""))
        }
        for session in sessions {
            menu.addItem(menuItem(for: session))
        }

        menu.addItem(.separator())

        let floating = NSMenuItem(title: "Floating Light", action: #selector(toggleFloatingLight), keyEquivalent: "")
        floating.target = self
        floating.state = floatingLight.isEnabled ? .on : .off
        menu.addItem(floating)

        if floatingLight.isEnabled {
            let orientationItem = NSMenuItem(title: "Orientation", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for orientation in LightOrientation.allCases {
                let choice = NSMenuItem(title: orientation.title, action: #selector(setOrientation(_:)), keyEquivalent: "")
                choice.target = self
                choice.representedObject = orientation
                choice.state = floatingLight.orientation == orientation ? .on : .off
                submenu.addItem(choice)
            }
            orientationItem.submenu = submenu
            menu.addItem(orientationItem)

            menu.addItem(sizeSliderItem())
        }

        let clear = NSMenuItem(title: "Clear All", action: #selector(clearAll), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)

        menu.addItem(NSMenuItem(title: "Quit Claude Signal",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
    }

    private func menuItem(for session: Session) -> NSMenuItem {
        let directory = session.cwd.isEmpty ? "?" : (session.cwd as NSString).lastPathComponent
        let time = Self.timeFormatter.string(from: Date(timeIntervalSince1970: session.timestamp))

        let item = NSMenuItem()
        let label = NSMutableAttributedString()
        label.append(NSAttributedString(string: "● ", attributes: [.foregroundColor: session.state.color]))
        label.append(NSAttributedString(string: "\(directory)  —  \(session.state.rawValue)  (\(time))"))
        item.attributedTitle = label
        item.toolTip = "\(session.cwd)\n\(session.id)"
        if session.pid != nil {
            item.representedObject = session
            item.action = #selector(focusSession(_:))
            item.target = self
            item.toolTip = "Click to open this session's window\n\(session.cwd)\n\(session.id)"
        }
        return item
    }

    /// Menu row hosting a live slider that scales the floating light.
    private func sizeSliderItem() -> NSMenuItem {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 26))

        let label = NSTextField(labelWithString: "Size")
        label.font = .menuFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: 14, y: 5, width: 34, height: 16)
        container.addSubview(label)

        let slider = NSSlider(
            value: Double(floatingLight.scale),
            minValue: Double(FloatingLightController.minScale),
            maxValue: Double(FloatingLightController.maxScale),
            target: self,
            action: #selector(sizeSliderChanged(_:))
        )
        slider.isContinuous = true
        slider.controlSize = .small
        slider.frame = NSRect(x: 52, y: 4, width: 154, height: 18)
        container.addSubview(slider)

        let item = NSMenuItem()
        item.view = container
        return item
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    // MARK: - Actions

    /// Brings the app window hosting this session's claude process to the
    /// front: the first ancestor that is a regular GUI app (the terminal
    /// window's process, or the IDE for embedded terminals).
    @objc private func focusSession(_ sender: NSMenuItem) {
        guard let session = sender.representedObject as? Session, let pid = session.pid else { return }
        for ancestor in ProcessTree.ancestry(of: pid) {
            guard let app = NSRunningApplication(processIdentifier: ancestor),
                  app.activationPolicy == .regular
            else { continue }
            bringToFront(app)
            return
        }
    }

    /// Activation from an accessory app is refused in several ways across
    /// macOS versions, so cascade: cooperative activate, legacy forced
    /// activate, then Dock-click semantics via NSWorkspace (which reliably
    /// raises a running app without spawning a second instance).
    private func bringToFront(_ app: NSRunningApplication) {
        app.unhide()
        if app.activate(options: [.activateAllWindows]) { return }
        if app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) { return }
        guard let url = app.bundleURL else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    @objc private func toggleFloatingLight() {
        floatingLight.toggle()
        floatingLight.update(sessions: sessions)
    }

    @objc private func setOrientation(_ sender: NSMenuItem) {
        guard let orientation = sender.representedObject as? LightOrientation else { return }
        floatingLight.setOrientation(orientation)
    }

    @objc private func sizeSliderChanged(_ sender: NSSlider) {
        floatingLight.setScale(CGFloat(sender.doubleValue))
    }

    @objc private func clearAll() {
        for session in sessions {
            SessionStore.remove(id: session.id)
        }
        refresh()
    }
}

private extension SessionState {
    var color: NSColor {
        switch self {
        case .waiting: return .systemRed
        case .running: return .systemYellow
        case .done: return .systemGreen
        }
    }
}
