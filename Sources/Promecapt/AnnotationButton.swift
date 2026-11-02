import AppKit

enum AnnotationPalette {
    static let background = NSColor(srgbRed: 0.10, green: 0.12, blue: 0.15, alpha: 1)
    static let control = NSColor(srgbRed: 0.17, green: 0.20, blue: 0.25, alpha: 1)
    static let selected = NSColor(srgbRed: 0.13, green: 0.32, blue: 0.52, alpha: 1)
    static let foreground = NSColor.white
    static let disabled = NSColor(srgbRed: 0.65, green: 0.69, blue: 0.75, alpha: 1)
    static let border = NSColor(srgbRed: 0.48, green: 0.54, blue: 0.62, alpha: 1)
    static let accent = NSColor(srgbRed: 0.43, green: 0.76, blue: 1, alpha: 1)
}

/// Native button interaction/accessibility with an opaque, consistently legible face.
final class AnnotationButton: NSButton {
    override var allowsVibrancy: Bool { false }
    override var state: NSControl.StateValue { didSet { if state != oldValue { needsDisplay = true } } }
    override var isEnabled: Bool { didSet { if isEnabled != oldValue { needsDisplay = true } } }
    override func draw(_ dirtyRect: NSRect) {
        let selected = state == .on || cell?.isHighlighted == true
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let outline = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        (selected ? AnnotationPalette.selected : AnnotationPalette.control).setFill()
        outline.fill()
        (selected ? AnnotationPalette.accent : AnnotationPalette.border).setStroke()
        outline.lineWidth = selected ? 1.5 : 1
        outline.stroke()
        let foreground = isEnabled ? AnnotationPalette.foreground : AnnotationPalette.disabled
        if let image, imagePosition == .imageOnly {
            let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [foreground]))
            let symbol = image.withSymbolConfiguration(configuration) ?? image
            let size = NSSize(width: min(18, symbol.size.width), height: min(18, symbol.size.height))
            symbol.draw(in: NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        } else {
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: foreground]
            let size = (title as NSString).size(withAttributes: attributes)
            (title as NSString).draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attributes)
        }
        if window?.firstResponder === self, NSApp.isFullKeyboardAccessEnabled {
            let focus = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 3, yRadius: 3)
            AnnotationPalette.accent.setStroke(); focus.lineWidth = 2; focus.stroke()
        }
    }
}
