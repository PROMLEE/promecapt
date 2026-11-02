import AppKit

/// Compact integer entry with native vertical increment/decrement arrows.
final class NumericStepper: NSControl, NSTextFieldDelegate {
    private let field = NSTextField(string: "4")
    private let stepper = NSStepper()
    private var value: Double = 4
    private var controlsEnabled = true
    var minValue: Double = 1 { didSet { doubleValue = value } }
    var maxValue: Double = 32 { didSet { doubleValue = value } }
    override var doubleValue: Double {
        get { value }
        set {
            value = min(maxValue, max(minValue, newValue.rounded()))
            field.stringValue = String(Int(value)); stepper.minValue = minValue
            stepper.maxValue = maxValue; stepper.doubleValue = value
        }
    }
    override var isEnabled: Bool {
        get { controlsEnabled }
        set { controlsEnabled = newValue; cell?.isEnabled = newValue; field.isEnabled = newValue; stepper.isEnabled = newValue }
    }
    convenience override init(frame frameRect: NSRect) { self.init(frame: frameRect, compact: false) }
    init(frame frameRect: NSRect, compact: Bool) {
        super.init(frame: frameRect)
        cell = NSActionCell()
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        field.alignment = .center
        field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        field.bezelStyle = .roundedBezel; field.isBezeled = true
        if compact {
            appearance = NSAppearance(named: .darkAqua)
            field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
            field.textColor = AnnotationPalette.foreground
            field.backgroundColor = AnnotationPalette.control
            field.drawsBackground = true
        }
        field.delegate = self
        stepper.controlSize = .small; stepper.increment = 1
        stepper.autorepeat = true; stepper.valueWraps = false
        stepper.target = self; stepper.action = #selector(step(_:))
        for view in [field,stepper] { view.translatesAutoresizingMaskIntoConstraints = false; addSubview(view) }
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: leadingAnchor), field.centerYAnchor.constraint(equalTo: centerYAnchor),
            field.heightAnchor.constraint(equalToConstant: 24), field.trailingAnchor.constraint(equalTo: stepper.leadingAnchor, constant: -3),
            stepper.trailingAnchor.constraint(equalTo: trailingAnchor), stepper.centerYAnchor.constraint(equalTo: centerYAnchor),
            stepper.widthAnchor.constraint(equalToConstant: 16)
        ])
        widthAnchor.constraint(equalToConstant: compact ? 62 : 76).isActive = true
        heightAnchor.constraint(equalToConstant: 28).isActive = true
        updateAccessibility(L("주석 두께"))
        doubleValue = 4
    }
    required init?(coder: NSCoder) { fatalError() }
    override func accessibilityChildren() -> [Any]? { [field, stepper] }
    func updateAccessibility(_ title: String) {
        setAccessibilityLabel(title + L(" 조절"))
        field.setAccessibilityLabel(title + L(" 숫자 입력"))
        stepper.setAccessibilityLabel(title + L(" 증감"))
        field.toolTip = title + L(": 숫자 입력 후 Enter · 이미지 위 휠로도 조절")
        stepper.toolTip = title + L(": 위 버튼 +1 · 아래 버튼 −1 · 길게 누르면 연속 조절")
    }
    static func parsedValue(_ text: String, min: Double, max: Double) -> Double? {
        guard let integer = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return Swift.min(max, Swift.max(min, Double(integer)))
    }
    private func commitInput() {
        guard let parsed = Self.parsedValue(field.stringValue, min: minValue, max: maxValue) else {
            doubleValue = value; return
        }
        doubleValue = parsed
        _ = sendAction(action, to: target)
    }
    @objc private func step(_ sender: NSStepper) {
        doubleValue = sender.doubleValue
        _ = sendAction(action, to: target)
    }
    func controlTextDidEndEditing(_ notification: Notification) { commitInput() }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            commitInput(); window?.makeFirstResponder(nil); return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            doubleValue = value; window?.makeFirstResponder(nil); return true
        }
        return false
    }
}
