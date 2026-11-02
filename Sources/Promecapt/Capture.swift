import AppKit
import ScreenCaptureKit

struct CaptureSurface {
    let screen: NSScreen
    let image: NSImage
    var windows: [CaptureWindowTarget] = []
}

enum ScreenSnapshots {
    static func capture(completion: @escaping (Result<[CaptureSurface], Error>) -> Void) {
        if #available(macOS 14.0, *) {
            SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { content, error in
                DispatchQueue.main.async {
                    guard let content else { completion(.failure(error ?? CocoaError(.fileReadUnknown))); return }
                    let screens = NSScreen.screens
                    var surfaces: [CaptureSurface] = []
                    func next(_ index: Int) {
                        guard index < screens.count else { completion(.success(surfaces)); return }
                        let screen = screens[index]
                        let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
                        guard let display = content.displays.first(where: { $0.displayID == displayID }) else { next(index + 1); return }
                        // Dashboard/preferences are already hidden. Capture the complete display,
                        // including our menu icon and any pinned images the user wants to capture.
                        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                        let config = SCStreamConfiguration()
                        config.width = Int(screen.frame.width * screen.backingScaleFactor)
                        config.height = Int(screen.frame.height * screen.backingScaleFactor)
                        config.showsCursor = false
                        SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { cg, error in
                            DispatchQueue.main.async {
                                guard let cg else { completion(.failure(error ?? CocoaError(.fileReadUnknown))); return }
                                let candidates = CaptureTargetDetector.windows(on: screen)
                                surfaces.append(CaptureSurface(screen: screen,
                                    image: NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height)), windows: candidates))
                                next(index + 1)
                            }
                        }
                    }
                    next(0)
                }
            }
        } else {
            // macOS 13 fallback only takes snapshots. Selection and annotation remain our own UI.
            let screens = NSScreen.screens
            var surfaces: [CaptureSurface] = []
            func next(_ index: Int) {
                guard index < screens.count else { completion(.success(surfaces)); return }
                let file = FileManager.default.temporaryDirectory.appendingPathComponent("Promecapt-\(UUID().uuidString).png")
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                process.arguments = ["-x", "-D", String(index + 1), "-t", "png", file.path]
                process.standardError = FileHandle.nullDevice
                process.terminationHandler = { _ in
                    DispatchQueue.main.async {
                        defer { try? FileManager.default.removeItem(at: file) }
                        guard let image = NSImage(contentsOf: file) else { completion(.failure(CocoaError(.fileReadUnknown))); return }
                        surfaces.append(CaptureSurface(screen: screens[index], image: Imaging.normalized(image), windows: CaptureTargetDetector.windows(on: screens[index])))
                        next(index + 1)
                    }
                }
                do { try process.run() } catch { completion(.failure(error)) }
            }
            next(0)
        }
    }
}

enum CaptureDestination { case copy, pin, save, gif }

private final class CaptureWindow: NSWindow {
    var handleShortcut: ((NSEvent) -> Bool)?
    override func sendEvent(_ event: NSEvent) {
        super.sendEvent(event)
        if [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .cursorUpdate, .mouseEntered, .mouseExited].contains(event.type) {
            (contentView as? CaptureView)?.refreshPointer(at: event.locationInWindow)
        }
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleShortcut?(event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }
}

final class CaptureSession {
    var onFinish: ((AnnotationDocument, CaptureDestination, NSRect, CaptureHistoryContext) -> Void)?
    var onCancel: (() -> Void)?
    private var windows: [NSWindow] = []
    private var completed = false
    var historyCount = 0
    var historyImage: ((Int) -> CaptureHistoryItem?)?
    var recordingSelection = false

