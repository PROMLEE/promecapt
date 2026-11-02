import AppKit

final class PinWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 53,
           (firstResponder as? NSTextView)?.isFieldEditor != true,
           let pin = delegate as? PinController {
            pin.handleEscape()
            return
        }
        super.sendEvent(event)
    }
}

final class PinController: NSWindowController, NSWindowDelegate {
    let id: UUID
    var image: NSImage
    private(set) var gifData: Data?
    private var animationView: AnimatedGIFView?
    private(set) var annotationDocument: AnnotationDocument?
    var group: String = ""
    var onChange: (() -> Void)?
    var onClose: ((PinController) -> Void)?
    var onEdit: ((NSImage) -> Void)?
    var onDrop: ((NSImage) -> Void)?
    private var normalSize: NSSize?
    private var imageView: PinView!
    var isEditingAnnotations: Bool { editCanvas != nil }
    private var editCanvas: CanvasView?
    private var editTools: NSPanel?

    init(image: NSImage, id: UUID = UUID()) {
        self.id = id
        self.image = image
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let factor = min(1, min(visible.width * 0.65 / image.size.width, visible.height * 0.65 / image.size.height))
        let size = NSSize(width: max(32, image.size.width * factor), height: max(32, image.size.height * factor))
        let panel = PinWindow(contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        super.init(window: panel)
        panel.title = L("Promecapt — 고정 이미지")
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = UserDefaults.standard.object(forKey: "pinShadow") as? Bool ?? true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.minSize = NSSize(width: 32, height: 32)
        panel.contentAspectRatio = image.size
        panel.delegate = self
        imageView = PinView()
        imageView.owner = self
        panel.contentView = imageView
        panel.center()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(imageView)
    }

    func replace(_ next: NSImage) {
        animationView?.removeFromSuperview(); animationView = nil; gifData = nil
        annotationDocument = nil
        image = next
        window?.contentAspectRatio = next.size
        imageView.needsDisplay = true
        onChange?()
    }
    func setGIF(_ data: Data) {
        guard let poster = GIFMedia.poster(data) else { return }
        replace(poster)
        gifData = data
        let view = AnimatedGIFView(data: data)
        view.frame = imageView.bounds; view.autoresizingMask = [.width, .height]
        imageView.addSubview(view); animationView = view
        window?.title = L("Promecapt — 고정 GIF")
        onChange?()
    }

    func setDocument(_ document: AnnotationDocument) {
        replace(document.rendered())
        annotationDocument = document
        onChange?()
    }

    func zoom(_ factor: CGFloat) {
        guard let window else { return }
        var frame = window.frame
        let size = NSSize(width: min(6000, max(32, frame.width * factor)), height: min(6000, max(32, frame.height * factor)))
        frame.origin.x -= (size.width - frame.width) / 2
        frame.origin.y -= (size.height - frame.height) / 2
        frame.size = size
        window.setFrame(frame, display: true)
        onChange?()
    }

    @objc func copyPin() {
        if let gifData { do { try GIFMedia.copy(gifData) } catch { showError(error.localizedDescription) }; return }
        editCanvas?.flushText(); copyImage(editCanvas?.image ?? image)
    }
    @objc func savePin() {
        if let gifData { GIFMedia.save(gifData); return }
        editCanvas?.flushText(); saveImage(editCanvas?.image ?? image)
    }
    @objc func editPin() {
        guard gifData == nil else { return }
        if editCanvas != nil { finishEditing(apply: true); return }
        guard let window else { return }
        let canvas = CanvasView(image: image)
        if let annotationDocument { canvas.load(annotationDocument) }
        canvas.contentInset = 0
        canvas.frame = imageView.bounds
        canvas.autoresizingMask = [.width, .height]
        imageView.addSubview(canvas)
        editCanvas = canvas
        window.isMovableByWindowBackground = false
        let tools = PinWindow(contentRect: NSRect(origin: .zero, size: AnnotationBar.preferredSize),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        tools.isReleasedWhenClosed = false
        tools.title = L("Promecapt · 고정 이미지 주석")
        tools.backgroundColor = .clear
        tools.isOpaque = false
        tools.hasShadow = true
        let bar = AnnotationBar(frame: NSRect(origin: .zero, size: AnnotationBar.preferredSize))
        bar.info.stringValue = L("Space: 편집 완료")
        bar.onTool = { [weak self, weak bar] tool in
            guard let self else { return }
            self.editCanvas?.flushText()
            self.editCanvas?.tool = tool ?? .select
            if let canvas = self.editCanvas { bar?.sync(with: canvas) }
            self.editCanvas?.isHidden = false
            self.window?.isMovableByWindowBackground = false
            self.window?.makeKeyAndOrderFront(nil)
            self.window?.makeFirstResponder(self.editCanvas)
        }
        bar.onUndo = { [weak canvas] in canvas?.undoEdit() }
        bar.onRedo = { [weak canvas] in canvas?.redoEdit() }
        bar.onColor = { [weak canvas] in canvas?.color = $0 }
        bar.onParameter = { [weak canvas] in canvas?.setParameter($0) }
        bar.onConcealStyle = { [weak canvas] in canvas?.concealStyle = $0 }
        canvas.onParametersChange = { [weak canvas, weak bar] in
            guard let canvas else { return }
            bar?.sync(with: canvas)
        }
        bar.onCopy = { [weak self] in self?.copyPin() }
        bar.onSave = { [weak self] in self?.savePin() }
        bar.onPin = { [weak self] in self?.finishEditing(apply: true) }
        bar.onCancel = { [weak self] in self?.finishEditing(apply: false) }
        bar.onOCR = { [weak self] in self?.extractText() }
        bar.onSizeChange = { [weak self] in self?.positionTools() }
        tools.contentView = bar
        editTools = tools
        window.addChildWindow(tools, ordered: .above)
        positionTools()
        canvas.onShortcut = { [weak self] event in
            guard let self else { return false }
            if event.keyCode == 49 && self.editCanvas?.activeTextInput == nil { self.finishEditing(apply: true); return true }
            if event.keyCode == 53 { self.finishEditing(apply: false); return true }
            guard event.modifierFlags.contains(.command) else { return false }
            guard let action = ImageKeyboardCommand.resolve(keyCode: event.keyCode, flags: event.modifierFlags) else { return false }
            switch action {
            case .undo: self.editCanvas?.undoEdit()
            case .redo: self.editCanvas?.redoEdit()
            case .copy: self.copyPin()
            case .save: self.savePin()
            case .pin: self.finishEditing(apply: true)
            }
            return true
        }
        bar.choose(0)
        tools.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(canvas)
    }
    private func finishEditing(apply: Bool) {
        guard let canvas = editCanvas else { return }
        canvas.flushText()
        let edited = canvas.document
        canvas.removeFromSuperview()
        editCanvas = nil
        if let tools = editTools { window?.removeChildWindow(tools); tools.close() }
        editTools = nil
        window?.isMovableByWindowBackground = true
        window?.makeFirstResponder(imageView)
        if apply { setDocument(edited) }
    }
    private func positionTools() {
        guard let frame = window?.frame, let tools = editTools else { return }
        let visible = window?.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
        let size = (tools.contentView as? AnnotationBar)?.preferredSize ?? AnnotationBar.preferredSize
        tools.setContentSize(size)
        var origin = NSPoint(x: frame.midX - size.width / 2, y: frame.minY - size.height - 8)
        origin.x = max(visible.minX + 8, min(visible.maxX - size.width - 8, origin.x))
        if origin.y < visible.minY { origin.y = min(visible.maxY - size.height, frame.maxY + 10) }
        tools.setFrameOrigin(origin)
    }
    @objc func closePin() { window?.close() }
    @objc func extractText() {
        if editCanvas == nil { editPin() }
        editCanvas?.beginOCRSelection { [weak self] image in OCRResultController.present(image, parent: self?.window) }
    }
    func handleEscape() {
        if let canvas = editCanvas {
            if !canvas.cancelInteraction() { finishEditing(apply: false) }
        }
        else { closePin() }
    }
    @objc func hidePin() { window?.orderOut(nil) }
    @objc func rotateLeft() { guard gifData == nil else { return }; transform(turns: 1) }
    @objc func rotateRight() { guard gifData == nil else { return }; transform(turns: -1) }
    @objc func flipHorizontal() { guard gifData == nil else { return }; replace(Imaging.transformed(image, flipX: true)) }
    @objc func flipVertical() { guard gifData == nil else { return }; replace(Imaging.transformed(image, flipY: true)) }
    @objc func actualSize() {
        window?.setContentSize(image.size)
        onChange?()
    }
    @objc func thumbnail() {
        guard let window else { return }
        if let size = normalSize { window.setContentSize(size); normalSize = nil }
        else {
            normalSize = window.frame.size
            let factor = 160 / max(image.size.width, image.size.height)
            window.setContentSize(NSSize(width: image.size.width * factor, height: image.size.height * factor))
        }
        onChange?()
    }
    @objc func clickThrough() {
        window?.ignoresMouseEvents = true
        // Always recoverable through the menu-bar command, including after restart.
    }
    @objc func setGroup() {
        let alert = NSAlert()
        alert.messageText = L("고정 이미지 그룹")
        alert.informativeText = L("그룹 이름을 입력하세요. 비워 두면 그룹 지정이 해제됩니다.")
        let input = NSTextField(string: group)
        input.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = input
        alert.addButton(withTitle: L("저장"))
        alert.addButton(withTitle: L("취소"))
        if alert.runModal() == .alertFirstButtonReturn {
            group = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            onChange?()
        }
    }

    @objc func clearGroup() {
        group = ""
        onChange?()
    }

    func opacity(_ delta: CGFloat) {
        guard let window else { return }
        window.alphaValue = min(1, max(0.15, window.alphaValue + delta))
        onChange?()
    }

    private func transform(turns: Int) {
        let old = window!.frame.size
        replace(Imaging.transformed(image, quarterTurns: turns))
        window?.setContentSize(NSSize(width: old.height, height: old.width))
        onChange?()
    }

    func windowWillClose(_ notification: Notification) { finishEditing(apply: true); onClose?(self) }
    func windowDidMove(_ notification: Notification) { positionTools(); onChange?() }
    func windowDidResize(_ notification: Notification) { positionTools(); onChange?() }

    func contextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let groupLabel = menu.addItem(withTitle: L("그룹: {0}", group.isEmpty ? L("미지정") : group), action: nil, keyEquivalent: "")
        groupLabel.isEnabled = false
        menu.addItem(.separator())
        let actions: [(String, Selector)] = [
            (L("복사  ⌘C"), #selector(copyPin)), (L("다른 이름으로 저장…"), #selector(savePin)),
            (L("텍스트 영역 선택 (OCR)…"), #selector(extractText)),
            (L("주석 편집  Space"), #selector(editPin)), (L("원본 크기  0"), #selector(actualSize)),
            (L("왼쪽 회전  1"), #selector(rotateLeft)), (L("오른쪽 회전  2"), #selector(rotateRight)),
            (L("좌우 반전  3"), #selector(flipHorizontal)), (L("상하 반전  4"), #selector(flipVertical)),
            (L("썸네일 전환"), #selector(thumbnail)), (L("클릭 통과 (메뉴 막대에서 해제)"), #selector(clickThrough)),
            (L("그룹 설정…"), #selector(setGroup)), (L("그룹 해제"), #selector(clearGroup)),
            (L("숨기기 (더블 클릭)"), #selector(hidePin)),
            (L("닫기  Esc"), #selector(closePin))]
        for (title, action) in actions {
            let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
            item.target = self
            if gifData != nil && [#selector(editPin), #selector(extractText), #selector(rotateLeft), #selector(rotateRight), #selector(flipHorizontal), #selector(flipVertical)].contains(action) { item.isEnabled = false }
            if action == #selector(clearGroup) { item.isEnabled = !group.isEmpty }
        }
        return menu
    }
}

final class PinView: NSView, NSDraggingSource {
    private var scrollSteps = ScrollSteps()
    private var adjustsOpacity = false
    weak var owner: PinController?
    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .tiff, .png])
        setAccessibilityLabel(L("Promecapt 고정 이미지"))
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let owner else { return }
        owner.image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
        NSColor.white.withAlphaComponent(0.4).setStroke()
        NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).stroke()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if event.modifierFlags.contains(.command), let image = owner?.image {
            let item = NSDraggingItem(pasteboardWriter: image)
            item.setDraggingFrame(bounds, contents: image)
            beginDraggingSession(with: [item], event: event, source: self)
            return
        }
        if event.clickCount == 2 {
            if event.modifierFlags.contains(.shift) { owner?.thumbnail() } else { owner?.hidePin() }
        } else { super.mouseDown(with: event) }
    }

    override func menu(for event: NSEvent) -> NSMenu? { owner?.contextMenu() }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let image = NSImage(pasteboard: pasteboard) {
            owner?.onDrop?(Imaging.normalized(image)); return true
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            var accepted = false
            for url in urls where url.isFileURL {
                if let image = NSImage(contentsOf: url) { owner?.onDrop?(Imaging.normalized(image)); accepted = true }
            }
            return accepted
        }
        return false
    }
    override func scrollWheel(with event: NSEvent) {
        let opacity = event.modifierFlags.contains(.control)
        if opacity != adjustsOpacity { scrollSteps.reset(); adjustsOpacity = opacity }
        let steps = scrollSteps.consume(event)
        guard steps != 0 else { return }
        if opacity { owner?.opacity(CGFloat(steps) * 0.02) }
        else { owner?.zoom(pow(1.03, CGFloat(steps))) }
    }
    @objc func copy(_ sender: Any?) { owner?.copyPin() }
    override func cancelOperation(_ sender: Any?) { owner?.closePin() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { owner?.closePin(); return }
        if let action = ImageKeyboardCommand.resolve(keyCode: event.keyCode, flags: event.modifierFlags) {
            if action == .copy { owner?.copyPin(); return }
            if action == .save { owner?.savePin(); return }
        }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case " ": owner?.editPin()
        case "0": owner?.actualSize()
        case "1": owner?.rotateLeft()
        case "2": owner?.rotateRight()
        case "3": owner?.flipHorizontal()
        case "4": owner?.flipVertical()
        case "+", "=": owner?.zoom(1.1)
        case "-": owner?.zoom(1 / 1.1)
        case "\u{7f}": owner?.closePin()
        default: super.keyDown(with: event)
        }
    }
}
