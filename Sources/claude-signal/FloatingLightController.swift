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
        applyOrientation(animated: true)
    }

    /// Enforces the stored orientation: fixes the view's layout axis, locks
    /// the resize aspect ratio, and reshapes/clamps the frame around its
    /// center. Also repairs a frame saved with bad proportions.
    private func applyOrientation(animated: Bool) {
        guard let panel, let lightView else { return }
        lightView.isVertical = orientation == .vertical

        let base = TrafficLightView.defaultSize
        let aspect = orientation == .vertical
            ? base
            : NSSize(width: base.height, height: base.width)
        panel.contentAspectRatio = aspect
        panel.minSize = scaled(aspect, by: 0.8)
        panel.maxSize = scaled(aspect, by: 3.0)

        // Rebuild the frame at the current scale (long side preserved),
        // clamped to bounds, centered where the panel already is.
        let frame = panel.frame
        let longSide = min(max(max(frame.width, frame.height), max(aspect.width, aspect.height) * 0.8),
                           max(aspect.width, aspect.height) * 3.0)
        let scale = longSide / max(aspect.width, aspect.height)
        let size = scaled(aspect, by: scale)
        let reshaped = NSRect(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        panel.setFrame(reshaped, display: true, animate: animated)
    }

    private func scaled(_ size: NSSize, by factor: CGFloat) -> NSSize {
        NSSize(width: size.width * factor, height: size.height * factor)
    }

    // MARK: - Panel lifecycle

    private func hide() {
        panel?.orderOut(nil)
        panel = nil
        lightView = nil
    }

    private func makePanel() -> NSPanel {
        let size = TrafficLightView.defaultSize
        let panel = NSPanel(
            contentRect: NSRect(origin: defaultOrigin(for: size), size: size),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
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
        applyOrientation(animated: false)
        panel?.orderFrontRegardless()
    }

    /// First-launch position: just under the menu bar, near the right edge.
    private func defaultOrigin(for size: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else { return NSPoint(x: 100, y: 100) }
        let frame = screen.visibleFrame
        return NSPoint(x: frame.maxX - size.width - 24, y: frame.maxY - size.height - 12)
    }
}
