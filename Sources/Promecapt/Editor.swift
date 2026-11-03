import AppKit

enum DrawingTool: String, CaseIterable, Codable {
    case select = "주석 선택"
    case pencil = "펜", marker = "형광펜", rectangle = "사각형", ellipse = "타원"
    case line = "선", arrow = "화살표", text = "텍스트", number = "번호", conceal = "가리기", crop = "자르기"
    var tip: String {
        switch self {
        case .select: return L("주석 선택: 그린 주석 클릭 → 이동·핸들 크기 조절·Delete 삭제")
        case .pencil: return L("펜: 자유롭게 그리기 · 휠로 두께 조절")
        case .marker: return L("형광펜: 반투명 강조선 · 휠로 두께 조절")
        case .rectangle: return L("사각형: 드래그하여 계속 그리기 · 선택된 주석은 바로 수정 · 휠로 두께 조절")
        case .ellipse: return L("타원: 드래그하여 계속 그리기 · 선택된 주석은 바로 수정 · 휠로 두께 조절")
        case .line: return L("선: 시작점에서 끝점으로 드래그 · 휠로 두께 조절")
        case .arrow: return L("화살표: 시작점에서 끝점으로 드래그 · 휠로 두께 조절")
        case .text: return L("텍스트: 원하는 위치 클릭 → 입력 → Enter 또는 확인 · 기존 글씨는 더블 클릭해 수정")
        case .number: return L("번호: 클릭할 때마다 원 안에 1, 2, 3… 추가 · 더블 클릭하여 번호 수정")
        case .conceal: return L("가리기: 방식 선택 후 영역 드래그 · 휠로 세기 조절")
        case .crop: return L("자르기: 남길 영역 드래그")
        }
    }
}

enum ConcealStyle: String, CaseIterable, Codable {
    case mosaic = "모자이크", blur = "블러", blackbox = "블랙박스"
}

final class EditorController: NSWindowController, NSWindowDelegate {
    let canvas: CanvasView
    var onPin: ((AnnotationDocument) -> Void)?
    var onClose: ((EditorController) -> Void)?
    private let info = NSTextField(labelWithString: "")
    private let tools = NSStackView()
    private var toolButtons: [NSButton] = []
    private let concealStyles = ToolbarPopUpButton()
    private var configurableButtons: [ToolbarItem: NSButton] = [:]
    private var toolbarObserver: NSObjectProtocol?
    private let parameter = NumericStepper(frame: .zero, compact: true)
    private let parameterLabel = NSTextField(labelWithString: L("두께 4"))
    private let colorWell = AnnotationColorWell()
    private var ocrButton: NSButton!

    init(image: NSImage) {
        canvas = CanvasView(image: image)
        canvas.tool = .select
        let screen = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1280, height: 800)
        let size = NSSize(width: min(1120, screen.width - 60), height: min(820, screen.height - 60))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = L("Promecapt · 캡처 편집")
        window.minSize = NSSize(width: 900, height: 420)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 0
        root.alignment = .leading
        let background = NSBox()
        background.boxType = .custom
        background.borderWidth = 0
        background.fillColor = .windowBackgroundColor
        background.contentViewMargins = .zero
        background.contentView = root
        window.contentView = background

