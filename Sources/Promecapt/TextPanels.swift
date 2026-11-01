import AppKit

final class AnnotationTextPanel: NSPanel, NSWindowDelegate {
    var onApply: (() -> Void)?
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    init(field: NSTextField) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 400, height: 88), styleMask: [.titled,.closable], backing: .buffered, defer: false)
        title = L("Promecapt · 텍스트 입력")
        isReleasedWhenClosed = false; hidesOnDeactivate = false; delegate = self
        field.frame = NSRect(x: 14, y: 49, width: 372, height: 25)
        contentView?.addSubview(field)
        let cancel = NSButton(title: L("취소"), target: self, action: #selector(cancelText))
        cancel.frame = NSRect(x: 226, y: 10, width: 76, height: 28)
        cancel.bezelStyle = .rounded; cancel.toolTip = L("입력 취소 (Esc)")
        let apply = NSButton(title: L("확인"), target: self, action: #selector(applyText))
        apply.frame = NSRect(x: 306, y: 10, width: 80, height: 28)
        apply.bezelStyle = .rounded; apply.toolTip = L("텍스트 주석 적용 (Enter)")
        contentView?.addSubview(cancel); contentView?.addSubview(apply)
    }
    @objc private func applyText() { onApply?() }
    @objc private func cancelText() { onCancel?() }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
    func windowWillClose(_ notification: Notification) { onCancel?() }
}

final class OCRResultController: NSWindowController, NSWindowDelegate {
    static var hasOpenResults: Bool { !openControllers.isEmpty }
    private static var openControllers: [ObjectIdentifier: OCRResultController] = [:]
    private let output = NSTextView()
    private let status = NSTextField(labelWithString: L("텍스트 인식 중…"))
    private let copyButton = NSButton(title: L("전체 복사"), target: nil, action: nil)

    static func present(_ image: NSImage, parent: NSWindow?) {
        let controller = OCRResultController(parent: parent)
        openControllers[ObjectIdentifier(controller)] = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true); controller.window?.makeKeyAndOrderFront(nil)
        Imaging.recognize(image) { [weak controller] result in controller?.complete(result) }
    }
    init(parent: NSWindow?) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 570, height: 380),
                              styleMask: [.titled,.closable,.resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = L("Promecapt · 텍스트 추출 (OCR)")
        window.isReleasedWhenClosed = false; window.delegate = self
        window.minSize = NSSize(width: 420, height: 260)
        window.level = NSWindow.Level(rawValue: max(parent?.level.rawValue ?? 0, NSWindow.Level.floating.rawValue) + 1)
        if let visible = parent?.screen?.visibleFrame { window.setFrameOrigin(NSPoint(x: visible.midX - 285, y: visible.midY - 190)) }
        else { window.center() }
        let root = window.contentView!
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        output.isEditable = true; output.isRichText = false; output.font = .systemFont(ofSize: 15)
        output.isVerticallyResizable = true; output.autoresizingMask = [.width]
        output.textContainer?.widthTracksTextView = true
        output.setAccessibilityLabel(L("OCR 인식 결과"))
        scroll.documentView = output
        copyButton.target = self; copyButton.action = #selector(copyText)
        copyButton.bezelStyle = .rounded; copyButton.isEnabled = false
        copyButton.toolTip = L("인식 결과 전체를 텍스트로 복사")
        let close = NSButton(title: L("닫기"), target: self, action: #selector(closeResult))
        close.bezelStyle = .rounded; close.toolTip = L("OCR 결과 창 닫기")
        for view in [scroll,status,copyButton,close] { view.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(view) }
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14), scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            scroll.topAnchor.constraint(equalTo: root.topAnchor, constant: 14), scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -54),
            status.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14), status.centerYAnchor.constraint(equalTo: copyButton.centerYAnchor),
            status.trailingAnchor.constraint(lessThanOrEqualTo: copyButton.leadingAnchor, constant: -10),
            close.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14), close.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            copyButton.trailingAnchor.constraint(equalTo: close.leadingAnchor, constant: -8), copyButton.bottomAnchor.constraint(equalTo: close.bottomAnchor)
        ])
        output.frame = NSRect(x: 0, y: 0, width: 540, height: 310)
    }
    required init?(coder: NSCoder) { fatalError() }
    private func complete(_ result: Result<String, Error>) {
        switch result {
        case .success(let text):
            output.string = text; copyButton.isEnabled = !text.isEmpty
            status.stringValue = text.isEmpty ? L("인식할 수 있는 텍스트가 없습니다.") : L("한국어·영어 인식 완료 · 수정 후 복사 가능")
        case .failure(let error): status.stringValue = L("인식 실패: {0}", error.localizedDescription)
        }
    }
    @objc private func copyText() { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(output.string, forType: .string) }
    @objc private func closeResult() { close() }
    func windowWillClose(_ notification: Notification) { Self.openControllers.removeValue(forKey: ObjectIdentifier(self)) }
}
