import AppKit

/// Use AppKit's bezel, symbol rendering, focus ring and appearance handling.
final class AnnotationButton: NSButton {
    // Older AppKit bezels report negative alignment insets. Keep the actual hit/draw
    // bounds equal to the toolbar allocation on every supported macOS version.
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .texturedRounded
        controlSize = .small
        imagePosition = .imageOnly
        contentTintColor = .labelColor
        symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
    }
    required init?(coder: NSCoder) { fatalError() }
}
