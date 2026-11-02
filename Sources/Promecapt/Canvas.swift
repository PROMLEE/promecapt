import AppKit

final class CanvasView: NSView, NSTextFieldDelegate {
    private(set) var document: AnnotationDocument
    private var renderedImage: NSImage?
    var image: NSImage {
        if let renderedImage { return renderedImage }
        let result = document.rendered(); renderedImage = result; return result
    }
    var contentInset: CGFloat = 24
    var acceptsDrawingAt: ((NSPoint) -> Bool)?
    var onChange: (() -> Void)?
    var onParametersChange: (() -> Void)?
    var onShortcut: ((NSEvent) -> Bool)?
    var onCopy: (() -> Void)?
    private(set) var selectedID: UUID?
    var selectedAnnotation: AnnotationObject? { document.objects.first { $0.id == selectedID } }
    var effectiveTool: DrawingTool { selectedAnnotation?.tool ?? tool }
    private var currentTool: DrawingTool = .pencil
    var tool: DrawingTool {
        get { currentTool }
        set {
            if isSelectingOCR { cancelOCRSelection() }
            currentTool = newValue; if newValue != .select { selectedID = nil }; refreshParameters()
        }
    }
    private(set) var isSelectingOCR = false
    private var ocrLimit = NSRect.zero
    private var ocrCompletion: ((NSImage) -> Void)?
    func beginOCRSelection(in rect: NSRect? = nil, completion: @escaping (NSImage) -> Void) {
        flushText()
        if isSelectingOCR { cancelOCRSelection(); return }
        selectAnnotation(nil); points = []
        ocrLimit = (rect ?? NSRect(origin: .zero, size: document.base.size)).intersection(NSRect(origin: .zero, size: document.base.size))
        ocrCompletion = completion; isSelectingOCR = true; refreshParameters()
        window?.makeFirstResponder(self)
    }
    func cancelOCRSelection() {
        isSelectingOCR = false; ocrCompletion = nil; points = []; refreshParameters()
    }
    @discardableResult func completeOCRSelection(_ rect: NSRect) -> NSImage? {
        guard isSelectingOCR else { return nil }
        let area = rect.integral.intersection(ocrLimit)
        guard area.width >= 4, area.height >= 4 else { points = []; needsDisplay = true; return nil }
        let output = Imaging.crop(image, rect: area), completion = ocrCompletion
        cancelOCRSelection(); completion?(output)
        return output
    }
    private var currentColor: NSColor = .systemRed
    var color: NSColor {
        get { currentColor }
        set { currentColor = newValue; updateSelected { $0.color = AnnotationColor(newValue) }; refreshParameters() }
    }
    private var currentWidth: CGFloat = 4
    var lineWidth: CGFloat {
        get { currentWidth }
        set { currentWidth = newValue; updateSelected { $0.lineWidth = newValue }; refreshParameters() }
    }
    private var currentStrength: CGFloat = 14
    var effectStrength: CGFloat {
        get { currentStrength }
        set { currentStrength = newValue; updateSelected { $0.strength = newValue }; refreshParameters() }
    }
    private var currentConcealStyle: ConcealStyle = .mosaic
    var concealStyle: ConcealStyle {
        get { currentConcealStyle }
        set { currentConcealStyle = newValue; updateSelected { if $0.tool == .conceal { $0.concealStyle = newValue } }; refreshParameters() }
    }
    var parameterValue: CGFloat { effectiveTool == .conceal ? effectStrength : lineWidth }
    var parameterIsEnabled: Bool { effectiveTool != .select && effectiveTool != .crop && !(effectiveTool == .conceal && concealStyle == .blackbox) }
    private var scrollRemainder: CGFloat = 0
    private(set) var activeTextInput: NSTextField?
    private var textPosition: NSPoint = .zero
    private var textEditingID: UUID?
    private var textPanel: AnnotationTextPanel?
    var nextNumber: Int { (document.objects.filter { $0.tool == .number }.compactMap { Int($0.text) }.max() ?? 0) + 1 }
    func addNumber(at point: NSPoint) {
        var object = makeObject([point], text: String(nextNumber)); object.tool = .number
        addAnnotation(object)
    }
    private var previous: [(AnnotationDocument, UUID?)] = []
    private var future: [(AnnotationDocument, UUID?)] = []
    private var points: [NSPoint] = []
    private var draggingObject: AnnotationObject?
    private var dragStart: NSPoint = .zero
    private var resizeHandle: CaptureSelection.Handle?
    private var dragSnapshot: (AnnotationDocument, UUID?)?
    override var acceptsFirstResponder: Bool { true }

