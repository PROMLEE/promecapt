import AppKit

/// One capture-frame mark for the app, menu bar and documentation assets.
enum CaptureMark {
    static func draw(in rect: NSRect, color: NSColor) {
        let path = NSBezierPath()
        path.lineWidth = rect.width * 0.082
        path.lineCapStyle = .round; path.lineJoinStyle = .round
        for (x, y, dx, dy): (CGFloat, CGFloat, CGFloat, CGFloat) in [(0,0,1,1),(1,0,-1,1),(0,1,1,-1),(1,1,-1,-1)] {
            let corner = NSPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
            path.move(to: NSPoint(x: corner.x + dx * rect.width * 0.25, y: corner.y))
            path.line(to: corner)
            path.line(to: NSPoint(x: corner.x, y: corner.y + dy * rect.height * 0.25))
        }
        color.setStroke(); path.stroke(); color.setFill()
        let diameter = rect.width * 0.15
        NSBezierPath(ovalIn: NSRect(x: rect.midX - diameter / 2, y: rect.midY - diameter / 2, width: diameter, height: diameter)).fill()
    }
}
