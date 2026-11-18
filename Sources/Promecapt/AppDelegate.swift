import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSMenuItemValidation {
    let updates = AppUpdates()
    var item: NSStatusItem!
    let menu = NSMenu()
    var library: Library!
    var pins: [PinController] = []
    var deferredPinRecords: [PinRecord] = []
    var editors: [EditorController] = []
    private var hotkeys: Hotkeys!
    var capturePending = false
    var captureRequest: UUID?
    var persistTask: DispatchWorkItem?
    var preferences: PreferencesController?
    var captureSession: CaptureSession?
    var gifRecorder: GIFRecorder?
    var gifResults: [GIFResultController] = []
    var hidden = false
    var terminating = false
    private var permissionSetup: PermissionSetupController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if InstallLocation.offerInstallation() { return }
        UserDefaults.standard.register(defaults: [DefaultsKey.autoSelectAnnotations: true, DefaultsKey.restorePins: false, DefaultsKey.historyLimit: 50, DefaultsKey.hotkeyProfile: 1,
                DefaultsKey.captureDelay: 0, DefaultsKey.autoCopy: true, DefaultsKey.showDock: true, DefaultsKey.showDashboard: true, DefaultsKey.pinShadow: true])
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
        library.onWriteFailure = { error in showError(L("캡처 기록 저장 실패: {0}", error.localizedDescription)) }
        menu.delegate = self
        configureStatusItem()
        NotificationCenter.default.addObserver(self, selector: #selector(keepStatusIconVisible), name: NSApplication.didBecomeActiveNotification, object: NSApp)
        NotificationCenter.default.addObserver(self, selector: #selector(keepStatusIconVisible), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSApp.setActivationPolicy(UserDefaults.standard.bool(forKey: DefaultsKey.showDock) ? .regular : .accessory)
        installMainMenu()
        hotkeys = Hotkeys()
        hotkeys.action = { [weak self] id in self?.executeHotkey(id) }
        registerHotkeys()
        do {
            let records = try library.pinRecords()
            if UserDefaults.standard.bool(forKey: DefaultsKey.restorePins) { restore(records) }
            else { deferredPinRecords = records }
        } catch { showError(L("고정 이미지 복원 실패: {0}", error.localizedDescription)) }
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
            self.library.flush()
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

    @objc func showDashboard() {
        showSettings()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if gifRecorder != nil { gifRecorder?.stop(); return .terminateCancel }
        terminating = true
        captureSession?.close()
        persistTask?.cancel()
        do { try library?.savePins(pins, keeping: deferredPinRecords) }
        catch { terminating = false; showError(L("고정 이미지 저장 실패: {0}", error.localizedDescription)); return .terminateCancel }
        library?.flush()
        return .terminateNow
    }

    func menuNeedsUpdate(_ menu: NSMenu) { if menu === self.menu { rebuildMenu() } }

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
    @objc func sampleColor() {
        NSColorSampler().show { [weak self] color in
            guard let color else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(Imaging.hex(color), forType: .string)
            _ = self?.createPin(Imaging.colorImage(color), pixelScale: 1)
        }
    }
    @objc func openHistory(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let entry = library.entries.first(where: { $0.id.uuidString == id }), let image = library.image(entry) else { return }
        edit(image)
    }
    @objc func clearHistory() {
        let alert = NSAlert()
        alert.messageText = L("캡처 기록을 모두 지울까요?")
        alert.informativeText = L("저장된 원본 캡처가 삭제됩니다. 고정 이미지는 별도로 보관됩니다.")
        alert.addButton(withTitle: L("취소"))
        alert.addButton(withTitle: L("모두 지우기"))
        if alert.runModal() == .alertSecondButtonReturn {
            do { try library.clearHistory() } catch { showError(error.localizedDescription) }
        }
    }

    @objc func showWelcome() {
        NSWorkspace.shared.open(URL(string: "https://github.com/PROMLEE/promecapt/blob/main/docs/USAGE.md")!)
    }

    @objc func openSupportPage() {
        if let url = AppInfo.supportURL { NSWorkspace.shared.open(url) }
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool { item.action == #selector(checkForUpdates) ? updates.canCheck : true }
    @objc func checkForUpdates() { updates.check() }
    @objc func showPermissions() { permissionSetup?.show() }
    @objc func showAbout() { showSettings(); preferences?.showAbout() }

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
                UserDefaults.standard.set(profile, forKey: DefaultsKey.hotkeyProfile)
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
    @objc private func openLibrary() { NSWorkspace.shared.open(library.root) }
    @objc func quit() { NSApp.terminate(nil) }
}
