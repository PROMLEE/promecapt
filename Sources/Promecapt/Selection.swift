import AppKit

/// All capture interaction uses screen points; conversion to bitmap pixels happens only at export.
struct CaptureSelection {
    enum Handle: CaseIterable {
        case northWest, north, northEast, east, southEast, south, southWest, west
        var changesLeft: Bool { [.northWest, .southWest, .west].contains(self) }
        var changesRight: Bool { [.northEast, .southEast, .east].contains(self) }
        var changesTop: Bool { [.northWest, .north, .northEast].contains(self) }
        var changesBottom: Bool { [.southWest, .south, .southEast].contains(self) }
    }
    enum Constraint { case free, square, aspect }
    enum Drag { case new, move, resize(Handle) }
    var rect: NSRect = .zero
    let bounds: NSRect
    private var start: NSPoint = .zero
    private var original: NSRect = .zero
    private var drag: Drag = .new

    init(bounds: NSRect) { self.bounds = bounds }

    var isValid: Bool { rect.width >= 2 && rect.height >= 2 }
    func point(for handle: Handle) -> NSPoint {
        switch handle {
        case .northWest: return NSPoint(x: rect.minX, y: rect.maxY)
        case .north: return NSPoint(x: rect.midX, y: rect.maxY)
        case .northEast: return NSPoint(x: rect.maxX, y: rect.maxY)
        case .east: return NSPoint(x: rect.maxX, y: rect.midY)
        case .southEast: return NSPoint(x: rect.maxX, y: rect.minY)
        case .south: return NSPoint(x: rect.midX, y: rect.minY)
        case .southWest: return NSPoint(x: rect.minX, y: rect.minY)
        case .west: return NSPoint(x: rect.minX, y: rect.midY)
        }
    }
    func handle(at location: NSPoint, tolerance: CGFloat = 8) -> Handle? {
        guard isValid else { return nil }
        return Handle.allCases.first {
            let p = point(for: $0)
            return abs(p.x - location.x) <= tolerance && abs(p.y - location.y) <= tolerance
        }
    }
    mutating func begin(at location: NSPoint, forceNew: Bool = false) {
        start = location
        original = rect
        if !forceNew, let handle = handle(at: location) { drag = .resize(handle) }
        else if !forceNew, isValid, rect.contains(location) { drag = .move }
        else { drag = .new; rect = NSRect(origin: location, size: .zero) }
    }
    mutating func update(to location: NSPoint, constraint: Constraint = .free) {
        let p = NSPoint(x: min(bounds.maxX, max(bounds.minX, location.x)), y: min(bounds.maxY, max(bounds.minY, location.y)))
        let ratio: CGFloat? = constraint == .square ? 1 : constraint == .aspect ? (original.width >= 2 && original.height >= 2 ? original.width / original.height : 1) : nil
        if let ratio {
            switch drag {
            case .new:
                rect = proportional(anchor: start, pointer: p, ratio: ratio, horizontal: true, vertical: true)
                return
            case .resize(let handle):
                let anchor = NSPoint(x: handle.changesLeft ? original.maxX : handle.changesRight ? original.minX : original.midX,
                                     y: handle.changesBottom ? original.maxY : handle.changesTop ? original.minY : original.midY)
                rect = proportional(anchor: anchor, pointer: p, ratio: ratio,
                                    horizontal: handle.changesLeft || handle.changesRight,
                                    vertical: handle.changesTop || handle.changesBottom)
                return
            case .move: break
            }
        }
        switch drag {
        case .new:
            rect = NSRect(x: min(start.x, p.x), y: min(start.y, p.y), width: abs(p.x - start.x), height: abs(p.y - start.y))
        case .move:
            rect = original
            rect.origin.x = min(bounds.maxX - rect.width, max(bounds.minX, original.minX + p.x - start.x))
            rect.origin.y = min(bounds.maxY - rect.height, max(bounds.minY, original.minY + p.y - start.y))
        case .resize(let handle):
            var x1 = original.minX, x2 = original.maxX, y1 = original.minY, y2 = original.maxY
            if handle.changesLeft { x1 = min(p.x, x2 - 2) }
            if handle.changesRight { x2 = max(p.x, x1 + 2) }
            if handle.changesBottom { y1 = min(p.y, y2 - 2) }
            if handle.changesTop { y2 = max(p.y, y1 + 2) }
            rect = NSRect(x: x1, y: y1, width: x2 - x1, height: y2 - y1).intersection(bounds)
        }
    }
    private func proportional(anchor: NSPoint, pointer: NSPoint, ratio: CGFloat, horizontal: Bool, vertical: Bool) -> NSRect {
        let sx: CGFloat = pointer.x < anchor.x ? -1 : 1
        let sy: CGFloat = pointer.y < anchor.y ? -1 : 1
        let maxWidth = horizontal ? (sx > 0 ? bounds.maxX - anchor.x : anchor.x - bounds.minX) : 2 * min(anchor.x - bounds.minX, bounds.maxX - anchor.x)
        let maxHeight = vertical ? (sy > 0 ? bounds.maxY - anchor.y : anchor.y - bounds.minY) : 2 * min(anchor.y - bounds.minY, bounds.maxY - anchor.y)
        let proposedWidth = horizontal ? abs(pointer.x - anchor.x) : abs(pointer.y - anchor.y) * ratio
        let proposed = horizontal && vertical ? max(proposedWidth, abs(pointer.y - anchor.y) * ratio) : proposedWidth
        let width = max(0, min(max(2, proposed), maxWidth, maxHeight * ratio))
        let height = width / ratio
        return NSRect(x: horizontal ? (sx > 0 ? anchor.x : anchor.x - width) : anchor.x - width / 2,
                      y: vertical ? (sy > 0 ? anchor.y : anchor.y - height) : anchor.y - height / 2,
                      width: width, height: height)
    }
    mutating func nudge(dx: CGFloat, dy: CGFloat, resize: Bool) {
        guard isValid else { return }
        if resize {
            rect.size.width = min(bounds.maxX - rect.minX, max(2, rect.width + dx))
            rect.size.height = min(bounds.maxY - rect.minY, max(2, rect.height + dy))
        } else {
            rect.origin.x = min(bounds.maxX - rect.width, max(bounds.minX, rect.minX + dx))
            rect.origin.y = min(bounds.maxY - rect.height, max(bounds.minY, rect.minY + dy))
        }
    }
    func pixelRect(imageSize: NSSize) -> NSRect {
        let sx = imageSize.width / bounds.width, sy = imageSize.height / bounds.height
        let x1 = ((rect.minX - bounds.minX) * sx).rounded()
        let y1 = ((rect.minY - bounds.minY) * sy).rounded()
        let x2 = ((rect.maxX - bounds.minX) * sx).rounded()
        let y2 = ((rect.maxY - bounds.minY) * sy).rounded()
        return NSRect(x: x1, y: y1, width: x2 - x1, height: y2 - y1)
    }
}
