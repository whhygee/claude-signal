import AppKit
import SignalCore

/// Classic three-lamp traffic light. The lamp for the current aggregate
/// state glows; the others stay dim. A tail strip at the end of the housing
/// is a dedicated resize lever: hovering reveals a curved grip there, and
/// dragging it scales the light (the rest of the housing moves the window).
final class TrafficLightView: NSView {
    static let defaultSize = NSSize(width: 30, height: 84)

    private let grip = ResizeGripView()
    private var worst: SessionState?
    private var count = 0
    private var isHovering = false

    /// Layout axis, set by the controller from the persisted orientation —
    /// never inferred from the frame's shape.
    var isVertical = true {
        didSet {
            layoutGrip()
            needsDisplay = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(grip)
        layoutGrip()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

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

    // MARK: - Layout

    /// Fraction of the main axis reserved for the resize lever.
    private var gripStripLength: CGFloat {
        (isVertical ? bounds.width : bounds.height) * 0.4
    }

    private func layoutGrip() {
        grip.frame = isVertical
            ? NSRect(x: 0, y: 0, width: bounds.width, height: gripStripLength)
            : NSRect(x: bounds.width - gripStripLength, y: 0, width: gripStripLength, height: bounds.height)
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutGrip()
    }

    // MARK: - Hover tracking (grip reveal)

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

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let cross = isVertical ? bounds.width : bounds.height
        let cornerRadius = cross * 0.45
        let housing = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 1, dy: 1),
            xRadius: cornerRadius,
            yRadius: cornerRadius
        )
        NSColor.black.withAlphaComponent(0.6).setFill()
        housing.fill()

        drawLamps(cross: cross)
        if isHovering {
            drawGripHandle(cross: cross)
        }
    }

    private func drawLamps(cross: CGFloat) {
        let lamps: [(SessionState, NSColor)] = [
            (.waiting, .systemRed),
            (.running, .systemYellow),
            (.done, .systemGreen),
        ]
        // Lamps live in the region outside the grip strip (above it when
        // vertical, left of it when horizontal); red stays first.
        let mainLength = (isVertical ? bounds.height : bounds.width) - gripStripLength
        let diameter = min(cross * 0.6, mainLength * 0.28)
        let spacing = diameter / 3
        let groupLength = CGFloat(lamps.count) * diameter + CGFloat(lamps.count - 1) * spacing

        for (index, (state, color)) in lamps.enumerated() {
            let offset = CGFloat(index) * (diameter + spacing)
            let rect: NSRect
            if isVertical {
                let regionMidY = gripStripLength + mainLength / 2
                let top = regionMidY + groupLength / 2 - diameter
                rect = NSRect(x: bounds.midX - diameter / 2, y: top - offset, width: diameter, height: diameter)
            } else {
                let regionMidX = mainLength / 2
                let left = regionMidX - groupLength / 2
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

    /// Fat round-capped arc in the grip strip, following the housing's end
    /// curve — the visual for the resize lever.
    private func drawGripHandle(cross: CGFloat) {
        let radius = cross * 0.45
        let lineWidth = max(3, cross * 0.12)
        let arcRadius = radius - lineWidth / 2 - 2.5

        let center: NSPoint
        let startAngle: CGFloat
        let endAngle: CGFloat
        if isVertical {
            // Smile along the bottom end of the housing.
            center = NSPoint(x: bounds.midX, y: bounds.minY + 1 + radius)
            startAngle = -140
            endAngle = -40
        } else {
            // Bracket along the right end of the housing.
            center = NSPoint(x: bounds.maxX - 1 - radius, y: bounds.midY)
            startAngle = -50
            endAngle = 50
        }

        let arc = NSBezierPath()
        arc.appendArc(withCenter: center, radius: arcRadius, startAngle: startAngle, endAngle: endAngle)
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .round
        NSColor.white.withAlphaComponent(0.6).setStroke()
        arc.stroke()
    }
}

/// Invisible drag handle covering the grip strip. Opts out of
/// window-background moves and implements aspect-preserving resize itself,
/// anchored at the window's top-left, clamped to the window's min/max size.
private final class ResizeGripView: NSView {
    private var startFrame: NSRect = .zero
    private var startMouse: NSPoint = .zero

    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        startFrame = window.frame
        startMouse = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        // Dragging away from the window's top-left (right or down) grows.
        let growth = max(mouse.x - startMouse.x, startMouse.y - mouse.y)

        let longSide = max(startFrame.width, startFrame.height)
        var scale = (longSide + growth) / longSide
        let minScale = max(window.minSize.width / startFrame.width,
                           window.minSize.height / startFrame.height)
        let maxScale = min(window.maxSize.width / startFrame.width,
                           window.maxSize.height / startFrame.height)
        scale = min(max(scale, minScale), maxScale)

        let size = NSSize(width: startFrame.width * scale, height: startFrame.height * scale)
        let frame = NSRect(
            x: startFrame.minX,
            y: startFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        window.setFrame(frame, display: true)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}
