import AppKit
import ApplicationServices
import ScreenCaptureKit

final class PermissionSetupController: NSWindowController, NSWindowDelegate {
    static let changed = Notification.Name("PromecaptPermissionsChanged")
    var onChange: (() -> Void)?
    private var screenAllowed = CGPreflightScreenCaptureAccess()
    private var accessibilityAllowed = AXIsProcessTrusted()
    private var requestingScreen = false
    private let screenStatus = NSTextField(labelWithString: "")
    private let accessibilityStatus = NSTextField(labelWithString: "")
    private var screenButton: NSButton!
    private var accessibilityButton: NSButton!
    private var doneButton: NSButton!
    private var timer: Timer?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 350), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = L("Promecapt 권한 설정")
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        let stack = NSStackView()
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24), stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24)])
        let title = NSTextField(labelWithString: L("캡처를 시작하기 전에 권한을 허용하세요"))
        title.font = .boldSystemFont(ofSize: 18); stack.addArrangedSubview(title)
        let intro = NSTextField(wrappingLabelWithString: L("아래 버튼을 눌러 macOS에서 Promecapt를 허용하세요. 권한 상태는 자동으로 갱신됩니다."))
        intro.preferredMaxLayoutWidth = 532
        intro.widthAnchor.constraint(equalToConstant: 532).isActive = true
        stack.addArrangedSubview(intro)
        screenButton = NSButton(title: L("화면 캡처 허용…"), target: self, action: #selector(requestScreen))
        accessibilityButton = NSButton(title: L("손쉬운 사용 허용…"), target: self, action: #selector(requestAccessibility))
        for (label, button) in [(screenStatus, screenButton!), (accessibilityStatus, accessibilityButton!)] {
            label.widthAnchor.constraint(equalToConstant: 300).isActive = true
            let row = NSStackView(views: [label, button]); row.spacing = 12; stack.addArrangedSubview(row)
        }
        let help = NSTextField(wrappingLabelWithString: L("손쉬운 사용은 앱의 버튼·입력칸 감지와 전역 단축키에 사용합니다. 설정 목록에서 Promecapt 스위치를 켜 주세요. 앱이 목록에 없거나 이전 빌드 권한이 남아 있으면 아래 ‘앱 위치 열기’로 설치된 앱을 찾을 수 있습니다."))
        help.preferredMaxLayoutWidth = 532
        help.widthAnchor.constraint(equalToConstant: 532).isActive = true
        stack.addArrangedSubview(help)
        let reveal = NSButton(title: L("앱 위치 열기"), target: self, action: #selector(revealApp))
        let later = NSButton(title: L("나중에"), target: self, action: #selector(dismiss))
        doneButton = NSButton(title: L("완료"), target: self, action: #selector(dismiss))
        stack.addArrangedSubview(NSStackView(views: [reveal, later, doneButton]))
        window.center()
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }
    var needsSetup: Bool { !screenAllowed || !accessibilityAllowed }
    func showIfNeeded() { refresh(); if needsSetup { show() } }
    func show() {
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
    }
    private func refresh() {
        let previous = (screenAllowed, accessibilityAllowed)
        screenAllowed = screenAllowed || CGPreflightScreenCaptureAccess()
        accessibilityAllowed = AXIsProcessTrusted()
        screenStatus.stringValue = L("화면 캡처: {0}", screenAllowed ? L("허용됨") : L("허용 필요"))
        accessibilityStatus.stringValue = L("손쉬운 사용 권한: {0}", accessibilityAllowed ? L("허용됨") : L("허용 필요"))
        screenButton.isEnabled = !screenAllowed && !requestingScreen
        accessibilityButton.isEnabled = !accessibilityAllowed
        doneButton.isEnabled = !needsSetup
        if previous.0 != screenAllowed || previous.1 != accessibilityAllowed {
            onChange?()
            NotificationCenter.default.post(name: Self.changed, object: self)
        }
    }
    @objc private func requestScreen() {
        guard !requestingScreen else { return }
        requestingScreen = true; refresh()
        if #available(macOS 14.0, *) {
            // Ask ScreenCaptureKit directly; it is authoritative for current capture builds.
            SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { [weak self] content, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.requestingScreen = false
                    if content != nil { self.screenAllowed = true }
                    else { Self.openSettings("Privacy_ScreenCapture") }
                    self.refresh()
                    NotificationCenter.default.post(name: Self.changed, object: self)
                }
            }
        } else {
            screenAllowed = CGRequestScreenCaptureAccess()
            requestingScreen = false
            if !screenAllowed { Self.openSettings("Privacy_ScreenCapture") }
            refresh()
        }
    }
    @objc private func requestAccessibility() {
        // The AX prompt registers this running app; users normally only need to turn its switch on.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        Self.openSettings("Privacy_Accessibility")
        refresh()
    }
    private static func openSettings(_ pane: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?" + pane)!)
    }
    @objc private func revealApp() { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
    @objc private func dismiss() { close() }
    func windowWillClose(_ notification: Notification) { timer?.invalidate(); timer = nil }
    deinit { timer?.invalidate() }
}
