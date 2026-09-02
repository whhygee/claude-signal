import AppKit
import SignalCore

/// Optional floating traffic light: a small always-on-top, draggable panel
/// mirroring the aggregate session state. Toggled from the menu bar menu;
/// visibility and position persist across launches.
final class FloatingLightController {
    private static let enabledDefaultsKey = "floatingLightEnabled"
    private static let frameAutosaveName = "FloatingLight"

    private var panel: NSPanel?
    private var lightView: TrafficLightView?

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
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

    /// Swaps width and height around the panel's center. Orientation is
    /// derived from the frame's shape, so this flips vertical ↔ horizontal;
    /// frame autosave persists the result.
    func rotate() {
        guard let panel else { return }
        let frame = panel.frame
        let rotated = NSRect(
            x: frame.midX - frame.height / 2,
            y: frame.midY - frame.width / 2,
            width: frame.height,
            height: frame.width
        )
        panel.setFrame(rotated, display: true, animate: true)
    }

    // MARK: - Panel lifecycle

    private func show() {
        if panel == nil {
            let panel = makePanel()
            self.panel = panel
        }
        panel?.orderFrontRegardless()
    }

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
        panel.minSize = NSSize(width: 22, height: 22)
        panel.maxSize = NSSize(width: 400, height: 400)
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

    override var mouseDownCanMoveWindow: Bool { true }

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
        // Orientation follows the frame's shape: taller than wide draws a
        // vertical light, wider than tall a horizontal one. Lamp geometry
        // scales with the cross-axis so resizing scales the whole light.
        let vertical = bounds.height >= bounds.width
        let cross = vertical ? bounds.width : bounds.height
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
        let diameter = cross * 0.6
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
