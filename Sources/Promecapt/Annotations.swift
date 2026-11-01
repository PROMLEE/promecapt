import AppKit

struct AnnotationColor: Codable, Equatable {
    var red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat
    init(_ color: NSColor) {
        let c = color.usingColorSpace(.sRGB) ?? .black
        red = c.redComponent; green = c.greenComponent; blue = c.blueComponent; alpha = c.alphaComponent
    }
    var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }
}

struct AnnotationObject: Codable, Identifiable, Equatable {
    var id = UUID()
    var tool: DrawingTool
    var points: [NSPoint]
    var color: AnnotationColor
    var lineWidth: CGFloat
    var strength: CGFloat
    var concealStyle: ConcealStyle
    var text = ""

    var bounds: NSRect {
        guard let first = points.first else { return .zero }
        if tool == .number {
            let diameter = max(24, lineWidth * 8)
            return NSRect(x: first.x - diameter / 2, y: first.y - diameter / 2, width: diameter, height: diameter)
        }
        if tool == .text {
            let size = (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: max(18, lineWidth * 5))])
            return NSRect(origin: first, size: NSSize(width: max(4, size.width), height: max(4, size.height)))
        }
        let xs = points.map(\.x), ys = points.map(\.y)
        return NSRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }
    mutating func move(dx: CGFloat, dy: CGFloat) {
        points = points.map { NSPoint(x: $0.x + dx, y: $0.y + dy) }
    }
    mutating func resize(to rect: NSRect) {
        let old = bounds
        if tool == .number {
            lineWidth = max(3, min(rect.width, rect.height) / 8)
            points = [NSPoint(x: rect.midX, y: rect.midY)]
        } else if tool == .text {
            lineWidth = max(1, lineWidth * rect.height / max(1, old.height))
            points = [rect.origin]
        } else {
            points = points.map { NSPoint(x: rect.minX + ($0.x - old.minX) / max(1, old.width) * rect.width,
                                         y: rect.minY + ($0.y - old.minY) / max(1, old.height) * rect.height) }
        }
    }
    func contains(_ point: NSPoint, tolerance: CGFloat) -> Bool {
        let b = bounds
        guard b.insetBy(dx: -tolerance - lineWidth, dy: -tolerance - lineWidth).contains(point) else { return false }
        if tool == .number { return hypot(point.x - b.midX, point.y - b.midY) <= b.width / 2 + tolerance }
        if tool == .conceal || tool == .text { return b.insetBy(dx: -tolerance, dy: -tolerance).contains(point) }
        if tool == .rectangle {
            return !b.insetBy(dx: tolerance + lineWidth / 2, dy: tolerance + lineWidth / 2).contains(point)
        }
        if tool == .ellipse {
            let rx = max(1, b.width / 2), ry = max(1, b.height / 2)
            let radius = hypot((point.x - b.midX) / rx, (point.y - b.midY) / ry)
            return abs(radius - 1) * min(rx, ry) <= tolerance + lineWidth / 2
        }
        let reach = tolerance + lineWidth * (tool == .marker ? 2.5 : 0.5)
        return zip(points, points.dropFirst()).contains { a, z in
            let dx = z.x - a.x, dy = z.y - a.y
            let t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / max(0.001, dx * dx + dy * dy)))
            return hypot(point.x - a.x - t * dx, point.y - a.y - t * dy) <= reach
        }
    }
    func applying(to image: NSImage) -> NSImage {
        if tool == .conceal && concealStyle != .blackbox {
            return Imaging.filtered(image, rect: bounds, mosaic: concealStyle == .mosaic, strength: strength)
        }
        return Imaging.render(size: image.size) {
            image.draw(at: .zero, from: .zero, operation: .copy, fraction: 1)
            draw()
        }
    }
    func draw() {
        guard let start = points.first, let end = points.last else { return }
        let path = NSBezierPath()
        path.lineWidth = tool == .marker ? lineWidth * 5 : lineWidth
        path.lineCapStyle = .round; path.lineJoinStyle = .round
        (tool == .marker ? color.nsColor.withAlphaComponent(0.3) : color.nsColor).setStroke()
        switch tool {
        case .rectangle: path.appendRect(bounds)
        case .ellipse: path.appendOval(in: bounds)
        case .line, .arrow:
            path.move(to: start); path.line(to: end)
            if tool == .arrow {
                let angle = atan2(end.y - start.y, end.x - start.x), length = max(14, lineWidth * 4)
                for offset in [-CGFloat.pi / 6, CGFloat.pi / 6] {
                    path.move(to: NSPoint(x: end.x - length * cos(angle + offset), y: end.y - length * sin(angle + offset)))
                    path.line(to: end)
                }
            }
        case .pencil, .marker:
            path.move(to: start)
            for point in points.dropFirst() { path.line(to: point) }
        case .text:
            (text as NSString).draw(at: start, withAttributes: [.font: NSFont.systemFont(ofSize: max(18, lineWidth * 5)), .foregroundColor: color.nsColor])
        case .number:
            color.nsColor.setFill(); NSBezierPath(ovalIn: bounds).fill()
            let font = NSFont.monospacedDigitSystemFont(ofSize: bounds.width * (text.count > 2 ? 0.35 : 0.48), weight: .semibold)
            let luminance = color.red * 0.2126 + color.green * 0.7152 + color.blue * 0.0722
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: luminance > 0.65 ? NSColor.black : NSColor.white]
            let size = (text as NSString).size(withAttributes: attributes)
            (text as NSString).draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attributes)
        case .conceal:
            if concealStyle == .blackbox { NSColor.black.setFill(); bounds.fill() }
        case .select, .crop: break
        }
        path.stroke()
    }
}

struct AnnotationDocument {
    var base: NSImage
    var objects: [AnnotationObject] = []
    func rendered() -> NSImage { objects.reduce(base) { $1.applying(to: $0) } }
    func cropped(to rect: NSRect) -> AnnotationDocument {
        let clipped = rect.integral.intersection(NSRect(origin: .zero, size: base.size))
        guard !clipped.isEmpty else { return self }
        let objects = objects.filter { $0.bounds.insetBy(dx: -$0.lineWidth * 3, dy: -$0.lineWidth * 3).intersects(clipped) }.map { object -> AnnotationObject in
            var object = object
            object.move(dx: -clipped.minX, dy: -clipped.minY)
            return object
        }
        return AnnotationDocument(base: Imaging.crop(base, rect: clipped), objects: objects)
    }
}
