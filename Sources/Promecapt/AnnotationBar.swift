import AppKit

final class AnnotationBar: NSView {
    var onDrag: ((NSPoint) -> Void)?
    private var dragPoint: NSPoint?
    var onSizeChange: (() -> Void)?
    private let top = NSStackView()
    private var itemButtons: [ToolbarItem: NSButton] = [:]
    private var preferenceObserver: NSObjectProtocol?
    let captureSize = CaptureSizeControl(frame: .zero)
    var onCaptureSize: ((NSSize) -> Void)? { didSet {
        captureSize.isHidden = onCaptureSize == nil
        info.isHidden = onCaptureSize != nil
        onSizeChange?()
    } }
    private let more = AnnotationButton()

    var onTool: ((DrawingTool?) -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onPin: (() -> Void)?
    var onCancel: (() -> Void)?
    var onRecord: (() -> Void)? { didSet { applyVisibility() } }
    private var recordButton: NSButton?
    var onOCRRegion: (() -> Void)?
    var onOCR: (() -> Void)?
    var onColor: ((NSColor) -> Void)?
    var onParameter: ((CGFloat) -> Void)?
    var onConcealStyle: ((ConcealStyle) -> Void)?
    private let styles = ToolbarPopUpButton()
    private let parameter = NumericStepper(frame: .zero, compact: true)
    private let colorWell = AnnotationColorWell(frame: NSRect(x: 0, y: 0, width: 30, height: 26))
    private var selectedTool: DrawingTool?
    private var ocrButton: NSButton?
    private var infoBeforeOCR: String?
    private static let tools = DrawingTool.allCases.filter { $0 != .crop }
    let info = ToolbarTextField(labelWithString: L("드래그하여 영역 선택"))
    private var toolButtons: [NSButton] = []
    private var hoverArea: NSTrackingArea?
    private weak var hoveredHelpView: NSView?
    private var hoveredHelpText: String?
    private var helpGeneration = 0
    private var helpLabels: [ObjectIdentifier: String] = [:]
    private var pendingTip: DispatchWorkItem?
    private var tipWindow: NSPanel?
    static let preferredSize = NSSize(width: 620, height: 36)
    var preferredSize: NSSize {
        let width = top.arrangedSubviews.filter { !$0.isHidden }.reduce(CGFloat(0)) { total, view in
            if view === captureSize { return total + 128 }
            if view === info { return total + min(136, max(60, info.intrinsicContentSize.width)) }
            if view === styles { return total + 78 }
            if view === colorWell { return total + 30 }
            if view === parameter { return total + 62 }
            return total + 28
        }
        return NSSize(width: ceil(width + 8), height: 36)
    }
    func setCaptureSize(_ size: NSSize) { captureSize.update(size) }
    func applyVisibility() {
        for (item, button) in itemButtons {
            button.isHidden = !item.isVisible || (item == .record && onRecord == nil)
        }
        hideTip(); onSizeChange?()
    }
    deinit { if let preferenceObserver { NotificationCenter.default.removeObserver(preferenceObserver) } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(L("주석 도구 막대"))
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerRadius = 7
        top.spacing = 0
        top.alignment = .centerY
        top.detachesHiddenViews = true
        top.orientation = .horizontal
        top.addArrangedSubview(toolButton("viewfinder", L("캡처 영역 조절: 테두리 이동·8개 핸들 크기 조절"), index: -1))
        let icons = ["cursorarrow", "pencil.tip", "highlighter", "rectangle", "circle", "line.diagonal", "arrow.up.right", "textformat", "1.circle", "square.grid.3x3.fill"]
        for (index, tool) in Self.tools.enumerated() {
            top.addArrangedSubview(toolButton(icons[index], tool.tip, index: index))
        }

        styles.identifier = .init("redaction-style")
        colorWell.identifier = .init("annotation-color")
        parameter.identifier = .init("annotation-parameter")
        styles.addItems(withTitles: ConcealStyle.allCases.map { L($0.rawValue) })
        styles.target = self; styles.action = #selector(styleChanged(_:))
        styles.setAccessibilityLabel(L("가리기 방식"))
        styles.toolTip = L("가리기 방식: 모자이크·블러·블랙박스")
        styles.widthAnchor.constraint(equalToConstant: 78).isActive = true
        styles.controlSize = .small
        styles.isBordered = false
        styles.font = .systemFont(ofSize: 12)
        top.addArrangedSubview(styles)

        let well = colorWell
        well.color = .systemRed
        well.isBordered = false
        well.target = self; well.action = #selector(colorChanged(_:))
        well.toolTip = L("색상: 선택한 주석 또는 다음 주석의 색 변경")
        well.widthAnchor.constraint(equalToConstant: 30).isActive = true
        top.addArrangedSubview(well)

        parameter.target = self; parameter.action = #selector(widthChanged(_:))
        parameter.updateAccessibility(L("주석 두께"))
        top.addArrangedSubview(parameter)
        addSubview(top)
        info.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        info.textColor = .labelColor
        info.lineBreakMode = .byTruncatingTail
        info.maximumNumberOfLines = 1
        info.widthAnchor.constraint(greaterThanOrEqualToConstant: 0).isActive = true
        info.widthAnchor.constraint(lessThanOrEqualToConstant: 136).isActive = true
        info.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        captureSize.isHidden = true
        captureSize.onCommit = { [weak self] size in self?.onCaptureSize?(size) }
        top.addArrangedSubview(captureSize)
        top.addArrangedSubview(info)
        for (symbol, action, tip) in [("arrow.uturn.backward", #selector(undoAction), L("실행 취소 (⌘Z)")), ("arrow.uturn.forward", #selector(redoAction), L("다시 실행 (⌘⇧Z)")),
                                     ("text.viewfinder", #selector(ocrAction), L("OCR: 캡처 전체 읽기 · ⌥클릭 부분 영역 지정 · O 전체 / Shift+O 부분")),
                                     ("doc.on.doc", #selector(copyAction), L("주석을 포함한 이미지를 클립보드에 복사 (⌘C)")),
                                     ("record.circle", #selector(recordAction), L("선택 영역 GIF 녹화 · 프레임·해상도는 설정 → GIF에서 변경")),
                                     ("square.and.arrow.down", #selector(saveAction), L("주석을 포함한 이미지 저장 (⌘S)")),
                                     ("pin", #selector(pinAction), L("캡처를 화면에 고정하거나 고정 주석 편집 적용 (⌘Enter)")),
                                     ("xmark", #selector(cancelAction), L("캡처 또는 고정 주석 편집 취소"))] {
            let button = AnnotationButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: tip) ?? NSImage(), target: self, action: action)
            button.bezelStyle = .regularSquare
            button.isBordered = false
            button.setButtonType(.momentaryPushIn)
            if let cell = button.cell as? NSButtonCell { cell.highlightsBy = []; cell.showsStateBy = [] }
            button.imageScaling = .scaleNone
            button.setAccessibilityLabel(tip)
            button.widthAnchor.constraint(equalToConstant: 28).isActive = true
            button.heightAnchor.constraint(equalToConstant: 28).isActive = true
            button.controlSize = .small
            button.toolTip = tip
            if action == #selector(recordAction) { recordButton = button; button.isHidden = onRecord == nil }
            if action == #selector(ocrAction) { button.setButtonType(.pushOnPushOff); button.indicatesSelection = true; ocrButton = button }
            let item: ToolbarItem
            switch action {
            case #selector(undoAction): item = .undo
            case #selector(redoAction): item = .redo
            case #selector(ocrAction): item = .ocr
            case #selector(copyAction): item = .copy
            case #selector(recordAction): item = .record
            case #selector(saveAction): item = .save
            case #selector(pinAction): item = .pin
            default: item = .close
            }
            button.identifier = .init("toolbar-" + item.rawValue)
            itemButtons[item] = button
            top.addArrangedSubview(button)
        }
        more.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: L("모든 도구"))
        more.imageScaling = .scaleNone; more.isBordered = false
        more.setButtonType(.momentaryPushIn)
        if let cell = more.cell as? NSButtonCell { cell.highlightsBy = []; cell.showsStateBy = [] }
        more.target = self; more.action = #selector(showAllTools)
        more.toolTip = L("모든 도구: 숨긴 버튼도 여기에서 사용할 수 있습니다.")
        more.setAccessibilityLabel(L("모든 도구"))
        more.widthAnchor.constraint(equalToConstant: 28).isActive = true
        more.heightAnchor.constraint(equalToConstant: 28).isActive = true
        top.addArrangedSubview(more)
        top.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            top.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            top.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
            top.heightAnchor.constraint(equalToConstant: 28),
            top.centerYAnchor.constraint(equalTo: centerYAnchor)])
        preferenceObserver = NotificationCenter.default.addObserver(forName: ToolbarItem.changed, object: nil, queue: .main) { [weak self] _ in self?.applyVisibility() }
        applyVisibility()
        captureHelpLabels()
        choose(-1)
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7).fill()
        NSColor.separatorColor.setStroke()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 7, yRadius: 7).stroke()
    }
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, bounds.contains(convert(point, from: superview)) else { return nil }
        return super.hitTest(point) ?? self
    }
    override func mouseDown(with event: NSEvent) {
        hideTip()
        dragPoint = window?.convertPoint(toScreen: event.locationInWindow)
    }
    override func mouseDragged(with event: NSEvent) {
        guard let previous = dragPoint, let window else { return }
        let point = window.convertPoint(toScreen: event.locationInWindow)
        dragPoint = point
        hideTip()
        onDrag?(NSPoint(x: point.x - previous.x, y: point.y - previous.y))
    }
    override func mouseUp(with event: NSEvent) { dragPoint = nil }

