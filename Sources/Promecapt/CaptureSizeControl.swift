import AppKit

/// Editable bitmap dimensions, with independent width/height and no modal dialog.
final class CaptureSizeControl: NSView, NSTextFieldDelegate {
    var onCommit: ((NSSize) -> Void)?
    private(set) var pixelSize = NSSize(width: 2, height: 2)
    let widthField = ToolbarTextField(string: "2")
    let heightField = ToolbarTextField(string: "2")
    private var committing = false
    override init(frame: NSRect) {
        super.init(frame: frame)
        let cross = ToolbarTextField(labelWithString: "×")
        let unit = ToolbarTextField(labelWithString: "px")
        let row = NSStackView(views: [widthField, cross, heightField, unit])
        row.spacing = 0; row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([row.leadingAnchor.constraint(equalTo: leadingAnchor), row.trailingAnchor.constraint(equalTo: trailingAnchor), row.centerYAnchor.constraint(equalTo: centerYAnchor), widthAnchor.constraint(equalToConstant: 128), heightAnchor.constraint(equalToConstant: 28)])
        for field in [widthField, heightField] {
            field.isBordered = false; field.drawsBackground = false
            field.alignment = .center
            field.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            field.delegate = self
            field.widthAnchor.constraint(equalToConstant: 48).isActive = true
            field.heightAnchor.constraint(equalToConstant: 22).isActive = true
        }
        cross.widthAnchor.constraint(equalToConstant: 12).isActive = true
        unit.widthAnchor.constraint(equalToConstant: 20).isActive = true
        for label in [cross, unit] { label.font = .systemFont(ofSize: 11) }
        widthField.setAccessibilityLabel(L("캡처 너비 (px)"))
        heightField.setAccessibilityLabel(L("캡처 높이 (px)"))
        widthField.toolTip = L("캡처 크기: 픽셀 수를 입력하고 Enter · 화면 범위 안에서 적용")
        heightField.toolTip = widthField.toolTip
    }
    required init?(coder: NSCoder) { fatalError() }
    func update(_ size: NSSize) {
        pixelSize = size
        // Do not overwrite unfinished input when a tool or tooltip updates.
        if widthField.currentEditor() == nil { widthField.stringValue = String(Int(size.width.rounded())) }
        if heightField.currentEditor() == nil { heightField.stringValue = String(Int(size.height.rounded())) }
    }
    static func parsed(_ width: String, _ height: String) -> NSSize? {
        guard let w = Int(width.trimmingCharacters(in: .whitespacesAndNewlines)),
              let h = Int(height.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...100000).contains(w), (1...100000).contains(h) else { return nil }
        return NSSize(width: w, height: h)
    }
    func commit() {
        guard !committing else { return }
        committing = true
        defer { committing = false }
        if let size = Self.parsed(widthField.stringValue, heightField.stringValue) { onCommit?(size) }
        widthField.stringValue = String(Int(pixelSize.width.rounded()))
        heightField.stringValue = String(Int(pixelSize.height.rounded()))
    }
    func controlTextDidEndEditing(_ notification: Notification) { commit() }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.insertNewline(_:)) {
            commit(); window?.makeFirstResponder(nil); return true
        }
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            widthField.stringValue = String(Int(pixelSize.width.rounded()))
            heightField.stringValue = String(Int(pixelSize.height.rounded()))
            window?.makeFirstResponder(nil); return true
        }
        return false
    }
}

final class ToolbarPopUpButton: NSPopUpButton {
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) }
}

final class ToolbarTextField: NSTextField {
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) }
}
