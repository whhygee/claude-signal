import AppKit
import SignalCore

/// Layout axis of the floating light.
enum LightOrientation: String, CaseIterable {
    case vertical
    case horizontal

    var title: String { rawValue.capitalized }
}

/// Optional floating traffic light: a small always-on-top, draggable panel
/// mirroring the aggregate session state. Toggled from the menu bar menu;
/// visibility, position, and orientation persist across launches.
final class FloatingLightController {
    private static let enabledDefaultsKey = "floatingLightEnabled"
    private static let orientationDefaultsKey = "floatingLightOrientation"
    private static let frameAutosaveName = "FloatingLight"

    private var panel: NSPanel?
    private var lightView: TrafficLightView?

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
    }

    private(set) var orientation: LightOrientation {
        get {
            UserDefaults.standard.string(forKey: Self.orientationDefaultsKey)
                .flatMap(LightOrientation.init(rawValue:)) ?? .vertical
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Self.orientationDefaultsKey) }
    }

    func applyPersistedState() {
        if isEnabled { show() }
    }

    func toggle() {
        let enable = !isEnabled
        UserDefaults.standard.set(enable, forKey: Self.enabledDefaultsKey)
        enable ? show() : hide()
    }

    func update(sessions: [Session]) {
        lightView?.render(worst: sessions.first?.state, count: sessions.count)
    }

    func setOrientation(_ newOrientation: LightOrientation) {
        guard newOrientation != orientation else { return }
        orientation = newOrientation
        reshape(animated: true)
    }

    static let minScale: CGFloat = 0.7
    static let maxScale: CGFloat = 3.0

    /// Current size as a multiple of the base size (1.0 = default).
    var scale: CGFloat {
        guard let panel else { return 1 }
        let base = TrafficLightView.defaultSize
        return max(panel.frame.width, panel.frame.height) / max(base.width, base.height)
    }

    func setScale(_ newScale: CGFloat) {
        reshape(scale: newScale, animated: false)
    }

    /// Rebuilds the frame from the stored orientation and the given scale
    /// (current scale if nil), centered where the panel already is. Also
    /// repairs a frame saved with bad proportions.
    private func reshape(scale requestedScale: CGFloat? = nil, animated: Bool) {
        guard let panel, let lightView else { return }
        lightView.isVertical = orientation == .vertical

        let base = TrafficLightView.defaultSize
        let aspect = orientation == .vertical
            ? base
            : NSSize(width: base.height, height: base.width)
        let clamped = min(max(requestedScale ?? scale, Self.minScale), Self.maxScale)

        let frame = panel.frame
        let size = NSSize(width: aspect.width * clamped, height: aspect.height * clamped)
        let reshaped = NSRect(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        panel.setFrame(reshaped, display: true, animate: animated)
    }

    // MARK: - Panel lifecycle

    private func hide() {
        panel?.orderOut(nil)
        panel = nil
        lightView = nil
    }

    private func makePanel() -> NSPanel {
        let size = TrafficLightView.defaultSize
        // No .resizable: the menu's Size slider is the only resize path.
        // Borderless edge-resize ignores contentAspectRatio, which allowed
        // off-aspect frames that skewed the lamp layout.
        let panel = NSPanel(
            contentRect: NSRect(origin: defaultOrigin(for: size), size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.setFrameAutosaveName(Self.frameAutosaveName)

        let view = TrafficLightView(frame: NSRect(origin: .zero, size: size))
        panel.contentView = view
        lightView = view
        return panel
    }

    private func show() {
        if panel == nil {
            panel = makePanel()
        }
        reshape(animated: false)
        panel?.orderFrontRegardless()
    }

    /// First-launch position: just under the menu bar, near the right edge.
    private func defaultOrigin(for size: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else { return NSPoint(x: 100, y: 100) }
        let frame = screen.visibleFrame
        return NSPoint(x: frame.maxX - size.width - 24, y: frame.maxY - size.height - 12)
    }
}
