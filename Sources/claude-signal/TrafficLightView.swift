import AppKit
import SignalCore

/// Boxy three-segment traffic light, styled after a real signal head: a
/// near-black housing split into equal segments, one glossy lamp per
/// segment. The lamp for the current aggregate state glows; the others sit
/// dark. The whole view drags the window; sizing happens via the menu.
final class TrafficLightView: NSView {
    static let defaultSize = NSSize(width: 34, height: 96)

    private var worst: SessionState?
    private var count = 0

    /// Layout axis, set by the controller from the persisted orientation —
    /// never inferred from the frame's shape.
    var isVertical = true {
        didSet { needsDisplay = true }
    }

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

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let cross = isVertical ? bounds.width : bounds.height
        let body = bounds.insetBy(dx: 1, dy: 1)
        let cornerRadius = cross * 0.14

        let housing = NSBezierPath(roundedRect: body, xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor(white: 0.08, alpha: 0.92).setFill()
        housing.fill()
        NSColor(white: 1.0, alpha: 0.08).setStroke()
        housing.lineWidth = 1
        housing.stroke()

        let lamps: [(SessionState, NSColor)] = [
            (.waiting, .systemRed),
            (.running, .systemYellow),
            (.done, .systemGreen),
        ]
        let segmentLength = (isVertical ? body.height : body.width) / CGFloat(lamps.count)

        // Red is first: on top when vertical, on the left when horizontal.
        for (index, (state, color)) in lamps.enumerated() {
            let segment: NSRect
            if isVertical {
                segment = NSRect(
                    x: body.minX,
                    y: body.maxY - CGFloat(index + 1) * segmentLength,
                    width: body.width,
                    height: segmentLength
                )
            } else {
                segment = NSRect(
                    x: body.minX + CGFloat(index) * segmentLength,
                    y: body.minY,
                    width: segmentLength,
                    height: body.height
                )
            }

            if index > 0 {
                drawDivider(before: segment)
            }
            drawLamp(in: segment, color: color, lit: state == worst)
        }
    }

    /// Thin seam between segments, like the joints of a real signal head.
    private func drawDivider(before segment: NSRect) {
        let seam = NSBezierPath()
        if isVertical {
            seam.move(to: NSPoint(x: segment.minX + 2, y: segment.maxY))
            seam.line(to: NSPoint(x: segment.maxX - 2, y: segment.maxY))
        } else {
            seam.move(to: NSPoint(x: segment.minX, y: segment.minY + 2))
            seam.line(to: NSPoint(x: segment.minX, y: segment.maxY - 2))
        }
        seam.lineWidth = 1
        NSColor(white: 0, alpha: 0.55).setStroke()
        seam.stroke()
    }

    private func drawLamp(in segment: NSRect, color: NSColor, lit: Bool) {
        let diameter = min(segment.width, segment.height) * 0.78
        let rect = NSRect(
            x: segment.midX - diameter / 2,
            y: segment.midY - diameter / 2,
            width: diameter,
            height: diameter
        )
        let circle = NSBezierPath(ovalIn: rect)

        NSGraphicsContext.saveGraphicsState()
        if lit {
            let glow = NSShadow()
            glow.shadowColor = color
            glow.shadowBlurRadius = diameter / 3
            glow.set()
            color.setFill()
            circle.fill()
        }
        NSGraphicsContext.restoreGraphicsState()

        // Glossy face: radial gradient with an off-center highlight, matching
        // the lens look of a real signal lamp. Unlit lamps keep a dark tint
        // of their hue so the fixture still reads as a traffic light.
        let gradient: NSGradient?
        if lit {
            gradient = NSGradient(colors: [
                color.blended(withFraction: 0.75, of: .white) ?? color,
                color,
                color.blended(withFraction: 0.35, of: .black) ?? color,
            ], atLocations: [0.0, 0.55, 1.0], colorSpace: .deviceRGB)
        } else {
            let dark = color.blended(withFraction: 0.65, of: .black) ?? color
            gradient = NSGradient(colors: [
                dark.withAlphaComponent(0.5),
                dark.withAlphaComponent(0.35),
            ], atLocations: [0.0, 1.0], colorSpace: .deviceRGB)
        }
        gradient?.draw(in: circle, relativeCenterPosition: NSPoint(x: -0.2, y: 0.25))

        // Bezel ring around the lens.
        NSColor(white: 0, alpha: 0.6).setStroke()
        circle.lineWidth = max(1, diameter * 0.05)
        circle.stroke()
    }
}
