import AppKit
import SignalCore

/// Optional floating traffic light: a small always-on-top, draggable panel
/// mirroring the aggregate session state. Toggled from the menu bar menu;
/// visibility and position persist across launches.
/// Layout axis of the floating light.
enum LightOrientation: String, CaseIterable {
    case vertical
    case horizontal

    var title: String { rawValue.capitalized }
}

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

/// Classic vertical three-lamp traffic light. The lamp for the current
/// aggregate state glows; the others stay dim. All lamps dim when no
/// sessions are active.
final class TrafficLightView: NSView {
    static let defaultSize = NSSize(width: 30, height: 78)

    private var worst: SessionState?
    private var count = 0

    /// Layout axis, set by the controller from the persisted orientation —
    /// never inferred from the frame's shape.
    var isVertical = true {
        didSet { needsDisplay = true }
    }

    private var isHovering = false

    override var mouseDownCanMoveWindow: Bool { true }

    // MARK: - Hover tracking (resize affordance)

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        needsDisplay = true
    }

    func render(worst: SessionState?, count: Int) {
        guard worst != self.worst || count != self.count else { return }
        self.worst = worst
        self.count = count
        toolTip = worst == nil
            ? "No active Claude sessions"
            : "\(count) Claude session\(count == 1 ? "" : "s") — \(worst!.rawValue)"
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let vertical = isVertical
        let cross = vertical ? bounds.width : bounds.height
        let mainLength = vertical ? bounds.height : bounds.width
        let cornerRadius = cross * 0.45
        let housing = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 1, dy: 1),
            xRadius: cornerRadius,
            yRadius: cornerRadius
        )
        NSColor.black.withAlphaComponent(0.6).setFill()
        housing.fill()

        let lamps: [(SessionState, NSColor)] = [
            (.waiting, .systemRed),
            (.running, .systemYellow),
            (.done, .systemGreen),
        ]
        // The aspect lock keeps proportions during resize; the main-axis cap
        // is a second line of defense so lamps can never overflow the housing.
        let diameter = min(cross * 0.6, mainLength * 0.25)
        let spacing = diameter / 3
        let groupLength = CGFloat(lamps.count) * diameter + CGFloat(lamps.count - 1) * spacing

        // Red is first: on top when vertical, on the left when horizontal.
        for (index, (state, color)) in lamps.enumerated() {
            let offset = CGFloat(index) * (diameter + spacing)
            let rect: NSRect
            if vertical {
                let top = bounds.midY + groupLength / 2 - diameter
                rect = NSRect(x: bounds.midX - diameter / 2, y: top - offset, width: diameter, height: diameter)
            } else {
                let left = bounds.midX - groupLength / 2
                rect = NSRect(x: left + offset, y: bounds.midY - diameter / 2, width: diameter, height: diameter)
            }
            drawLamp(in: rect, color: color, lit: state == worst)
        }

        if isHovering {
            drawResizeGrip()
        }
    }

    /// Resize affordance shown on hover: a short, fat, round-capped arc
    /// hugging the housing's bottom-right corner. Following the corner
    /// curve keeps it in the ring between the lamps and the border, so it
    /// never overlaps a lamp at any size.
    private func drawResizeGrip() {
        let cross = isVertical ? bounds.width : bounds.height
        let cornerRadius = cross * 0.45
        let cornerCenter = NSPoint(
            x: bounds.maxX - 1 - cornerRadius,
            y: bounds.minY + 1 + cornerRadius
        )
        let lineWidth = max(2.5, cross * 0.1)

        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: cornerCenter,
            radius: cornerRadius - lineWidth / 2 - 2,
            startAngle: -80,
            endAngle: -10
        )
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .round
        NSColor.white.withAlphaComponent(0.55).setStroke()
        arc.stroke()
    }

    private func drawLamp(in rect: NSRect, color: NSColor, lit: Bool) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        if lit {
            let glow = NSShadow()
            glow.shadowColor = color
            glow.shadowBlurRadius = rect.width / 3
            glow.set()
            color.setFill()
        } else {
            color.withAlphaComponent(0.18).setFill()
        }
        NSBezierPath(ovalIn: rect).fill()
    }
}