        tools.orientation = .horizontal
        tools.spacing = 0
        tools.detachesHiddenViews = true
        tools.setHuggingPriority(.required, for: .horizontal)
        let symbols = ["cursorarrow", "pencil.tip", "highlighter", "rectangle", "circle", "line.diagonal", "arrow.up.right", "textformat", "1.circle", "square.grid.3x3.fill", "crop"]
        for (index, tool) in DrawingTool.allCases.enumerated() {
            let button = AnnotationButton(image: NSImage(systemSymbolName: symbols[index], accessibilityDescription: L(tool.rawValue)) ?? NSImage(), target: self, action: #selector(selectTool(_:)))
            button.tag = index
            button.bezelStyle = .regularSquare
            button.isBordered = false
            if let cell = button.cell as? NSButtonCell { cell.highlightsBy = .contentsCellMask; cell.showsStateBy = .contentsCellMask }
            button.setButtonType(.pushOnPushOff)
            button.indicatesSelection = true
            button.setAccessibilityLabel(L(tool.rawValue))
            button.toolTip = tool.tip
            button.widthAnchor.constraint(equalToConstant: 28).isActive = true
            button.heightAnchor.constraint(equalToConstant: 28).isActive = true
            if index < 10 { configurableButtons[ToolbarItem.allCases[index + 1]] = button }
            toolButtons.append(button)
            tools.addArrangedSubview(button)
        }
        tools.toolTip = L("영역 도구는 이미지에서 드래그합니다. 텍스트는 클릭합니다.")
        concealStyles.identifier = .init("redaction-style")
        colorWell.identifier = .init("annotation-color")
        parameter.identifier = .init("annotation-parameter")
        concealStyles.addItems(withTitles: ConcealStyle.allCases.map { L($0.rawValue) })
        concealStyles.isBordered = false
        concealStyles.widthAnchor.constraint(equalToConstant: 78).isActive = true
        concealStyles.target = self; concealStyles.action = #selector(selectConcealStyle(_:))
        concealStyles.setAccessibilityLabel(L("가리기 방식"))

        let color = colorWell
        color.color = .systemRed
        color.isBordered = false
        color.target = self
        color.action = #selector(selectColor(_:))
        color.widthAnchor.constraint(equalToConstant: 30).isActive = true
        parameter.target = self; parameter.action = #selector(selectWidth(_:))
        let undo = button(L("실행 취소"), #selector(undoEdit), "⌘Z")
        let redo = button(L("다시 실행"), #selector(redoEdit), "⇧⌘Z")
        let copy = button(L("복사"), #selector(copyOutput), "⌘C")
        let save = button(L("저장…"), #selector(saveOutput), "⌘S")
        let pin = button(L("화면 고정"), #selector(pinOutput), "⌘↩")
        ocrButton = button(L("텍스트 추출 (OCR)"), #selector(ocr))
        configurableButtons.merge([.undo: undo, .redo: redo, .copy: copy, .save: save, .pin: pin, .ocr: ocrButton!]) { _, new in new }
        let toolRow = row([tools, concealStyles, color, parameter, undo, redo,
            button(L("회전"), #selector(rotateImage)), button(L("좌우 반전"), #selector(flip)), ocrButton, copy, save, pin, button(L("모든 도구"), #selector(showTools))])
        toolRow.detachesHiddenViews = true
        root.addArrangedSubview(toolRow)
        toolbarObserver = NotificationCenter.default.addObserver(forName: ToolbarItem.changed, object: nil, queue: .main) { [weak self] _ in self?.applyToolbarPreferences() }
        applyToolbarPreferences()
        canvas.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(canvas)
        let bottom = row([info])
        root.addArrangedSubview(bottom)
        toolRow.setHuggingPriority(.required, for: .horizontal)
        toolRow.widthAnchor.constraint(lessThanOrEqualTo: root.widthAnchor).isActive = true
        for view in [canvas, bottom] {
            view.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        }
        canvas.heightAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        canvas.setContentHuggingPriority(.defaultLow, for: .vertical)
        canvas.onChange = { [weak self] in self?.updateInfo() }
        canvas.onParametersChange = { [weak self] in self?.updateInfo() }
        canvas.onShortcut = { [weak self] event in self?.shortcut(event) ?? false }
        updateInfo()
    }

    @objc private func showTools() {
        let menu = NSMenu()
        for (index, tool) in DrawingTool.allCases.enumerated() {
            let entry = NSMenuItem(title: L(tool.rawValue), action: #selector(menuSelectTool(_:)), keyEquivalent: "")
            entry.target = self; entry.tag = index; entry.state = canvas.tool == tool ? .on : .off
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        for (title, action) in [(L("실행 취소"), #selector(undoEdit)), (L("다시 실행"), #selector(redoEdit)),
                                (L("회전"), #selector(rotateImage)), (L("좌우 반전"), #selector(flip)),
                                (L("텍스트 추출 (OCR)"), #selector(ocr)), (L("복사"), #selector(copyOutput)),
                                (L("저장…"), #selector(saveOutput)), (L("화면 고정"), #selector(pinOutput))] {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: ""); entry.target = self; menu.addItem(entry)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 4, y: 4), in: window!.contentView!)
    }
    @objc private func menuSelectTool(_ sender: NSMenuItem) {
        window?.makeFirstResponder(nil)
        canvas.tool = DrawingTool.allCases[sender.tag]
        updateInfo(); window?.makeFirstResponder(canvas)
    }
    private func applyToolbarPreferences() {
        for (item, button) in configurableButtons { button.isHidden = !item.isVisible }
    }
    deinit { if let toolbarObserver { NotificationCenter.default.removeObserver(toolbarObserver) } }
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(canvas)
    }

    private func row(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.spacing = 0
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        stack.setContentHuggingPriority(.required, for: .vertical)
        return stack
    }

    private func button(_ title: String, _ selector: Selector, _ tip: String? = nil) -> NSButton {
        let symbols: [Selector: String] = [#selector(undoEdit): "arrow.uturn.backward", #selector(redoEdit): "arrow.uturn.forward", #selector(rotateImage): "rotate.left", #selector(flip): "arrow.left.and.right.righttriangle.left.righttriangle.right", #selector(copyOutput): "doc.on.doc", #selector(saveOutput): "square.and.arrow.down", #selector(pinOutput): "pin", #selector(ocr): "text.viewfinder"]
        let button = AnnotationButton(image: NSImage(systemSymbolName: symbols[selector] ?? "ellipsis", accessibilityDescription: title) ?? NSImage(), target: self, action: selector)
        button.image = button.image?.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [.labelColor]))
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.controlSize = .small
        button.contentTintColor = .labelColor
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        button.setAccessibilityLabel(title)
        button.toolTip = title + (tip.map { " (" + $0 + ")" } ?? "")
        return button
    }

    private func updateInfo() {
        colorWell.color = canvas.color
        colorWell.isHidden = canvas.isSelectingOCR || !canvas.colorIsEnabled
        if colorWell.isHidden && colorWell.isActive {
            colorWell.deactivate()
            NSColorPanel.shared.orderOut(nil)
        }
        let showParameter = !canvas.isSelectingOCR && canvas.parameterIsEnabled
        parameter.isHidden = !showParameter
        parameterLabel.isHidden = !showParameter
        for button in toolButtons { button.state = DrawingTool.allCases[button.tag] == canvas.tool ? .on : .off }
        let conceal = canvas.effectiveTool == .conceal
        concealStyles.isHidden = canvas.isSelectingOCR || !conceal
        concealStyles.selectItem(at: ConcealStyle.allCases.firstIndex(of: canvas.concealStyle)!)
        parameter.minValue = conceal ? 2 : 1
        parameter.maxValue = conceal ? 80 : 32
        parameter.doubleValue = Double(canvas.parameterValue)
        parameter.isEnabled = canvas.parameterIsEnabled
        parameter.updateAccessibility(conceal ? L("가리기 세기") : L("주석 두께"))
        parameterLabel.stringValue = conceal ? L("세기") : L("두께")
        info.lineBreakMode = .byTruncatingTail
        info.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        info.stringValue = L("{0} × {1} px  ·  {2}  ·  클릭 선택 · Delete 삭제 · 휠 조절", Int(canvas.image.size.width), Int(canvas.image.size.height), conceal ? canvas.concealStyle.rawValue : canvas.effectiveTool.rawValue)
    }

    @objc private func selectTool(_ sender: NSButton) {
        window?.makeFirstResponder(nil)
        canvas.tool = DrawingTool.allCases[sender.tag]
        updateInfo()
        window?.makeFirstResponder(canvas)
    }
    @objc private func selectColor(_ sender: NSColorWell) { canvas.color = sender.color }
    @objc private func selectWidth(_ sender: NumericStepper) { canvas.setParameter(CGFloat(sender.doubleValue)) }
    @objc private func selectConcealStyle(_ sender: NSPopUpButton) {
        canvas.concealStyle = ConcealStyle.allCases[sender.indexOfSelectedItem]
    }
    @objc private func undoEdit() { canvas.undoEdit() }
    @objc private func redoEdit() { canvas.redoEdit() }
    @objc private func rotateImage() { canvas.commit(Imaging.transformed(canvas.image, quarterTurns: -1)) }
    @objc private func flip() { canvas.commit(Imaging.transformed(canvas.image, flipX: true)) }
    @objc private func copyOutput() { canvas.flushText(); copyImage(canvas.image) }
    @objc private func saveOutput() { canvas.flushText(); saveImage(canvas.image, parent: window) }
    @objc private func pinOutput() { canvas.flushText(); onPin?(canvas.document) }
    @objc private func ocr() {
        canvas.beginOCRSelection { [weak self] image in OCRResultController.present(image, parent: self?.window) }
    }

    private func shortcut(_ event: NSEvent) -> Bool {
        guard let action = ImageKeyboardCommand.resolve(keyCode: event.keyCode, flags: event.modifierFlags) else { return false }
        switch action {
        case .copy: copyOutput()
        case .save: saveOutput()
        case .undo: undoEdit()
        case .redo: redoEdit()
        case .pin: pinOutput()
        }
        return true
    }

    func windowWillClose(_ notification: Notification) { onClose?(self) }
}