    /// Keep the whole toolbar below the menu bar/notch and inside its display.
    static func constrainedOrigin(_ origin: NSPoint, size: NSSize, within rect: NSRect) -> NSPoint {
        let safe = rect.insetBy(dx: 8, dy: 8)
        return NSPoint(x: max(safe.minX, min(origin.x, safe.maxX - size.width)),
                       y: max(safe.minY, min(origin.y, safe.maxY - size.height)))
    }
    override func scrollWheel(with event: NSEvent) {}
    @objc private func recordAction() { onRecord?() }
    required init?(coder: NSCoder) { fatalError() }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        captureHelpLabels()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero, options: [.inVisibleRect, .mouseMoved, .mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(area); hoverArea = area
        hideTip()
    }
    // Resolve the live hit target rather than storing rectangles that become stale
    // whenever contextual controls hide, resize or move the toolbar.
    private func captureHelpLabels() {
        func visit(_ view: NSView) {
            if let label = view.toolTip, !label.isEmpty {
                helpLabels[ObjectIdentifier(view)] = label
                view.setAccessibilityHelp(label)
                // Only the capture-level help panel should show, not a second native tip.
                view.toolTip = nil
            }
            for child in view.subviews { visit(child) }
        }
        for child in subviews { visit(child) }
    }
    func helpText(for view: NSView) -> String? { helpLabels[ObjectIdentifier(view)] ?? view.toolTip }
    func helpTarget(at point: NSPoint) -> NSView? {
        guard bounds.contains(point), !isHidden else { return nil }
        var view = super.hitTest(convert(point, to: superview))
        while let candidate = view, candidate !== self {
            if !candidate.isHiddenOrHasHiddenAncestor, let text = helpText(for: candidate), !text.isEmpty { return candidate }
            view = candidate.superview
        }
        return nil
    }
    override func mouseEntered(with event: NSEvent) { trackHelp(at: convert(event.locationInWindow, from: nil)) }
    override func mouseMoved(with event: NSEvent) { trackHelp(at: convert(event.locationInWindow, from: nil)) }
    private func trackHelp(at point: NSPoint) {
        guard let target = helpTarget(at: point), let text = helpText(for: target) else { hideTip(); return }
        guard target !== hoveredHelpView || text != hoveredHelpText else { return }
        hideTip()
        hoveredHelpView = target; hoveredHelpText = text
        let generation = helpGeneration
        let task = DispatchWorkItem { [weak self, weak target] in
            guard let self, let target, self.helpGeneration == generation,
                  let window = self.window, NSEvent.pressedMouseButtons == 0, !target.isHiddenOrHasHiddenAncestor,
                  self.helpTarget(at: self.convert(window.mouseLocationOutsideOfEventStream, from: nil)) === target,
                  let currentText = self.helpText(for: target) else { return }
            self.showTip(currentText, at: self.convert(target.bounds, from: target))
        }
        pendingTip = task; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
    }
    override func mouseExited(with event: NSEvent) { hideTip() }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        hideTip()
    }
    override func setFrameSize(_ size: NSSize) {
        if size != frame.size { hideTip() }
        super.setFrameSize(size)
    }
    override func setFrameOrigin(_ origin: NSPoint) {
        if origin != frame.origin { hideTip() }
        super.setFrameOrigin(origin)
    }
    private func hideTip() {
        helpGeneration += 1
        hoveredHelpView = nil; hoveredHelpText = nil
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
        background.wantsLayer = true; background.layer?.cornerRadius = 6
        background.appearance = effectiveAppearance
        effectiveAppearance.performAsCurrentDrawingAppearance {
            background.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            background.layer?.borderWidth = 1
            background.layer?.borderColor = NSColor.separatorColor.cgColor
        }
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = font; label.textColor = .labelColor
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
        button.imageScaling = .scaleNone
        button.tag = index
        button.bezelStyle = .regularSquare
        button.isBordered = false
        if let cell = button.cell as? NSButtonCell { cell.highlightsBy = .contentsCellMask; cell.showsStateBy = .contentsCellMask }
        button.setButtonType(.pushOnPushOff)
        button.indicatesSelection = true
        button.toolTip = label
        button.setAccessibilityLabel(index < 0 ? L("캡처 영역 이동 / 크기 조절") : L(Self.tools[index].rawValue))
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        let item = ToolbarItem.allCases[index + 1]
        button.identifier = .init("toolbar-" + item.rawValue)
        itemButtons[item] = button
        toolButtons.append(button)
        return button
    }
    @objc private func showAllTools() {
        hideTip()
        let menu = NSMenu()
        for (index, item) in ToolbarItem.allCases.enumerated() {
            if item == .undo { menu.addItem(.separator()) }
            if item == .record && onRecord == nil { continue }
            let entry = NSMenuItem(title: item.title, action: #selector(menuTool(_:)), keyEquivalent: "")
            entry.target = self; entry.tag = index
            if let button = itemButtons[item] { entry.state = button.state }
            menu.addItem(entry)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: more.frame.minX, y: more.frame.minY), in: top)
    }
    @objc private func menuTool(_ sender: NSMenuItem) {
        let item = ToolbarItem.allCases[sender.tag]
        if sender.tag < 11 { choose(sender.tag - 1); return }
        switch item {
        case .undo: undoAction()
        case .redo: redoAction()
        case .ocr: ocrAction()
        case .record: recordAction()
        case .copy: copyAction()
        case .save: saveAction()
        case .pin: pinAction()
        case .close: cancelAction()
        default: break
        }
    }
    func choose(_ index: Int) {
        for button in toolButtons { button.state = button.tag == index ? .on : .off }
        selectedTool = index < 0 ? nil : Self.tools[index]
        updateOptions(tool: selectedTool ?? .select, active: selectedTool != nil,
                      style: ConcealStyle.allCases[max(0, styles.indexOfSelectedItem)])
        onTool?(selectedTool)
        onSizeChange?()
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
        updateOptions(tool: canvas.effectiveTool, active: selectedTool != nil && !canvas.isSelectingOCR, style: canvas.concealStyle)
        styles.selectItem(at: ConcealStyle.allCases.firstIndex(of: canvas.concealStyle)!)
        parameter.minValue = conceal ? 2 : 1
        parameter.maxValue = conceal ? 80 : 32
        parameter.doubleValue = Double(canvas.parameterValue)
        parameter.isEnabled = !canvas.isSelectingOCR && selectedTool != nil && canvas.parameterIsEnabled
        parameter.updateAccessibility(conceal ? L("가리기 세기") : L("주석 두께"))
        info.toolTip = info.stringValue
        captureHelpLabels()
        onSizeChange?()
    }
    private func updateOptions(tool: DrawingTool, active: Bool, style: ConcealStyle) {
        styles.isHidden = !active || tool != .conceal
        colorWell.isHidden = !active || [DrawingTool.select, .crop, .conceal].contains(tool)
        parameter.isHidden = !active || [DrawingTool.select, .crop].contains(tool) || (tool == .conceal && style == .blackbox)
        if colorWell.isHidden { colorWell.deactivate() }
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
    @objc private func ocrAction() {
        ocrButton?.state = .off
        window?.makeFirstResponder(nil)
        if NSApp.currentEvent?.modifierFlags.contains(.option) == true, let onOCRRegion { onOCRRegion() }
        else { onOCR?() }
    }
}
