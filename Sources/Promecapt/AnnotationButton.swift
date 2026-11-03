import AppKit

/// AppKit draws the bezel and interaction states; only the symbol's size and tint
/// are fixed so a non-key capture window does not fade enabled icons to gray.
final class AnnotationButtonCell: NSButtonCell {
    override func drawBezel(withFrame frame: NSRect, in controlView: NSView) {
        guard !isBordered else { super.drawBezel(withFrame: frame, in: controlView); return }
    }
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        super.draw(withFrame: cellFrame, in: controlView)
        if !isBordered && state == .on && (controlView as? AnnotationButton)?.indicatesSelection == true {
            NSColor.labelColor.setFill()
            NSRect(x: cellFrame.midX - 6, y: controlView.isFlipped ? cellFrame.maxY - 3.5 : cellFrame.minY + 2, width: 12, height: 1.5).fill()
        }
    }
    override func drawImage(_ image: NSImage, withFrame frame: NSRect, in controlView: NSView) {
        let dark = controlView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let color: NSColor = dark ? .white : .labelColor
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        let symbol = image.withSymbolConfiguration(configuration) ?? image
        let maximum: CGFloat = 14
        let ratio = min(maximum / max(1, symbol.size.width), maximum / max(1, symbol.size.height))
        let size = NSSize(width: symbol.size.width * ratio, height: symbol.size.height * ratio)
        let target = NSRect(x: controlView.bounds.midX - size.width / 2, y: controlView.bounds.midY - size.height / 2, width: size.width, height: size.height)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: controlView.bounds.insetBy(dx: 5, dy: 5)).addClip()
        symbol.draw(in: target, from: .zero, operation: .sourceOver, fraction: isEnabled ? 1 : 0.4, respectFlipped: true, hints: nil)
        NSGraphicsContext.restoreGraphicsState()
    }
}

final class AnnotationButton: NSButton {
    var indicatesSelection = false { didSet { needsDisplay = true } }
    override class var cellClass: AnyClass? {
        get { AnnotationButtonCell.self }
        set {}
    }
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) }
}
