import AppKit

enum MenuBarIconRenderer {
    static func makeIcon(utilization: Double, status: String, monochrome: Bool = false) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 6.5
            let lineWidth: CGFloat = 3.0

            // Track: visible full circle
            let track = NSBezierPath(ovalIn: NSRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            ))
            track.lineWidth = lineWidth
            NSColor.white.withAlphaComponent(0.35).setStroke()
            track.stroke()

            // Color based on status and utilization
            let color: NSColor
            if monochrome {
                color = NSColor.white
            } else if status == "rejected" {
                color = .systemRed
            } else if utilization >= 0.8 {
                color = .systemRed
            } else if utilization >= 0.5 {
                color = .systemOrange
            } else if status == "loading" || status == "unknown" {
                color = NSColor.white.withAlphaComponent(0.5)
            } else {
                color = NSColor(calibratedRed: 0.2, green: 0.9, blue: 0.4, alpha: 1.0)
            }

            // Progress arc: 12 o'clock, clockwise
            let clamped = min(1.0, max(0.0, utilization))
            if clamped > 0 {
                let arc = NSBezierPath()
                arc.appendArc(
                    withCenter: center,
                    radius: radius,
                    startAngle: 90,
                    endAngle: 90 - CGFloat(clamped) * 360,
                    clockwise: true
                )
                arc.lineWidth = lineWidth
                arc.lineCapStyle = .round
                color.setStroke()
                arc.stroke()
            }

            return true
        }
        image.isTemplate = monochrome
        return image
    }
}
