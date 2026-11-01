import AppKit

final class ShortcutRecorder: NSButton {
    static private(set) var isRecordingShortcut = false
    static private(set) weak var activeRecorder: ShortcutRecorder?
    var shortcut: Shortcut? { didSet { if !recording { updateTitle() } } }
    var onRecord: ((Shortcut?) -> String?)?
    var onRecording: ((Bool) -> Void)?
    var onError: ((String?) -> Void)?
    private(set) var recording = false
    override var acceptsFirstResponder: Bool { true }
    init(action: HotkeyAction) {
        super.init(frame: .zero)
        bezelStyle = .rounded
        title = L("직접 지정…")
        target = self; self.action = #selector(beginRecording)
        setAccessibilityLabel(L("{0} 단축키 기록", action.title))
        widthAnchor.constraint(equalToConstant: 210).isActive = true
        updateTitle()
        NotificationCenter.default.addObserver(self, selector: #selector(focusLost(_:)), name: NSWindow.didResignKeyNotification, object: nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    @objc private func focusLost(_ notification: Notification) {
        if recording, let source = notification.object as? NSWindow, source === window { endRecording() }
    }
    required init?(coder: NSCoder) { fatalError() }
    private func updateTitle() { title = shortcut?.display ?? L("직접 지정…") }
    @objc private func beginRecording() {
        Self.activeRecorder?.endRecording()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)
        recording = true
        Self.activeRecorder = self
        Self.isRecordingShortcut = true
        title = L("키 조합을 누르세요…")
        onError?(nil)
        onRecording?(true)
    }
    private func endRecording() {
        recording = false
        if Self.activeRecorder === self {
            Self.activeRecorder = nil
            Self.isRecordingShortcut = false
        }
        updateTitle()
        onRecording?(false)
    }
    override func resignFirstResponder() -> Bool {
        if recording { endRecording() }
        return super.resignFirstResponder()
    }
    func record(_ event: NSEvent) -> Bool {
        guard recording, event.type == .keyDown else { return false }
        if event.keyCode == 53 { endRecording(); return true }
        let flags = event.modifierFlags.intersection(Shortcut.allowedModifiers)
        if [UInt16(51), UInt16(117)].contains(event.keyCode), flags.isEmpty {
            let error = onRecord?(nil)
            onError?(error)
            if error == nil { shortcut = nil }
            endRecording(); return true
        }
        let binding = Shortcut(keyCode: event.keyCode, flags: flags)
        guard binding.isValid else { onError?(L("⌘C·⌘V 등 표준 편집 키를 제외하고, ⌘·⌥·⌃ 조합 또는 F1–F20을 누르세요.")); return true }
        let error = onRecord?(binding)
        onError?(error)
        if error == nil { shortcut = binding }
        endRecording()
        return true
    }
    override func keyDown(with event: NSEvent) { if !record(event) { super.keyDown(with: event) } }
    override func performKeyEquivalent(with event: NSEvent) -> Bool { record(event) || super.performKeyEquivalent(with: event) }
}

enum ImageKeyboardCommand: Equatable {
    case copy, save, undo, redo, pin
    static func resolve(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Self? {
        guard flags.contains(.command), flags.intersection([.option,.control]).isEmpty else { return nil }
        switch keyCode {
        case 8: return .copy
        case 1: return .save
        case 6: return flags.contains(.shift) ? .redo : .undo
        case 36, 76: return .pin
        default: return nil
        }
    }
}
