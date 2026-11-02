import AppKit

/// Use AppKit's bezel, symbol rendering, focus ring and appearance handling.
final class AnnotationButton: NSButton {
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