    func start(_ surfaces: [CaptureSurface], full: Bool) {
        for surface in surfaces {
            let window = CaptureWindow(contentRect: surface.screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.title = L("Promecapt · 영역 선택 및 주석")
            window.isReleasedWhenClosed = false
            window.hidesOnDeactivate = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.backgroundColor = .black
            window.acceptsMouseMovedEvents = true
            let view = CaptureView(surface: surface)
            view.historyCount = historyCount; view.historyImage = historyImage
            view.recordingSelection = recordingSelection
            window.handleShortcut = { [weak view] in view?.shortcut($0) ?? false }
            view.onFinish = { [weak self] image, destination, rect, context in
                guard let self, !self.completed else { return }
                self.completed = true
                self.close()
                self.onFinish?(image, destination, rect, context)
            }
            view.onCancel = { [weak self] in
                guard let self, !self.completed else { return }
                self.completed = true
                self.close()
                self.onCancel?()
            }
            window.contentView = view
            windows.append(window)
            window.setFrame(surface.screen.frame, display: true)
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)
            if full && surface.screen == NSScreen.main { view.selectAll() }
            else if UserDefaults.standard.bool(forKey: "rememberRegion"),
                    let last = UserDefaults.standard.string(forKey: "lastCaptureRect") {
                view.restoreRegion(NSRectFromString(last))
            }
        }
        if let mouseScreen = surfaces.firstIndex(where: { $0.screen.frame.contains(NSEvent.mouseLocation) }) {
            windows[mouseScreen].makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.completed else { return }
            for window in self.windows {
                window.invalidateCursorRects(for: window.contentView!)
                (window.contentView as? CaptureView)?.startInteraction()
            }
        }
    }
    func close() {
        completed = true
        for window in windows {
            (window.contentView as? CaptureView)?.stopInteraction()
            (window as? CaptureWindow)?.handleShortcut = nil
            window.acceptsMouseMovedEvents = false
            window.discardCursorRects()
            window.orderOut(nil); window.close()
        }
        windows.removeAll()
        NSCursor.arrow.set()
    }
}

enum CapturePointerStyle: Equatable {
    case arrow, crosshair
    static func forMode(selectingRegion: Bool, selectingOCR: Bool) -> Self {
        selectingRegion || selectingOCR ? .crosshair : .arrow
    }
    var cursor: NSCursor { self == .arrow ? .arrow : .crosshair }
}

final class CaptureView: NSView {
    let canvas: CanvasView
    var selection: CaptureSelection
    let bar = AnnotationBar(frame: .zero)
    var onFinish: ((AnnotationDocument, CaptureDestination, NSRect, CaptureHistoryContext) -> Void)?
    var onCancel: (() -> Void)?
    private let surface: CaptureSurface
    var historyCount = 0
    var historyImage: ((Int) -> CaptureHistoryItem?)?
    var recordingSelection = false
    private var historyCursor = CaptureHistoryCursor()
    private var historyStates: [Int: (AnnotationDocument, NSRect)] = [:]
    private func browseHistory(older: Bool) {
        guard !recordingSelection, !canvas.isSelectingOCR else { return }
        var cursor = historyCursor
        guard let index = cursor.move(older: older, count: historyCount) else { NSSound.beep(); return }
        canvas.flushText()
        let state: (AnnotationDocument, NSRect)
        if let saved = historyStates[index] { state = saved }
        else if index >= 0, let image = historyImage?(index) { state = CaptureHistoryLayout.place(image, in: surface) }
        else { NSSound.beep(); return }
        historyStates[historyCursor.index] = (canvas.document, selection.rect)
        historyCursor = cursor
        bar.onRecord = index < 0 ? { [weak self] in self?.finish(.gif) } : nil
        canvas.cancelOCRSelection(); canvas.load(state.0); selection.rect = state.1
        pendingTarget = nil; dragging = false; detector.cancel(); changed()
        if index >= 0 { bar.info.stringValue = L("기록 {0}/{1} · , 이전 / . 다음", index + 1, historyCount) }
    }
    private var tool: DrawingTool?
    private var dragging = false
    private var windowMode = false
    private var hoveredWindow: NSRect?
    private let detector = CaptureTargetDetector()
    private var targets: [CaptureTarget] = []
    private var targetIndex = 0
    private var lastProbe: NSPoint?
    private var pendingTarget: NSRect?
    private var downPoint = NSPoint.zero
    private var automaticTargets: Bool { UserDefaults.standard.object(forKey: "autoDetectTargets") as? Bool ?? true }
    private var interactionActive = true
    private var pointerTimer: Timer?

