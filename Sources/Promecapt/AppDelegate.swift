import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSMenuItemValidation {
    private let updates = AppUpdates()
    private var item: NSStatusItem!
    private let menu = NSMenu()
    private var library: Library!
    private var pins: [PinController] = []
    private var deferredPinRecords: [PinRecord] = []
    private var editors: [EditorController] = []
    private var hotkeys: Hotkeys!
    private var captureProcess: Process?
    private var capturePending = false
    private var captureRequest: UUID?
    private var persistTask: DispatchWorkItem?
    private var preferences: PreferencesController?
    private var captureSession: CaptureSession?
    private var gifRecorder: GIFRecorder?
    private var gifResults: [GIFResultController] = []
    private var hidden = false
    private var terminating = false
    private var permissionSetup: PermissionSetupController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if InstallLocation.offerInstallation() { return }
        UserDefaults.standard.register(defaults: ["autoSelectAnnotations": true, "restorePins": false, "historyLimit": 50, "hotkeyProfile": 1, "captureDelay": 0, "autoCopy": true, "showDock": true, "showDashboard": true, "pinShadow": true])
        do {
            #if DEBUG
            if Bundle.main.bundleIdentifier == "com.promlee.promecapt.update-test" {
                library = try Library(root: Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("TestLibrary"))
            } else { library = try Library() }
            #else
            library = try Library()
            #endif
        }
        catch { showError(L("보관함을 열지 못했습니다: {0}", error.localizedDescription)); NSApp.terminate(nil); return }
        menu.delegate = self
        configureStatusItem()
        NotificationCenter.default.addObserver(self, selector: #selector(keepStatusIconVisible), name: NSApplication.didBecomeActiveNotification, object: NSApp)
        NotificationCenter.default.addObserver(self, selector: #selector(keepStatusIconVisible), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSApp.setActivationPolicy(UserDefaults.standard.bool(forKey: "showDock") ? .regular : .accessory)
        installMainMenu()
        hotkeys = Hotkeys()
        hotkeys.action = { [weak self] id in self?.executeHotkey(id) }
        registerHotkeys()
        if UserDefaults.standard.bool(forKey: "restorePins") {
            do {
                for (record, image) in try library.restorePins() {
                    let pin = createPin(image, id: record.id)
                    if let gif = library.gifData(for: record) { pin.setGIF(gif) }
                    else if let document = library.annotationDocument(for: record) { pin.setDocument(document) }
                    var frame = NSRect(x: record.x, y: record.y, width: max(32, record.width), height: max(32, record.height))
                    if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
                        frame.origin = NSScreen.main?.visibleFrame.origin ?? .zero
                    }
                    pin.window?.setFrame(frame, display: true)
                    pin.window?.alphaValue = min(1, max(0.15, record.opacity))
                    pin.group = record.group
                }
            } catch { showError(L("고정 이미지 복원 실패: {0}", error.localizedDescription)) }
        }
        if !UserDefaults.standard.bool(forKey: "restorePins") {
            do { deferredPinRecords = try library.pinRecords() }
            catch { showError(L("고정 이미지 복원 실패: {0}", error.localizedDescription)) }
        }
        rebuildMenu()
        updates.isBusy = { [weak self] in
            guard let self else { return true }
            return self.capturePending || self.captureSession != nil || self.gifRecorder != nil
                || self.editors.contains { $0.window?.isVisible == true }
                || self.gifResults.contains { $0.window?.isVisible == true }
                || self.pins.contains { $0.isEditingAnnotations }
                || OCRResultController.hasOpenResults
                || NSApp.windows.contains { $0.isVisible && $0 is AnnotationTextPanel }
        }
        updates.saveBeforeInstall = { [weak self] in
            guard let self else { return }
            self.persistTask?.cancel()
            try self.library.savePins(self.pins, keeping: self.deferredPinRecords)
        }
        updates.start()
        let setup = PermissionSetupController()
        setup.onChange = { [weak self] in
            guard !ShortcutRecorder.isRecordingShortcut else { return }
            self?.registerHotkeys()
        }
        permissionSetup = setup
        DispatchQueue.main.async { [weak self] in self?.permissionSetup?.showIfNeeded() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard library != nil else { return false }
        keepStatusIconVisible()
        if !flag && !capturePending && captureSession == nil && gifRecorder == nil { showSettings() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func executeHotkey(_ id: UInt32) {
        switch id {
        case 1: capture()
        case 2: pastePin()
        case 3: togglePins()
        case 4: showSettings()
        default: break
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if let image = NSImage(contentsOf: url) { edit(Imaging.normalized(image)) }
        }
    }

    private func installMainMenu() {
        let root = NSMenu()
        let appItem = root.addItem(withTitle: "Promecapt", action: nil, keyEquivalent: "")
        let appMenu = NSMenu(title: "Promecapt")
        appItem.submenu = appMenu
        add(L("정보"), #selector(showAbout), to: appMenu)
        if AppInfo.supportURL != nil {
            add(L("개발 후원…"), #selector(openSupportPage), to: appMenu)
        }
        add(L("업데이트 확인…"), #selector(checkForUpdates), to: appMenu)
        add(L("메뉴 막대 아이콘 복구"), #selector(restoreStatusIcon), to: appMenu)
        let settings = add(L("설정…"), #selector(showSettings), to: appMenu)
        settings.keyEquivalent = ","
        appMenu.addItem(.separator())
        let quit = add(L("Promecapt 종료"), #selector(quit), to: appMenu)
        quit.keyEquivalent = "q"
        let captureItem = root.addItem(withTitle: L("캡처"), action: nil, keyEquivalent: "")
        let captures = NSMenu(title: L("캡처"))
        captureItem.submenu = captures
        add(L("영역 캡처"), #selector(capture), to: captures)
        add(L("전체 화면 캡처"), #selector(captureFull), to: captures)
        add(L("클립보드 고정"), #selector(pastePin), to: captures)
        add(L("이미지 열기…"), #selector(openImage), to: captures)
        let editItem = root.addItem(withTitle: L("편집"), action: nil, keyEquivalent: "")
        let edits = NSMenu(title: L("편집"))
        editItem.submenu = edits
        for (title, selector, key) in [(L("잘라내기"), "cut:", "x"), (L("복사"), "copy:", "c"), (L("붙여넣기"), "paste:", "v"), (L("전체 선택"), "selectAll:", "a")] {
            edits.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key)
        }
        NSApp.mainMenu = root
    }

    @objc func showDashboard() {
        showSettings()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if gifRecorder != nil { gifRecorder?.stop(); return .terminateCancel }
        terminating = true
        captureSession?.close()
        captureProcess?.terminate()
        persistTask?.cancel()
        do { try library?.savePins(pins, keeping: deferredPinRecords) }
        catch { terminating = false; showError(L("고정 이미지 저장 실패: {0}", error.localizedDescription)); return .terminateCancel }
        return .terminateNow
    }

    func menuNeedsUpdate(_ menu: NSMenu) { if menu === self.menu { rebuildMenu() } }

    @discardableResult private func add(_ title: String, _ action: Selector, to targetMenu: NSMenu? = nil) -> NSMenuItem {
        let entry = (targetMenu ?? menu).addItem(withTitle: title, action: action, keyEquivalent: "")
        entry.target = self
        return entry
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? L("개발 버전")
        let title = menu.addItem(withTitle: "PROMECAPT  \(version)", action: nil, keyEquivalent: "")
        title.isEnabled = false
        add(L("영역 / 창 캡처…"), #selector(capture)).isEnabled = !capturePending
        add(L("GIF 영역 녹화…"), #selector(captureGIF)).isEnabled = gifRecorder == nil
        if gifRecorder != nil { add(L("GIF 녹화 정지"), #selector(stopGIF)) }
        add(L("주 화면 전체 캡처"), #selector(captureFull)).isEnabled = !capturePending
        add(L("클립보드 화면 고정"), #selector(pastePin))
        add(L("이미지 파일 열기…"), #selector(openImage))
        add(L("화면 색상 추출…"), #selector(sampleColor))
        menu.addItem(.separator())
        add(L("고정 이미지 모두 표시 / 숨기기 ({0})", pins.count), #selector(togglePins))
        add(L("클릭 통과 모두 해제"), #selector(recoverPins))
        let groups = NSMenu()
        for group in Set(pins.map(\.group)).sorted() {
            let entry = add(group.isEmpty ? L("미지정") : group, #selector(toggleGroup(_:)), to: groups)
            entry.representedObject = group
        }
        let groupItem = menu.addItem(withTitle: L("그룹 표시 / 숨기기"), action: nil, keyEquivalent: "")
        groupItem.submenu = groups
        let history = NSMenu()
        for entry in library.entries {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd HH:mm:ss"
            let item = add(formatter.string(from: entry.date), #selector(openHistory(_:)), to: history)
            item.representedObject = entry.id.uuidString
            if let image = library.image(entry) {
                let thumb = NSImage(size: NSSize(width: 56, height: 36))
                thumb.lockFocus()
                image.draw(in: NSRect(x: 0, y: 0, width: 56, height: 36), from: .zero, operation: .sourceOver, fraction: 1)
                thumb.unlockFocus()
                item.image = thumb
            }
        }
        if library.entries.isEmpty { history.addItem(withTitle: L("아직 캡처한 이미지가 없습니다"), action: nil, keyEquivalent: "") }
        history.addItem(.separator())
        add(L("캡처 기록 지우기…"), #selector(clearHistory), to: history)
        let historyItem = menu.addItem(withTitle: L("캡처 기록 ({0})", library.entries.count), action: nil, keyEquivalent: "")
        historyItem.submenu = history
        menu.addItem(.separator())
        add(L("설정…"), #selector(showSettings))
        add(L("사용 방법…"), #selector(showWelcome))
        add(L("업데이트 확인…"), #selector(checkForUpdates)).isEnabled = updates.canCheck
        add(L("정보"), #selector(showAbout))
        if AppInfo.supportURL != nil {
            add(L("개발 후원…"), #selector(openSupportPage))
        }
        add(L("권한 설정…"), #selector(showPermissions))
        add(L("종료"), #selector(quit))
    }

    private func captureScreen(full: Bool, recording: Bool = false) {
        guard !capturePending, captureSession == nil, gifRecorder == nil else { return }
        // On modern macOS, ScreenCaptureKit is the authority. The legacy CG preflight can
        // report false for a replaced development build even while Settings shows it enabled.
        if #unavailable(macOS 14.0) {
            guard CGPreflightScreenCaptureAccess() else {
                _ = CGRequestScreenCaptureAccess()
                showError(L("시스템 설정 → 개인정보 보호 및 보안 → 화면 녹화에서 Promecapt를 허용해 주세요."))
                return
            }
        }
        capturePending = true
        let request = UUID()
        captureRequest = request
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            guard let self, self.capturePending, self.captureRequest == request else { return }
            self.capturePending = false
            self.captureRequest = nil
            showError(L("화면 캡처 요청이 응답하지 않았습니다. 다시 캡처를 시작해 주세요."))
            self.showDashboard()
        }
        preferences?.window?.orderOut(nil)
        let delay = Double(UserDefaults.standard.integer(forKey: "captureDelay")) + 0.2
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.terminating else { return }
            ScreenSnapshots.capture { [weak self] result in
                guard let self, !self.terminating, self.captureRequest == request else { return }
                self.capturePending = false
                self.captureRequest = nil
                switch result {
                case .failure(let error):
                    showError(L("화면 캡처 실패: {0}", error.localizedDescription))
                    self.showDashboard()
                case .success(let surfaces):
                    guard !surfaces.isEmpty else { self.showDashboard(); return }
                    let session = CaptureSession()
                    let entries = self.library.entries
                    session.historyCount = entries.count
                    session.historyImage = { [weak self] index in
                        guard entries.indices.contains(index) else { return nil }
                        return self?.library.historyItem(entries[index])
                    }
                    session.recordingSelection = recording
                    session.onFinish = { [weak self] document, destination, frame, context in
                        guard let self else { return }
                        self.captureSession = nil
                        if destination == .gif { self.recordGIF(frame); return }
                        let image = document.rendered()
                        UserDefaults.standard.set(NSStringFromRect(frame), forKey: "lastCaptureRect")
                        do { try self.library.add(image, context: context) }
                        catch { showError(L("캡처 기록 저장 실패: {0}", error.localizedDescription)) }
                        if UserDefaults.standard.bool(forKey: "autoCopy") { copyImage(image) }
                        switch destination {
                        case .copy: copyImage(image)
                        case .pin:
                            let pin = self.createPin(image)
                            pin.setDocument(document)
                            pin.window?.setFrame(frame, display: true)
                            pin.window?.makeKeyAndOrderFront(nil)
                            self.schedulePersistence()
                        case .save: saveImage(image)
                        case .gif: break
                        }
                    }
                    session.onCancel = { [weak self] in self?.captureSession = nil }
                    self.captureSession = session
                    session.start(surfaces, full: full)
                }
            }
        }
    }

    @objc func capture() { captureScreen(full: false) }
    @objc private func captureFull() { captureScreen(full: true) }

    @objc private func captureGIF() { captureScreen(full: false, recording: true) }
    @objc private func stopGIF() { gifRecorder?.stop() }
    private func recordGIF(_ frame: NSRect) {
        let recorder = GIFRecorder(); gifRecorder = recorder
        recorder.onComplete = { [weak self, weak recorder] result in
            guard let self, let recorder else { return }
            self.gifRecorder = nil
            switch result {
            case .failure(let error): showError(L("GIF 녹화 실패: {0}", error.localizedDescription))
            case .success(let file):
                do {
                    let result = try GIFResultController(data: Data(contentsOf: file))
                    result.onPin = { [weak self] data, image in self?.createPin(image).setGIF(data) }
                    result.onClose = { [weak self] closing in self?.gifResults.removeAll { $0 === closing } }
                    self.gifResults.append(result)
                    result.show()
                } catch { showError(L("GIF 결과를 열지 못했습니다: {0}", error.localizedDescription)) }
                recorder.removeTemporaryFiles()
            }
        }
        recorder.start(rect: frame)
    }

    @objc func pastePin() {
        let pasteboard = NSPasteboard.general
        if let data = pasteboard.data(forType: NSPasteboard.PasteboardType("com.compuserve.gif")), let image = GIFMedia.poster(data) {
            createPin(image).setGIF(data); return
        }
        if let image = NSImage(pasteboard: pasteboard) { _ = createPin(Imaging.normalized(image)); return }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urls.first, url.isFileURL, let image = NSImage(contentsOf: url) {
            _ = createPin(Imaging.normalized(image)); return
        }
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            _ = createPin(Imaging.parseColor(text).map(Imaging.colorImage) ?? Imaging.textImage(String(text.prefix(8000))))
            return
        }
        showError(L("클립보드에 이미지 또는 텍스트를 복사한 후 다시 시도해 주세요."))
    }

    @discardableResult private func createPin(_ image: NSImage, id: UUID = UUID()) -> PinController {
        let pin = PinController(image: image, id: id)
        pin.onChange = { [weak self] in self?.schedulePersistence() }
        pin.onClose = { [weak self] closing in
            self?.pins.removeAll { $0 === closing }
            self?.schedulePersistence()
        }
        pin.onEdit = { [weak self] image in self?.edit(image) }
        pin.onDrop = { [weak self] image in self?.createPin(image) }
        pins.append(pin)
        pin.show()
        hidden = false
        schedulePersistence()
        return pin
    }

    private func edit(_ image: NSImage) {
        let editor = EditorController(image: image)
        editor.onPin = { [weak self] document in
            self?.createPin(document.rendered()).setDocument(document)
        }
        editor.onClose = { [weak self] closing in self?.editors.removeAll { $0 === closing } }
        editors.append(editor)
        editor.show()
    }

    private func schedulePersistence() {
        persistTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            do { try self.library.savePins(self.pins, keeping: self.deferredPinRecords) }
            catch { showError(L("고정 이미지 저장 실패: {0}", error.localizedDescription)) }
        }
        persistTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: task)
    }

    @objc func togglePins() {
        hidden.toggle()
        for pin in pins { if hidden { pin.window?.orderOut(nil) } else { pin.show() } }
    }
    @objc private func toggleGroup(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? String else { return }
        let selected = pins.filter { $0.group == group }
        let visible = selected.contains { $0.window?.isVisible == true }
        for pin in selected { if visible { pin.window?.orderOut(nil) } else { pin.show() } }
    }
    @objc private func recoverPins() {
        for pin in pins { pin.window?.ignoresMouseEvents = false; pin.window?.alphaValue = 1; pin.show() }
        hidden = false
        schedulePersistence()
    }
    @objc func openImage() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let image = NSImage(contentsOf: url) { edit(Imaging.normalized(image)) }
            }
        }
    }
    @objc private func sampleColor() {
        NSColorSampler().show { [weak self] color in
            guard let color else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(Imaging.hex(color), forType: .string)
            _ = self?.createPin(Imaging.colorImage(color))
        }
    }
    @objc private func openHistory(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let entry = library.entries.first(where: { $0.id.uuidString == id }), let image = library.image(entry) else { return }
        edit(image)
    }
    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = L("캡처 기록을 모두 지울까요?")
        alert.informativeText = L("저장된 원본 캡처가 삭제됩니다. 고정 이미지는 별도로 보관됩니다.")
        alert.addButton(withTitle: L("취소"))
        alert.addButton(withTitle: L("모두 지우기"))
        if alert.runModal() == .alertSecondButtonReturn {
            do { try library.clearHistory() } catch { showError(error.localizedDescription) }
        }
    }

    @objc private func showWelcome() {
        NSWorkspace.shared.open(URL(string: "https://github.com/PROMLEE/promecapt/blob/main/docs/USAGE.md")!)
    }

    @objc private func openSupportPage() {
        if let url = AppInfo.supportURL { NSWorkspace.shared.open(url) }
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool { item.action == #selector(checkForUpdates) ? updates.canCheck : true }
    @objc private func checkForUpdates() { updates.check() }
    @objc private func showPermissions() { permissionSetup?.show() }
    @objc private func showAbout() { showSettings(); preferences?.showAbout() }

    @objc func showSettings() {
        if preferences == nil {
            let controller = PreferencesController(updates: updates)
            controller.onShowPermissions = { [weak self] in self?.showPermissions() }
            controller.onLanguageChange = { [weak self] in
                guard let self else { return }
                self.preferences?.close(); self.preferences = nil
                self.installMainMenu(); self.rebuildMenu(); self.configureStatusItem()
                for pin in self.pins { pin.window?.title = pin.gifData == nil ? L("Promecapt — 고정 이미지") : L("Promecapt — 고정 GIF") }
                self.showSettings()
            }
            controller.onSetProfile = { [weak self] profile in
                guard let self else { return nil }
                let previous = ShortcutPreferences.bindings()
                if profile == 3 && UserDefaults.standard.data(forKey: ShortcutPreferences.customKey) == nil {
                    ShortcutPreferences.saveCustom(previous)
                    return nil
                }
                if let error = self.hotkeys.register(ShortcutPreferences.bindings(profile: profile)) {
                    _ = self.hotkeys.register(previous)
                    return error
                }
                UserDefaults.standard.set(profile, forKey: "hotkeyProfile")
                return nil
            }
            controller.onSetShortcut = { [weak self] action, shortcut in
                guard let self else { return nil }
                let previous = ShortcutPreferences.bindings()
                var candidate = previous
                candidate[action] = shortcut
                if let error = self.hotkeys.register(candidate) {
                    _ = self.hotkeys.register(previous)
                    return error
                }
                ShortcutPreferences.saveCustom(candidate)
                return nil
            }
            controller.onRecording = { [weak self] recording in
                if recording { self?.hotkeys.unregisterAll() }
                else { _ = self?.hotkeys.register(ShortcutPreferences.bindings()) }
            }
            controller.onRestoreIcon = { [weak self] in self?.restoreStatusIcon() }
            controller.onSetDockVisibility = { [weak self] enabled in
                NSApp.setActivationPolicy(enabled ? .regular : .accessory)
                self?.keepStatusIconVisible()
                DispatchQueue.main.async { [weak self] in self?.keepStatusIconVisible() }
            }
            controller.onClearHistory = { [weak self] in self?.clearHistory() }
            controller.onOpenLibrary = { [weak self] in self?.openLibrary() }
            preferences = controller
        }
        preferences?.show()
    }
    private func registerHotkeys() {
        if let error = hotkeys.register(ShortcutPreferences.bindings()) { showError(error) }
    }
    private func configureStatusItem(forcePosition: Bool = false) {
        let name = "PromepasteStatusItemV4"
        if forcePosition || !UserDefaults.standard.bool(forKey: "statusPlacementV4") {
            // AppKit restores the status item's saved distance from the right edge.
            // Migrate once; subsequent launches preserve the user's own ordering.
            UserDefaults.standard.set(0.0, forKey: "NSStatusItem Preferred Position " + name)
            UserDefaults.standard.set(true, forKey: "statusPlacementV4")
        }
        UserDefaults.standard.set(true, forKey: "NSStatusItem Visible " + name)
        // Keep one status item for the application's lifetime. Removing and replacing
        // a live item can strand it outside the visible menu bar after a settings action.
        if item == nil {
            item = NSStatusBar.system.statusItem(withLength: 28)
            item.autosaveName = name
        }
        item.length = 28
        item.behavior = []
        item.isVisible = true
        item.button?.image = StatusIcon.make()
        item.button?.imagePosition = .imageOnly
        item.button?.title = ""
        item.button?.setAccessibilityLabel(L("Promecapt 메뉴"))
        item.button?.toolTip = L("Promecapt — 캡처·고정·설정")
        item.menu = menu
    }
    @objc private func keepStatusIconVisible() {
        guard let item else { configureStatusItem(forcePosition: true); return }
        item.isVisible = true
    }
    @objc private func restoreStatusIcon() { configureStatusItem(forcePosition: true) }
    @objc private func openLibrary() { NSWorkspace.shared.open(library.root) }
    @objc private func quit() { NSApp.terminate(nil) }
}
