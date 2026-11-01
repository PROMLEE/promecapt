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
        case .rectangle: return L("사각형: 드래그하여 계속 그리기 · 수정은 화살표 선택 도구에서 · 휠로 두께 조절")
        case .ellipse: return L("타원: 드래그하여 계속 그리기 · 수정은 화살표 선택 도구에서 · 휠로 두께 조절")
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
    private let tools = NSSegmentedControl()
    private let concealStyles = NSPopUpButton()
    private let parameter = NumericStepper(frame: .zero)
    private let parameterLabel = NSTextField(labelWithString: L("두께 4"))
    private let colorWell = NSColorWell()
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
        window.contentView = root

        tools.segmentCount = DrawingTool.allCases.count
        for (index, tool) in DrawingTool.allCases.enumerated() {
            tools.setLabel(L(tool.rawValue), forSegment: index)
            tools.setToolTip(tool.tip, forSegment: index)
        }
        tools.selectedSegment = 0
        tools.target = self
        tools.action = #selector(selectTool)
        tools.toolTip = L("영역 도구는 이미지에서 드래그합니다. 텍스트는 클릭합니다.")
        concealStyles.addItems(withTitles: ConcealStyle.allCases.map { L($0.rawValue) })
        concealStyles.target = self; concealStyles.action = #selector(selectConcealStyle(_:))
        concealStyles.setAccessibilityLabel(L("가리기 방식"))
        let toolRow = row([tools, concealStyles])
        root.addArrangedSubview(toolRow)

        let color = colorWell
        color.color = .systemRed
        color.target = self
        color.action = #selector(selectColor(_:))
        color.widthAnchor.constraint(equalToConstant: 44).isActive = true
        parameter.target = self; parameter.action = #selector(selectWidth(_:))
        let actions = row([
            color, parameterLabel, parameter,
            button(L("실행 취소"), #selector(undoEdit), "⌘Z"), button(L("다시 실행"), #selector(redoEdit), "⇧⌘Z"),
            button(L("회전"), #selector(rotateImage)), button(L("좌우 반전"), #selector(flip)),
            button(L("복사"), #selector(copyOutput), "⌘C"), button(L("저장…"), #selector(saveOutput), "⌘S"),
            button(L("화면 고정"), #selector(pinOutput), "⌘↩")])
        root.addArrangedSubview(actions)
        canvas.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(canvas)
        let bottom = row([info])
        ocrButton = button(L("텍스트 추출 (OCR)"), #selector(ocr))
        bottom.addArrangedSubview(ocrButton)
        root.addArrangedSubview(bottom)
        for view in [toolRow, actions, canvas, bottom] {
            view.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        }
        canvas.heightAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        canvas.setContentHuggingPriority(.defaultLow, for: .vertical)
        canvas.onChange = { [weak self] in self?.updateInfo() }
        canvas.onParametersChange = { [weak self] in self?.updateInfo() }
        canvas.onShortcut = { [weak self] event in self?.shortcut(event) ?? false }
        updateInfo()
    }

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
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        stack.setContentHuggingPriority(.required, for: .vertical)
        return stack
    }

    private func button(_ title: String, _ selector: Selector, _ tip: String? = nil) -> NSButton {
        let button = NSButton(title: title, target: self, action: selector)
        button.bezelStyle = .rounded
        button.toolTip = tip
        return button
    }

    private func updateInfo() {
        colorWell.color = canvas.color
        tools.selectedSegment = DrawingTool.allCases.firstIndex(of: canvas.tool)!
        let conceal = canvas.effectiveTool == .conceal
        concealStyles.isHidden = !conceal
        concealStyles.selectItem(at: ConcealStyle.allCases.firstIndex(of: canvas.concealStyle)!)
        parameter.minValue = conceal ? 2 : 1
        parameter.maxValue = conceal ? 80 : 32
        parameter.doubleValue = Double(canvas.parameterValue)
        parameter.isEnabled = canvas.parameterIsEnabled
        parameter.updateAccessibility(conceal ? L("가리기 세기") : L("주석 두께"))
        parameterLabel.stringValue = conceal ? L("세기") : L("두께")
        info.stringValue = L("{0} × {1} px  ·  {2}  ·  클릭 선택 · Delete 삭제 · 휠 조절", Int(canvas.image.size.width), Int(canvas.image.size.height), conceal ? canvas.concealStyle.rawValue : canvas.effectiveTool.rawValue)
    }

    @objc private func selectTool() {
        window?.makeFirstResponder(nil)
        canvas.tool = DrawingTool.allCases[tools.selectedSegment]
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
