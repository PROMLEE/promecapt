import AppKit

final class AnnotationBar: NSView {
    var onTool: ((DrawingTool?) -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onPin: (() -> Void)?
    var onCancel: (() -> Void)?
    var onRecord: (() -> Void)? { didSet { recordButton?.isHidden = onRecord == nil } }
    private var recordButton: NSButton?
    var onOCR: (() -> Void)?
    var onColor: ((NSColor) -> Void)?
    var onParameter: ((CGFloat) -> Void)?
    var onConcealStyle: ((ConcealStyle) -> Void)?
    private let styles = NSPopUpButton()
    private let parameter = NumericStepper(frame: .zero, compact: true)
    private let colorWell = AnnotationColorWell(frame: NSRect(x: 0, y: 0, width: 30, height: 26))
    private var selectedTool: DrawingTool?
    private var ocrButton: NSButton?
    private var infoBeforeOCR: String?
    private static let tools = DrawingTool.allCases.filter { $0 != .crop }
    let info = NSTextField(labelWithString: L("드래그하여 영역 선택"))
    private var toolButtons: [NSButton] = []
    private var tipAreas: [NSTrackingArea] = []
    private var pendingTip: DispatchWorkItem?
    private var tipWindow: NSPanel?
    static let preferredSize = NSSize(width: 560, height: 68)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(L("주석 도구 막대"))
        appearance = NSAppearance(named: .darkAqua)
        wantsLayer = true
        layer?.backgroundColor = AnnotationPalette.background.cgColor
        layer?.masksToBounds = true
        layer?.cornerRadius = 7
        layer?.borderWidth = 1
        layer?.borderColor = AnnotationPalette.border.cgColor
        let top = NSStackView()
        top.spacing = 2
        top.orientation = .horizontal
        top.addArrangedSubview(toolButton("viewfinder", L("캡처 영역 조절: 테두리 이동·8개 핸들 크기 조절"), index: -1))
        let icons = ["cursorarrow", "pencil.tip", "highlighter", "rectangle", "circle", "line.diagonal", "arrow.up.right", "textformat", "1.circle", "square.grid.3x3.fill"]
        for (index, tool) in Self.tools.enumerated() {
            top.addArrangedSubview(toolButton(icons[index], tool.tip, index: index))
        }
        styles.addItems(withTitles: ConcealStyle.allCases.map { L($0.rawValue) })
        styles.target = self; styles.action = #selector(styleChanged(_:))
        styles.setAccessibilityLabel(L("가리기 방식"))
        styles.toolTip = L("가리기 방식: 모자이크·블러·블랙박스")
        styles.widthAnchor.constraint(equalToConstant: 78).isActive = true
        styles.controlSize = .small
        styles.font = .systemFont(ofSize: 12, weight: .semibold)
        styles.contentTintColor = AnnotationPalette.foreground
        top.addArrangedSubview(styles)
        let well = colorWell
        well.color = .systemRed
        well.target = self; well.action = #selector(colorChanged(_:))
        well.toolTip = L("색상: 선택한 주석 또는 다음 주석의 색 변경")
        well.widthAnchor.constraint(equalToConstant: 30).isActive = true
        top.addArrangedSubview(well)
        parameter.target = self; parameter.action = #selector(widthChanged(_:))
        parameter.updateAccessibility(L("주석 두께"))
        top.addArrangedSubview(parameter)
        addSubview(top)
        let bottom = NSStackView()
        bottom.spacing = 3
        info.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        info.textColor = .white
        info.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bottom.addArrangedSubview(info)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        bottom.addArrangedSubview(spacer)
        for (title, action, tip) in [("↶", #selector(undoAction), L("실행 취소 (⌘Z)")), ("↷", #selector(redoAction), L("다시 실행 (⌘⇧Z)")),
                                     ("OCR", #selector(ocrAction), L("OCR 영역 선택: 버튼을 누른 뒤 읽을 글자 범위만 드래그 · Esc 취소")),
                                     (L("복사"), #selector(copyAction), L("주석을 포함한 이미지를 클립보드에 복사 (⌘C)")),
                                     ("GIF", #selector(recordAction), L("선택 영역 GIF 녹화 · 프레임·해상도는 설정 → GIF에서 변경")),
                                     (L("저장"), #selector(saveAction), L("주석을 포함한 이미지 저장 (⌘S)")),
                                     (L("고정"), #selector(pinAction), L("캡처를 화면에 고정하거나 고정 주석 편집 적용 (⌘Enter)")),
                                     (L("닫기"), #selector(cancelAction), L("캡처 또는 고정 주석 편집 취소"))] {
            let button = AnnotationButton(title: title, target: self, action: action)
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.toolTip = tip
            if action == #selector(recordAction) { recordButton = button; button.isHidden = onRecord == nil }
            if action == #selector(ocrAction) { button.setButtonType(.pushOnPushOff); ocrButton = button }
            bottom.addArrangedSubview(button)
        }
        addSubview(bottom)
        for row in [top, bottom] {
            row.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 7),
                row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -7),
                row.heightAnchor.constraint(equalToConstant: 26)])
        }
        top.topAnchor.constraint(equalTo: topAnchor, constant: 6).isActive = true
        bottom.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6).isActive = true
        choose(-1)
    }
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, bounds.contains(convert(point, from: superview)) else { return nil }
        return super.hitTest(point) ?? self
    }
    override func mouseDown(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
    override func scrollWheel(with event: NSEvent) {}
    @objc private func recordAction() { onRecord?() }
    required init?(coder: NSCoder) { fatalError() }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in tipAreas { removeTrackingArea(area) }
        tipAreas = []
        func visit(_ view: NSView) {
            if let tip = view.toolTip, !tip.isEmpty {
                let rect = convert(view.bounds, from: view)
                let area = NSTrackingArea(rect: rect, options: [.mouseEnteredAndExited,.activeAlways], owner: self,
                                          userInfo: ["tip": tip, "rect": NSValue(rect: rect)])
                addTrackingArea(area); tipAreas.append(area)
            }
            for child in view.subviews { visit(child) }
        }
        for child in subviews { visit(child) }
    }
    override func mouseEntered(with event: NSEvent) {
        guard let tip = event.trackingArea?.userInfo?["tip"] as? String,
              let rect = event.trackingArea?.userInfo?["rect"] as? NSValue else { return }
        hideTip()
        let task = DispatchWorkItem { [weak self] in self?.showTip(tip, at: rect.rectValue) }
        pendingTip = task; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
    }
    override func mouseExited(with event: NSEvent) { hideTip() }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); hideTip() }
    private func hideTip() {
        pendingTip?.cancel(); pendingTip = nil
        if let tipWindow { tipWindow.parent?.removeChildWindow(tipWindow); tipWindow.close() }
        tipWindow = nil
    }
    func dismissHelp() { hideTip() }
    private func showTip(_ text: String, at rect: NSRect) {
        guard let window, !isHidden, window.isVisible else { return }
        let font = NSFont.systemFont(ofSize: 12)
        let measured = (text as NSString).boundingRect(with: NSSize(width: 480, height: 100), options: [.usesLineFragmentOrigin], attributes: [.font: font])
        let size = NSSize(width: ceil(measured.width) + 20, height: ceil(measured.height) + 16)
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless,.nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = L("Promecapt · 도구 설명")
        panel.isReleasedWhenClosed = false; panel.ignoresMouseEvents = true
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        // Native help windows can sit behind a screen-saver-level capture overlay.
        panel.level = NSWindow.Level(rawValue: window.level.rawValue + 2)
        let background = NSView(frame: NSRect(origin: .zero, size: size))
        background.appearance = NSAppearance(named: .darkAqua)
        background.wantsLayer = true; background.layer?.cornerRadius = 6
        background.layer?.backgroundColor = AnnotationPalette.background.cgColor
        background.layer?.borderWidth = 1; background.layer?.borderColor = AnnotationPalette.border.cgColor
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = font; label.textColor = .white
        label.frame = NSRect(x: 10, y: 8, width: size.width - 20, height: size.height - 16)
        background.addSubview(label); panel.contentView = background
        let anchor = window.convertToScreen(convert(rect, to: nil))
        let visible = window.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
        let y = anchor.maxY + size.height + 7 <= visible.maxY ? anchor.maxY + 7 : anchor.minY - size.height - 7
        panel.setFrameOrigin(NSPoint(x: min(visible.maxX - size.width, max(visible.minX, anchor.midX - size.width / 2)), y: y))
        tipWindow = panel; window.addChildWindow(panel, ordered: .above); panel.orderFrontRegardless()
    }
    private func toolButton(_ symbol: String, _ label: String, index: Int) -> NSButton {
        let button = AnnotationButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: label) ?? NSImage(), target: self, action: #selector(toolAction(_:)))
        button.tag = index
        button.bezelStyle = .texturedRounded
        button.setButtonType(.pushOnPushOff)
        button.toolTip = label
        button.setAccessibilityLabel(index < 0 ? L("캡처 영역 이동 / 크기 조절") : L(Self.tools[index].rawValue))
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 26).isActive = true
        toolButtons.append(button)
        return button
    }
    func choose(_ index: Int) {
        for button in toolButtons { button.state = button.tag == index ? .on : .off }
        selectedTool = index < 0 ? nil : Self.tools[index]
        styles.isEnabled = selectedTool == .conceal
        parameter.isEnabled = selectedTool != nil
        onTool?(selectedTool)
    }
    func sync(with canvas: CanvasView) {
        colorWell.color = canvas.color
        if selectedTool != nil {
            let index = Self.tools.firstIndex(of: canvas.tool)!
            for button in toolButtons { button.state = button.tag == index ? .on : .off }
        }
        ocrButton?.state = canvas.isSelectingOCR ? .on : .off
        if canvas.isSelectingOCR {
            if infoBeforeOCR == nil { infoBeforeOCR = info.stringValue }
            info.stringValue = L("OCR: 글자 범위 드래그 · Esc 취소")
        } else if let previous = infoBeforeOCR { info.stringValue = previous; infoBeforeOCR = nil }
        let conceal = selectedTool != nil && canvas.effectiveTool == .conceal
        styles.isEnabled = conceal
        styles.selectItem(at: ConcealStyle.allCases.firstIndex(of: canvas.concealStyle)!)
        parameter.minValue = conceal ? 2 : 1
        parameter.maxValue = conceal ? 80 : 32
        parameter.doubleValue = Double(canvas.parameterValue)
        parameter.isEnabled = !canvas.isSelectingOCR && selectedTool != nil && canvas.parameterIsEnabled
        parameter.updateAccessibility(conceal ? L("가리기 세기") : L("주석 두께"))
    }
    @objc private func toolAction(_ sender: NSButton) { hideTip(); window?.makeFirstResponder(nil); choose(sender.tag) }
    @objc private func colorChanged(_ sender: NSColorWell) { onColor?(sender.color) }
    @objc private func widthChanged(_ sender: NumericStepper) { onParameter?(CGFloat(sender.doubleValue)) }
    @objc private func styleChanged(_ sender: NSPopUpButton) { onConcealStyle?(ConcealStyle.allCases[sender.indexOfSelectedItem]) }
    @objc private func undoAction() { window?.makeFirstResponder(nil); onUndo?() }
    @objc private func redoAction() { window?.makeFirstResponder(nil); onRedo?() }
    @objc private func copyAction() { window?.makeFirstResponder(nil); onCopy?() }
    @objc private func saveAction() { window?.makeFirstResponder(nil); onSave?() }
    @objc private func pinAction() { window?.makeFirstResponder(nil); onPin?() }
    @objc private func cancelAction() { onCancel?() }
    @objc private func ocrAction() { window?.makeFirstResponder(nil); onOCR?() }
}