    func startInteraction() {
        guard pointerTimer == nil, interactionActive else { return }
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.refreshPointer() }
        RunLoop.main.add(timer, forMode: .common)
        pointerTimer = timer
        if let window { updateTarget(at: convert(window.mouseLocationOutsideOfEventStream, from: nil)) }
        refreshPointer()
    }
    override var acceptsFirstResponder: Bool { true }

    init(surface: CaptureSurface) {
        self.surface = surface
        canvas = CanvasView(image: surface.image)
        selection = CaptureSelection(bounds: NSRect(origin: .zero, size: surface.screen.frame.size))
        super.init(frame: NSRect(origin: .zero, size: surface.screen.frame.size))
        canvas.frame = bounds
        canvas.autoresizingMask = [.width, .height]
        canvas.contentInset = 0
        canvas.acceptsDrawingAt = { [weak self] point in self?.selection.rect.insetBy(dx: 5, dy: 5).contains(point) ?? false }
        canvas.onShortcut = { [weak self] in self?.shortcut($0) ?? false }
        canvas.onCopy = { [weak self] in self?.finish(.copy) }
        addSubview(canvas)
        // A transparent overlay shades the canvas, while hit testing routes annotation to it.
        let shade = CaptureShade(frame: bounds)
        shade.owner = self
        shade.autoresizingMask = [.width, .height]
        addSubview(shade)
        addSubview(bar)
        bar.isHidden = true
        bar.onSizeChange = { [weak self] in self?.positionBar() }
        bar.onDrag = { [weak self] delta in
            guard let self else { return }
            self.manualBarOrigin = NSPoint(x: self.bar.frame.minX + delta.x, y: self.bar.frame.minY + delta.y)
            self.positionBar()
        }
        bar.onTool = { [weak self] tool in
            guard let self else { return }
            self.canvas.flushText()
            self.tool = tool
            if let tool { self.canvas.tool = tool }
            else { self.canvas.selectAnnotation(nil) }
            self.bar.sync(with: self.canvas)
            self.window?.invalidateCursorRects(for: self)
            self.window?.makeFirstResponder(self)
        }
        bar.onUndo = { [weak self] in self?.canvas.undoEdit() }
        bar.onRedo = { [weak self] in self?.canvas.redoEdit() }
        bar.onColor = { [weak self] in self?.canvas.color = $0 }
        bar.onParameter = { [weak self] in self?.canvas.setParameter($0) }
        bar.onConcealStyle = { [weak self] in self?.canvas.concealStyle = $0 }
        canvas.onParametersChange = { [weak self] in
            guard let self else { return }
            self.bar.sync(with: self.canvas)
            self.window?.invalidateCursorRects(for: self)
        }
        bar.onRecord = { [weak self] in self?.finish(.gif) }
        bar.onCopy = { [weak self] in self?.finish(.copy) }
        bar.onSave = { [weak self] in self?.finish(.save) }
        bar.onPin = { [weak self] in self?.finish(.pin) }
        bar.onCancel = { [weak self] in self?.onCancel?() }
        bar.onOCR = { [weak self] in
            guard let self, self.selection.isValid else { return }
            self.canvas.beginOCRSelection(in: self.selection.pixelRect(imageSize: self.canvas.image.size)) { [weak self] image in
                OCRResultController.present(image, parent: self?.window)
            }
        }
        let tracking = NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseMoved, .cursorUpdate, .inVisibleRect], owner: self)
        addTrackingArea(tracking)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(L("캡처 영역 선택. 드래그로 선택하고 8개 핸들로 크기를 조절합니다."))
    }
    required init?(coder: NSCoder) { fatalError() }

    func stopInteraction() {
        interactionActive = false
        pointerTimer?.invalidate(); pointerTimer = nil
        detector.cancel()
        for area in trackingAreas { removeTrackingArea(area) }
        bar.dismissHelp()
        bar.isHidden = true
        onFinish = nil; onCancel = nil
    }
    override func resetCursorRects() {
        super.resetCursorRects()
        guard interactionActive, window?.isVisible == true else { return }
        addCursorRect(bounds, cursor: tool == .select ? .arrow : tool == .text ? .iBeam : .crosshair)
        if selection.isValid {
            if canvas.isSelectingOCR { addCursorRect(selection.rect, cursor: .crosshair) }
            else if tool == nil {
                addCursorRect(selection.rect, cursor: .openHand)
                for handle in CaptureSelection.Handle.allCases {
                    let p = selection.point(for: handle)
                    let cursor: NSCursor = [.west,.east].contains(handle) ? .resizeLeftRight : [.north,.south].contains(handle) ? .resizeUpDown : .arrow
                    addCursorRect(NSRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16), cursor: cursor)
                }
            }
        }
        if !bar.isHidden { addCursorRect(bar.frame, cursor: .arrow) }
    }

    override func scrollWheel(with event: NSEvent) {
        if tool != nil && selection.isValid { canvas.scrollWheel(with: event) }
        else { super.scrollWheel(with: event) }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if !bar.isHidden && bar.frame.contains(point) { return bar.hitTest(point) ?? bar }
        if let input = canvas.activeTextInput, input.window === window, input.frame.contains(point) { return canvas.hitTest(point) }
        if canvas.isSelectingOCR, selection.isValid, selection.rect.contains(point) { return canvas.hitTest(point) }
        if tool != nil && selection.isValid && selection.handle(at: point) == nil && selection.rect.insetBy(dx: 5, dy: 5).contains(point) {
            return canvas.hitTest(point)
        }
        return self
    }
    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        guard bar.isHidden || !bar.frame.contains(p) else { return }
        canvas.flushText()
        window?.makeFirstResponder(self)
        downPoint = p
        if !selection.isValid {
            updateTarget(at: p)
            pendingTarget = hoveredWindow
        }
        selection.begin(at: p)
        dragging = true
        bar.isHidden = true
        needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        guard dragging else { return }
        let p = convert(event.locationInWindow, from: nil)
        if pendingTarget != nil {
            guard hypot(p.x - downPoint.x, p.y - downPoint.y) > 4 else { return }
            pendingTarget = nil
            selection.begin(at: downPoint, forceNew: true)
        }
        selection.update(to: p)
        subviews.forEach { $0.needsDisplay = true }
    }
    override func mouseUp(with event: NSEvent) {
        guard dragging else { return }
        if let pendingTarget { selection.rect = pendingTarget }
        else { selection.update(to: convert(event.locationInWindow, from: nil)) }
        pendingTarget = nil
        dragging = false
        detector.cancel()
        changed()
        if recordingSelection && selection.isValid { finish(.gif) }
    }
    override func mouseMoved(with event: NSEvent) {
        guard interactionActive, window?.isVisible == true, event.window === window else { return }
        updateTarget(at: convert(event.locationInWindow, from: nil))
    }
    func refreshPointer(at location: NSPoint? = nil) {
        guard interactionActive, let window, window.isVisible, NSApp.isActive else { return }
        let p = convert(location ?? window.mouseLocationOutsideOfEventStream, from: nil)
        guard bounds.contains(p) else { return }
        if !bar.isHidden && bar.frame.contains(p) { NSCursor.arrow.set() }
        else if canvas.isSelectingOCR && selection.rect.contains(p) { NSCursor.crosshair.set() }
        else if selection.isValid && tool == nil, let handle = selection.handle(at: p) {
            let cursor: NSCursor = [.west,.east].contains(handle) ? .resizeLeftRight : [.north,.south].contains(handle) ? .resizeUpDown : .arrow
            cursor.set()
        }
        else if selection.isValid && tool == nil && selection.rect.contains(p) { NSCursor.openHand.set() }
        else if tool == .text { NSCursor.iBeam.set() }
        else if canvas.isSelectingOCR || tool != .select { NSCursor.crosshair.set() }
        else { NSCursor.arrow.set() }
    }
    override func cursorUpdate(with event: NSEvent) { refreshPointer() }
    private func updateTarget(at p: NSPoint, force: Bool = false) {
        guard !selection.isValid, !dragging, automaticTargets || windowMode else { return }
        if !force, let lastProbe, hypot(p.x - lastProbe.x, p.y - lastProbe.y) < 1 { return }
        lastProbe = p
        detector.cancel()
        guard let candidate = surface.windows.first(where: { $0.rect.contains(p) }) else {
            targets = []; targetIndex = 0; hoveredWindow = nil
            updateTargetLabel(); return
        }
        targets = windowMode ? [CaptureTarget(rect: candidate.rect, label: L("창"))] : detector.cached(at: p, window: candidate, bounds: bounds)
        targetIndex = 0
        hoveredWindow = targets.first?.rect
        updateTargetLabel()
        if !windowMode && CaptureTargetDetector.canReadElements {
            detector.detect(at: p, screen: surface.screen, window: candidate) { [weak self] targets in
                guard let self, self.interactionActive, !self.selection.isValid else { return }
                if self.dragging && self.pendingTarget == nil { return }
                self.targets = targets; self.targetIndex = 0
                self.hoveredWindow = targets.first?.rect
                if self.dragging { self.pendingTarget = targets.first?.rect }
                self.updateTargetLabel()
            }
        }
    }
    private func updateTargetLabel() {
        let target = targets.indices.contains(targetIndex) ? targets[targetIndex] : nil
        setAccessibilityValue(target.map { L("자동 선택: {0}, {1} × {2} pt", $0.label, Int($0.rect.width), Int($0.rect.height)) } ?? L("직접 영역 선택"))
        subviews.forEach { $0.needsDisplay = true }
    }
    func selectAll() { selection.rect = bounds; changed() }
    func restoreRegion(_ global: NSRect) {
        let local = global.intersection(surface.screen.frame).offsetBy(dx: -surface.screen.frame.minX, dy: -surface.screen.frame.minY)
        if local.width >= 2 && local.height >= 2 { selection.rect = local; changed() }
    }
    private func changed() {
        window?.invalidateCursorRects(for: self)
        let pixel = selection.pixelRect(imageSize: canvas.image.size)
        bar.info.stringValue = "\(Int(pixel.width)) × \(Int(pixel.height)) px"
        bar.isHidden = !selection.isValid
        positionBar()
        subviews.forEach { $0.needsDisplay = true }
    }
    private var manualBarOrigin: NSPoint?
    private func positionBar() {
        let size = bar.preferredSize
        var origin = NSPoint(x: selection.rect.maxX - size.width, y: selection.rect.minY - size.height - 8)
        if origin.y < 8 { origin.y = min(bounds.maxY - size.height - 8, selection.rect.maxY + 8) }
        origin.x = min(bounds.maxX - size.width - 8, max(8, origin.x))
        let screen = surface.screen
        let safe = screen.visibleFrame.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY).intersection(bounds)
        origin = AnnotationBar.constrainedOrigin(manualBarOrigin ?? origin, size: size, within: safe)
        if manualBarOrigin != nil { manualBarOrigin = origin }
        bar.frame = NSRect(origin: origin, size: size)
    }
    private func finish(_ destination: CaptureDestination) {
        guard selection.isValid else { return }
        canvas.flushText()
        let image = canvas.document.cropped(to: selection.pixelRect(imageSize: canvas.image.size))
        let frame = selection.rect.offsetBy(dx: surface.screen.frame.minX, dy: surface.screen.frame.minY)
        onFinish?(image, destination, frame, CaptureHistoryContext(image: canvas.document.rendered(), selection: selection.pixelRect(imageSize: canvas.image.size)))
    }
    @objc func copy(_ sender: Any?) { finish(.copy) }
    func shortcut(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }
        if let editor = window?.firstResponder as? NSTextView, editor.isFieldEditor { return false }
        let command = event.modifierFlags.contains(.command)
        // Text editing keeps standard Copy/Paste/Undo; only Cmd-Return completes a text capture.
        if canvas.activeTextInput != nil && !(command && [36,76].contains(Int(event.keyCode))) { return false }
        if canvas.handleSelectionKey(event) { return true }
        if let action = ImageKeyboardCommand.resolve(keyCode: event.keyCode, flags: event.modifierFlags) {
            switch action {
            case .copy: guard selection.isValid else { return false }; finish(.copy)
            case .save: guard selection.isValid else { return false }; finish(.save)
            case .pin: guard selection.isValid else { return false }; finish(.pin)
            case .undo: canvas.undoEdit()
            case .redo: canvas.redoEdit()
            }
            return true
        }
        guard !command else { return false }
        switch event.keyCode {
        case 43: browseHistory(older: true)
        case 47: browseHistory(older: false)
        case 53: onCancel?()
        case 36,76: return true // Enter confirms text input only; never dismiss an active capture.
        case 48:
            guard !selection.isValid, !targets.isEmpty else { return false }
            let step = event.modifierFlags.contains(.shift) ? -1 : 1
            targetIndex = (targetIndex + step + targets.count) % targets.count
            hoveredWindow = targets[targetIndex].rect
            updateTargetLabel()
        case 49:
            guard !selection.isValid else { return true }
            windowMode.toggle(); lastProbe = nil
            if let window { updateTarget(at: convert(window.mouseLocationOutsideOfEventStream, from: nil), force: true) }
            changed()
        case 35: finish(.pin)
        case 123,124,125,126:
            let step: CGFloat = event.modifierFlags.contains(.option) ? 10 : 1 / surface.screen.backingScaleFactor
            selection.nudge(dx: event.keyCode == 123 ? -step : event.keyCode == 124 ? step : 0,
                dy: event.keyCode == 125 ? -step : event.keyCode == 126 ? step : 0,
                resize: event.modifierFlags.contains(.shift))
            changed()
        default: return false
        }
        return true
    }
    override func keyDown(with event: NSEvent) { if !shortcut(event) { super.keyDown(with: event) } }
    override func performKeyEquivalent(with event: NSEvent) -> Bool { shortcut(event) }

    func drawShade() {
        let hole = selection.isValid ? selection.rect : hoveredWindow
        let shade = NSBezierPath(rect: bounds)
        if let hole { shade.appendRect(hole) }
        shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.45).setFill()
        shade.fill()
        guard let hole else {
            (L("드래그 영역 선택  ·  , 이전 기록 / . 다음  ·  클릭 자동 선택  ·  Tab 상위 요소  ·  Space 창 선택  ·  Esc 취소") as NSString).draw(at: NSPoint(x: 36, y: bounds.maxY - 70), withAttributes: [
                .font: NSFont.systemFont(ofSize: 16, weight: .medium), .foregroundColor: NSColor.white])
            return
        }
        NSColor.systemMint.setStroke()
        let border = NSBezierPath(rect: hole)
        border.lineWidth = 1.5
        border.stroke()
        if !selection.isValid, targets.indices.contains(targetIndex) {
            let label = L("{0} · 클릭 선택 / 드래그 직접 지정 · Tab 상위 요소 · Space 창 선택", targets[targetIndex].label)
            (label as NSString).draw(at: NSPoint(x: max(8, hole.minX + 8), y: min(bounds.maxY - 24, hole.maxY + 8)), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.white, .backgroundColor: NSColor.black.withAlphaComponent(0.85)])
        }
        if selection.isValid {
            for handle in CaptureSelection.Handle.allCases {
                let p = selection.point(for: handle)
                let box = NSRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)
                NSColor.white.setFill(); box.fill()
                NSColor.systemMint.setStroke(); NSBezierPath(rect: box).stroke()
            }
            let pixels = selection.pixelRect(imageSize: canvas.image.size)
            let text = L("{0} × {1} px  ·  방향키 이동 / Shift+방향키 크기", Int(pixels.width), Int(pixels.height))
            let labelPoint = NSPoint(x: hole.minX + 8, y: min(bounds.maxY - 24, hole.maxY + 9))
            (text as NSString).draw(at: labelPoint, withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.white, .backgroundColor: NSColor.black.withAlphaComponent(0.8)])
        }
    }
}

private final class CaptureShade: NSView {
    weak var owner: CaptureView?
    override func draw(_ dirtyRect: NSRect) { owner?.drawShade() }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