    init(image: NSImage) {
        document = AnnotationDocument(base: image)
        super.init(frame: .zero)
        setAccessibilityLabel(L("주석 캔버스. 클릭하여 선택, 드래그하여 이동, 핸들로 크기 조절, Delete로 삭제"))
    }
    required init?(coder: NSCoder) { fatalError() }
    func load(_ document: AnnotationDocument) {
        self.document = document; selectedID = nil; previous = []; future = []; invalidate()
    }
    private func refreshParameters() { needsDisplay = true; window?.invalidateCursorRects(for: self); onParametersChange?() }
    override func resetCursorRects() {
        super.resetCursorRects()
        guard window?.isVisible == true else { return }
        if isSelectingOCR { addCursorRect(imageRect, cursor: .crosshair) }
    }
    private func invalidate() { renderedImage = nil; needsDisplay = true; onChange?(); onParametersChange?() }
    private func checkpoint() {
        previous.append((document, selectedID))
        if previous.count > 50 { previous.removeFirst(previous.count - 50) }
        future = []
    }
    private func updateSelected(_ change: (inout AnnotationObject) -> Void) {
        guard let index = document.objects.firstIndex(where: { $0.id == selectedID }) else { return }
        var next = document.objects[index]; change(&next)
        guard next != document.objects[index] else { return }
        checkpoint(); document.objects[index] = next; invalidate()
    }
    func selectAnnotation(_ id: UUID?) {
        selectedID = document.objects.contains { $0.id == id } ? id : nil
        if let object = selectedAnnotation {
            currentWidth = object.lineWidth; currentStrength = object.strength
            currentColor = object.color.nsColor; currentConcealStyle = object.concealStyle
        }
        refreshParameters()
    }
    func addAnnotation(_ object: AnnotationObject) {
        checkpoint()
        document.objects.append(object)
        if UserDefaults.standard.object(forKey: "autoSelectAnnotations") as? Bool ?? true {
            currentTool = .select
            selectAnnotation(object.id)
        } else { selectedID = nil }
        invalidate()
    }
    func deleteSelection() {
        guard selectedAnnotation != nil else { return }
        checkpoint(); document.objects.removeAll { $0.id == selectedID }; selectedID = nil; invalidate()
    }
    func moveSelection(dx: CGFloat, dy: CGFloat) { updateSelected { $0.move(dx: dx, dy: dy) } }
    func resizeSelection(to rect: NSRect) { updateSelected { $0.resize(to: rect) } }
    func setParameter(_ value: CGFloat) {
        guard parameterIsEnabled else { return }
        if effectiveTool == .conceal { effectStrength = min(80, max(2, value.rounded())) }
        else { lineWidth = min(32, max(1, value.rounded())) }
    }
    func adjustParameter(by steps: CGFloat) { setParameter(parameterValue + steps * (effectiveTool == .conceal ? 2 : 1)) }
    override func scrollWheel(with event: NSEvent) {
        guard !isSelectingOCR, parameterIsEnabled, activeTextInput == nil else { return }
        if event.phase == .began { scrollRemainder = 0 }
        scrollRemainder += event.scrollingDeltaY / (event.hasPreciseScrollingDeltas ? 8 : 1)
        let steps = scrollRemainder.rounded(.towardZero)
        if steps != 0 { scrollRemainder -= steps; adjustParameter(by: steps) }
    }
    var imageRect: NSRect {
        let available = bounds.insetBy(dx: contentInset, dy: contentInset)
        let scale = min(available.width / document.base.size.width, available.height / document.base.size.height)
        let size = NSSize(width: document.base.size.width * scale, height: document.base.size.height * scale)
        return NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }
    private var scale: CGFloat { max(0.001, imageRect.width / document.base.size.width) }
    private func point(_ event: NSEvent) -> NSPoint {
        let local = convert(event.locationInWindow, from: nil), rect = imageRect
        return NSPoint(x: min(document.base.size.width, max(0, (local.x - rect.minX) / scale)),
                       y: min(document.base.size.height, max(0, (local.y - rect.minY) / scale)))
    }
    private func selectionGeometry(_ object: AnnotationObject) -> CaptureSelection {
        var geometry = CaptureSelection(bounds: NSRect(origin: .zero, size: document.base.size))
        let b = object.bounds
        geometry.rect = NSRect(x: b.minX, y: b.minY, width: max(2, b.width), height: max(2, b.height))
        return geometry
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.12, alpha: 1).setFill(); bounds.fill()
        image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: imageRect.minX, yBy: imageRect.minY); transform.scale(by: scale); transform.concat()
        if isSelectingOCR && points.count > 1 {
            NSColor.systemYellow.setStroke()
            let path = NSBezierPath(rect: dragRect); path.lineWidth = 2 / scale
            path.setLineDash([6 / scale, 4 / scale], count: 2, phase: 0); path.stroke()
        } else if points.count > 1 {
            let draft = makeObject(points)
            if tool == .crop || (tool == .conceal && concealStyle != .blackbox) {
                NSColor.systemCyan.setStroke()
                let path = NSBezierPath(rect: draft.bounds); path.lineWidth = 1 / scale
                path.setLineDash([6 / scale, 4 / scale], count: 2, phase: 0); path.stroke()
            } else { draft.draw() }
        }
        if let object = selectedAnnotation, activeTextInput == nil {
            let geometry = selectionGeometry(object)
            NSColor.systemCyan.setStroke()
            let outline = NSBezierPath(rect: geometry.rect); outline.lineWidth = 1 / scale; outline.stroke()
            for handle in CaptureSelection.Handle.allCases {
                let p = geometry.point(for: handle), size = 7 / scale
                let r = NSRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size)
                NSColor.white.setFill(); r.fill(); NSColor.systemCyan.setStroke(); NSBezierPath(rect: r).stroke()
            }
        }
        NSGraphicsContext.restoreGraphicsState()
    }
    private func makeObject(_ points: [NSPoint], text: String = "") -> AnnotationObject {
        AnnotationObject(tool: tool, points: points, color: AnnotationColor(color), lineWidth: lineWidth,
                         strength: effectStrength, concealStyle: concealStyle, text: text)
    }
    private var dragRect: NSRect {
        guard let first = points.first, let last = points.last else { return .zero }
        return NSRect(x: min(first.x, last.x), y: min(first.y, last.y), width: abs(last.x - first.x), height: abs(last.y - first.y))
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let local = convert(event.locationInWindow, from: nil)
        guard imageRect.contains(local), acceptsDrawingAt?(local) != false else { return }
        flushText()
        let p = point(event)
        if isSelectingOCR {
            guard ocrLimit.contains(p) else { return }
            points = [p]; needsDisplay = true; return
        }
        if !event.modifierFlags.contains(.option), tool == .select || ([.text,.number].contains(tool) && event.clickCount >= 2) {
            if let object = selectedAnnotation,
               let handle = selectionGeometry(object).handle(at: p, tolerance: 8 / scale) {
                startObjectDrag(object, at: p, handle: handle); return
            }
            if let object = document.objects.reversed().first(where: { $0.contains(p, tolerance: 6 / scale) }) {
                selectAnnotation(object.id)
                if [.text,.number].contains(object.tool) && event.clickCount >= 2 { beginText(at: object.bounds.origin, editing: object) }
                else { startObjectDrag(object, at: p, handle: nil) }
                return
            }
        }
        selectAnnotation(nil)
        if tool == .select { return }
        if tool == .number { addNumber(at: p); return }
        if tool == .text { beginText(at: p, editing: nil) }
        else { points = [p]; needsDisplay = true }
    }
    private func startObjectDrag(_ object: AnnotationObject, at point: NSPoint, handle: CaptureSelection.Handle?) {
        draggingObject = object; dragStart = point; resizeHandle = handle; dragSnapshot = (document, selectedID)
    }
    override func mouseDragged(with event: NSEvent) {
        let p = point(event)
        if isSelectingOCR, let first = points.first {
            let bounded = NSPoint(x: min(ocrLimit.maxX, max(ocrLimit.minX, p.x)), y: min(ocrLimit.maxY, max(ocrLimit.minY, p.y)))
            points = [first, bounded]; needsDisplay = true; return
        }
        if var object = draggingObject, let index = document.objects.firstIndex(where: { $0.id == object.id }) {
            if let handle = resizeHandle {
                let original = selectionGeometry(object)
                if [.line, .arrow].contains(object.tool), object.points.count == 2 {
                    let h = original.point(for: handle), a = object.points[0], b = object.points[1]
                    let index = hypot(h.x - a.x, h.y - a.y) <= hypot(h.x - b.x, h.y - b.y) ? 0 : 1
                    object.points[index] = p
                } else {
                    var geometry = original
                    geometry.begin(at: geometry.point(for: handle)); geometry.update(to: p)
                    object.resize(to: geometry.rect)
                }
            } else { object.move(dx: p.x - dragStart.x, dy: p.y - dragStart.y) }
            document.objects[index] = object; invalidate(); return
        }
        guard !points.isEmpty else { return }
        if tool == .pencil || tool == .marker { points.append(p) }
        else { points = [points[0], p] }
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        if isSelectingOCR {
            if points.count > 1 { _ = completeOCRSelection(dragRect) }
            return
        }
        if let snapshot = dragSnapshot {
            if snapshot.0.objects != document.objects { previous.append(snapshot); future = [] }
            draggingObject = nil; dragSnapshot = nil; resizeHandle = nil; refreshParameters(); return
        }
        guard points.count > 1 else { points = []; return }
        let object = makeObject(points); points = []
        if tool == .crop {
            checkpoint(); document = document.cropped(to: object.bounds); selectedID = nil; invalidate()
        } else { addAnnotation(object) }
    }
    func beginText(at position: NSPoint, editing object: AnnotationObject? = nil) {
        flushText()
        textPosition = position; textEditingID = object?.id
        let field = NSTextField(string: object?.text ?? "")
        field.font = .systemFont(ofSize: 16)
        field.placeholderString = L("텍스트 입력 후 Enter")
        field.delegate = self; field.setAccessibilityLabel(L("주석 텍스트"))
        activeTextInput = field
        guard let window else { return }
        let panel = AnnotationTextPanel(field: field)
        panel.onApply = { [weak self] in self?.flushText() }
        panel.onCancel = { [weak self] in _ = self?.cancelInteraction() }
        panel.level = NSWindow.Level(rawValue: window.level.rawValue + 1)
        let location = window.convertPoint(toScreen: convert(NSPoint(x: imageRect.minX + position.x * scale, y: imageRect.minY + position.y * scale), to: nil))
        let visible = window.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
        panel.setFrameOrigin(NSPoint(x: min(visible.maxX - panel.frame.width, max(visible.minX, location.x)),
                                     y: min(visible.maxY - panel.frame.height, max(visible.minY, location.y - panel.frame.height))))
        textPanel = panel; window.addChildWindow(panel, ordered: .above)
        NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field); field.selectText(nil)
    }
    private func dismissTextPanel() {
        guard let panel = textPanel else { return }
        textPanel = nil; panel.onCancel = nil
        panel.parent?.removeChildWindow(panel); panel.close()
        window?.makeKeyAndOrderFront(nil); window?.makeFirstResponder(self)
    }
    func flushText() {
        guard let field = activeTextInput else { return }
        let text = field.stringValue, editingID = textEditingID
        field.delegate = nil; activeTextInput = nil; textEditingID = nil; field.removeFromSuperview()
        dismissTextPanel()
        if let editingID, let index = document.objects.firstIndex(where: { $0.id == editingID }) {
            guard document.objects[index].text != text else { return }
            checkpoint()
            if text.isEmpty { document.objects.remove(at: index); selectedID = nil }
            else { document.objects[index].text = text }
            invalidate()
        } else if !text.isEmpty {
            var object = makeObject([textPosition], text: text); object.tool = .text; addAnnotation(object)
        }
    }
    // Commit explicitly with Enter/확인 or when the user changes tools. A temporary
    // field-editor focus transition must not silently remove an empty input field.
    func controlTextDidEndEditing(_ notification: Notification) {}
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) { flushText(); window?.makeFirstResponder(self); return true }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) { _ = cancelInteraction(); window?.makeFirstResponder(self); return true }
        return false
    }
    @discardableResult func cancelInteraction() -> Bool {
        if isSelectingOCR { cancelOCRSelection(); return true }
        if let field = activeTextInput {
            field.delegate = nil; activeTextInput = nil; textEditingID = nil; field.removeFromSuperview()
            dismissTextPanel(); refreshParameters(); return true
        }
        if selectedAnnotation != nil { selectAnnotation(nil); return true }
        return false
    }
    func handleSelectionKey(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, activeTextInput == nil else { return false }
        if isSelectingOCR, event.keyCode == 53 { cancelOCRSelection(); return true }
        guard selectedAnnotation != nil else { return false }
        if event.keyCode == 53 { return cancelInteraction() }
        if [51,117].contains(event.keyCode) { deleteSelection(); return true }
        guard event.modifierFlags.intersection([.command,.option,.control]).isEmpty else { return false }
        let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
        switch event.keyCode {
        case 123: moveSelection(dx: -step, dy: 0)
        case 124: moveSelection(dx: step, dy: 0)
        case 125: moveSelection(dx: 0, dy: -step)
        case 126: moveSelection(dx: 0, dy: step)
        default: return false
        }
        return true
    }
    func commit(_ output: NSImage) {
        checkpoint(); document = AnnotationDocument(base: output); selectedID = nil; invalidate()
    }
    func undoEdit() {
        flushText()
        guard let last = previous.popLast() else { return }
        future.append((document, selectedID)); document = last.0; selectedID = last.1
        selectAnnotation(selectedID); invalidate()
    }
    func redoEdit() {
        guard let last = future.popLast() else { return }
        previous.append((document, selectedID)); document = last.0; selectedID = last.1
        selectAnnotation(selectedID); invalidate()
    }
    @objc func copy(_ sender: Any?) { flushText(); if let onCopy { onCopy() } else { copyImage(image) } }
    override func keyDown(with event: NSEvent) {
        if [36,76].contains(event.keyCode), !event.modifierFlags.contains(.command) { return }
        if !handleSelectionKey(event), onShortcut?(event) != true { super.keyDown(with: event) }
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool { handleSelectionKey(event) || (onShortcut?(event) ?? false) }
}
