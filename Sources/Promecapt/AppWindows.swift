import AppKit
import ApplicationServices
import ServiceManagement

final class PreferencesController: NSWindowController {
    var onShowPermissions: (() -> Void)?
    private let accessibilityLabel = NSTextField(labelWithString: "")
    private var permissionObserver: NSObjectProtocol?
    var onLanguageChange: (() -> Void)?
    var onSetProfile: ((Int) -> String?)?
    var onSetShortcut: ((HotkeyAction, Shortcut?) -> String?)?
    var onRecording: ((Bool) -> Void)?
    var onRestoreIcon: (() -> Void)?
    var onSetDockVisibility: ((Bool) -> Void)?
    private var recorders: [HotkeyAction: ShortcutRecorder] = [:]
    var onClearHistory: (() -> Void)?
    var onOpenLibrary: (() -> Void)?
    private var actions: [Int: (NSControl) -> Void] = [:]
    private var actionID = 0
    private var helpPopover: NSPopover?

    private let updates: AppUpdates
    private var aboutTab: NSTabViewItem?
    private weak var tabView: NSTabView?
    private let updateStatus = NSTextField(wrappingLabelWithString: "")
    private let latestLabel = NSTextField(labelWithString: "")
    private let lastCheckLabel = NSTextField(labelWithString: "")
    private var checkButton: NSButton!
    private var automaticButton: NSButton!
    private var updateObserver: NSObjectProtocol?

    init(updates: AppUpdates) {
        self.updates = updates
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 650, height: 510),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = L("Promecapt 설정")
        window.isReleasedWhenClosed = false
        window.center()
        let container = NSView()
        let tabs = NSTabView()
        tabView = tabs
        tabs.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tabs)
        window.contentView = container
        NSLayoutConstraint.activate([
            tabs.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            tabs.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            tabs.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            tabs.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20)])

        let general = page(L("일반"), tabs: tabs)
        let languages = NSPopUpButton()
        languages.addItems(withTitles: AppLanguage.names)
        languages.selectItem(at: AppLanguage.codes.firstIndex(of: UserDefaults.standard.string(forKey: "appLanguage") ?? "auto") ?? 0)
        languages.setAccessibilityLabel(L("언어"))
        bind(languages) { [weak self] control in
            UserDefaults.standard.set(AppLanguage.codes[(control as! NSPopUpButton).indexOfSelectedItem], forKey: "appLanguage")
            DispatchQueue.main.async { self?.onLanguageChange?() }
        }
        general.addArrangedSubview(withHelp(NSStackView(views: [NSTextField(labelWithString: L("언어")), languages]), text: L("메뉴와 새 창에 바로 적용됩니다. 열려 있는 편집창은 다시 열어 주세요.")))
        let permissions = NSButton(title: L("권한 설정…"), target: nil, action: nil)
        bind(permissions) { [weak self] _ in self?.onShowPermissions?() }
        general.addArrangedSubview(permissions)
        general.addArrangedSubview(heading(L("시작 및 표시")))
        general.addArrangedSubview(withHelp(toggle(L("Dock에 Promecapt 표시"), key: "showDock", fallback: true) { [weak self] enabled in
            self?.onSetDockVisibility?(enabled)
        }, text: L("Dock 표시를 꺼도 메뉴 막대 아이콘과 단축키는 계속 사용할 수 있습니다.\n설정: 메뉴 막대 Promecapt 아이콘 → 설정, 또는 ⌘,")))
        let login = NSButton(checkboxWithTitle: L("로그인할 때 시작"), target: nil, action: nil)
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        bind(login) { control in
            guard let button = control as? NSButton else { return }
            do {
                if button.state == .on { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                button.state = SMAppService.mainApp.status == .enabled ? .on : .off
                showError(error.localizedDescription)
            }
        }
        general.addArrangedSubview(login)

        let repair = NSButton(title: L("메뉴 막대 아이콘 위치 복구"), target: nil, action: nil)
        bind(repair) { [weak self] _ in self?.onRestoreIcon?() }
        general.addArrangedSubview(repair)

        let keys = page(L("단축키"), tabs: tabs)
        keys.spacing = 10
        keys.addArrangedSubview(heading(L("전역 단축키")))
        let profiles = NSPopUpButton()
        profiles.addItems(withTitles: [L("F1 캡처 · F3 고정 · F4 표시/숨기기"), L("⌥⌘1 캡처 · ⌥⌘3 고정 · ⌥⌘4 표시/숨기기"), L("전역 단축키 사용 안 함"), L("직접 지정")])
        profiles.selectItem(at: UserDefaults.standard.integer(forKey: "hotkeyProfile"))
        let errorLabel = NSTextField(wrappingLabelWithString: "")
        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 11)
        errorLabel.preferredMaxLayoutWidth = 510
        bind(profiles) { [weak self] sender in
            guard let self else { return }
            let error = self.onSetProfile?((sender as! NSPopUpButton).indexOfSelectedItem)
            profiles.selectItem(at: UserDefaults.standard.integer(forKey: "hotkeyProfile"))
            errorLabel.stringValue = error ?? ""
            self.refreshRecorders()
        }
        keys.addArrangedSubview(withHelp(profiles, text: L("버튼을 클릭한 뒤 원하는 조합을 누르세요. Esc 취소 · Delete 해제.\nF1–F20은 ‘F키…’에서 바로 선택할 수 있습니다. 밝기·음량 키 모드에서는 실행 시 Fn+F1을 누르세요.\n중복·시스템 충돌 시 기존 설정을 유지합니다. 캡처 중 ⌘C 복사 · ⌘Enter 고정 · Esc 취소")))
        for action in HotkeyAction.allCases {
            let label = NSTextField(labelWithString: action.title)
            label.widthAnchor.constraint(equalToConstant: 185).isActive = true
            let recorder = ShortcutRecorder(action: action)
            recorder.shortcut = ShortcutPreferences.bindings()[action]
            recorder.onRecording = { [weak self] recording in self?.onRecording?(recording) }
            recorder.onRecord = { [weak self] binding in
                let error = self?.onSetShortcut?(action, binding)
                profiles.selectItem(at: UserDefaults.standard.integer(forKey: "hotkeyProfile"))
                self?.refreshRecorders()
                return error
            }
            recorder.onError = { error in errorLabel.stringValue = error ?? "" }
            recorders[action] = recorder
            let clear = NSButton(title: L("해제"), target: nil, action: nil)
            bind(clear) { [weak self] _ in
                let error = self?.onSetShortcut?(action, nil)
                errorLabel.stringValue = error ?? ""
                profiles.selectItem(at: UserDefaults.standard.integer(forKey: "hotkeyProfile"))
                self?.refreshRecorders()
            }
            let functions = NSPopUpButton()
            functions.addItems(withTitles: [L("F키…")] + (1...20).map { "F\($0)" })
            functions.setAccessibilityLabel(L("{0} 기능키 선택", action.title))
            bind(functions) { [weak self] sender in
                let picker = sender as! NSPopUpButton
                guard let binding = Shortcut.functionKey(picker.indexOfSelectedItem) else { return }
                let error = self?.onSetShortcut?(action, binding)
                errorLabel.stringValue = error ?? ""
                picker.selectItem(at: 0)
                profiles.selectItem(at: UserDefaults.standard.integer(forKey: "hotkeyProfile"))
                self?.refreshRecorders()
            }
            let row = NSStackView(views: [label, recorder, functions, clear])
            row.spacing = 8
            keys.addArrangedSubview(row)
        }
        keys.addArrangedSubview(errorLabel)

        let capture = page(L("캡처"), tabs: tabs)
        capture.addArrangedSubview(withHelp(heading(L("캡처 동작")), text: L("영역 선택 후 8개 핸들로 크기를 조절합니다. 테두리 안쪽을 드래그하면 영역이 이동합니다. 도구 막대에서 펜·도형·화살표·텍스트·모자이크를 선택하면 그 자리에서 주석을 작성할 수 있습니다.")))
        let delay = NSPopUpButton()
        delay.addItems(withTitles: [L("지연 없이 캡처"), L("3초 뒤 캡처"), L("5초 뒤 캡처")])
        delay.selectItem(at: [0, 3, 5].firstIndex(of: UserDefaults.standard.integer(forKey: "captureDelay")) ?? 0)
        bind(delay) { UserDefaults.standard.set([0, 3, 5][($0 as! NSPopUpButton).indexOfSelectedItem], forKey: "captureDelay") }
        capture.addArrangedSubview(delay)
        capture.addArrangedSubview(toggle(L("캡처 결과를 클립보드에 자동 복사"), key: "autoCopy", fallback: true))
        capture.addArrangedSubview(toggle(L("마지막 캡처 영역 기억"), key: "rememberRegion", fallback: false))
        capture.addArrangedSubview(toggle(L("캡처 전 창·앱 요소 자동 감지"), key: "autoDetectTargets", fallback: true))
        let targetDetail = NSPopUpButton()
        targetDetail.addItems(withTitles: CaptureTargetDetail.allCases.map(\.title))
        targetDetail.selectItem(at: CaptureTargetDetail.current.rawValue)
        targetDetail.setAccessibilityLabel(L("자동 영역 인식 범위"))
        bind(targetDetail) { UserDefaults.standard.set(($0 as! NSPopUpButton).indexOfSelectedItem, forKey: "captureTargetDetail") }
        capture.addArrangedSubview(heading(L("자동 영역 인식 범위")))
        capture.addArrangedSubview(withHelp(targetDetail, text: L("균형은 작은 아이콘·글자 영역을 건너뜁니다. 큰 영역 위주는 패널·넓은 구역을 우선하고, 창만은 내부 요소를 감지하지 않습니다. Tab으로 상위 영역을 선택할 수 있습니다.")))
        capture.addArrangedSubview(toggle(L("그린 주석을 자동으로 선택"), key: "autoSelectAnnotations", fallback: true))
        refreshPermissionStatus()
        capture.addArrangedSubview(accessibilityLabel)
        let elementPermission = NSButton(title: L("앱 내부 요소 감지 권한 설정…"), target: nil, action: nil)
        bind(elementPermission) { [weak self] _ in self?.onShowPermissions?() }
        permissionObserver = NotificationCenter.default.addObserver(forName: PermissionSetupController.changed, object: nil, queue: .main) { [weak self] _ in self?.refreshPermissionStatus() }
        capture.addArrangedSubview(withHelp(elementPermission, text: L("창 자동 감지는 화면 캡처 권한으로 작동합니다. 버튼·입력칸 등 내부 요소 감지는 손쉬운 사용 권한이 필요하며, 앱이 제공하는 접근성 정보에 따라 감지 범위가 다릅니다. Tab으로 상위 영역을 선택합니다.")))

        let toolbarPage = page(L("도구"), tabs: tabs)
        toolbarPage.addArrangedSubview(withHelp(heading(L("도구창 버튼")), text: L("행을 드래그하거나 위로·아래로 버튼으로 순서를 바꾸세요. 체크한 버튼만 표시합니다. 숨긴 기능은 모든 도구(…) 메뉴에서 사용할 수 있습니다.")))
        toolbarPage.addArrangedSubview(ToolbarCustomizationView(frame: .zero))
        toolbarPage.addArrangedSubview(withHelp(toggle(L("마지막 캡처 도구 기억"), key: CaptureToolPreferences.enabledKey, fallback: false), text: L("켜면 마지막으로 직접 선택한 도구를 다음 캡처에서도 사용합니다. 꺼두면 캡처 영역 조절로 시작합니다.")))

        let gif = page("GIF", tabs: tabs)
        gif.addArrangedSubview(withHelp(heading(L("GIF 녹화")), text: L("녹화 중에는 빨간 점선과 바깥쪽 음영으로 영역을 표시하며, 화면은 그대로 조작할 수 있습니다. 정지 후 결과 창에서 재생·복사·고정·저장을 선택합니다. GIF 고정은 재생 상태로 복원되며 주석 편집·회전은 지원하지 않습니다.")))
        let options = GIFOptions.current
        for (title, key, values, labels, selected) in [
            (L("프레임"), "gifFrameRate", GIFOptions.frameRates, GIFOptions.frameRates.map { "\($0) fps" }, options.frameRate),
            (L("해상도"), "gifMaxDimension", GIFOptions.dimensions, [L("긴 변 640 px"), L("긴 변 1280 px"), L("긴 변 1920 px"), L("원본 픽셀 (Retina 포함)")], options.maxDimension),
            (L("최대 시간"), "gifDuration", GIFOptions.durations, GIFOptions.durations.map { L("{0}초", $0) }, options.duration)
        ] {
            let label = NSTextField(labelWithString: title); label.widthAnchor.constraint(equalToConstant: 90).isActive = true
            let picker = NSPopUpButton(); picker.addItems(withTitles: labels)
            picker.selectItem(at: values.firstIndex(of: selected) ?? 0); picker.setAccessibilityLabel("GIF " + title)
            bind(picker) { UserDefaults.standard.set(values[($0 as! NSPopUpButton).indexOfSelectedItem], forKey: key) }
            let row = NSStackView(views: [label, picker]); row.spacing = 12; gif.addArrangedSubview(withHelp(row, text: L("다음 녹화부터 적용됩니다. 프레임은 최대 초당 프레임 수이며 화면 변화량에 따라 줄어들 수 있습니다. 해상도는 원본보다 확대하지 않습니다. 임시 프레임이 256MiB에 도달하면 녹화를 마칩니다.")))
        }
        gif.addArrangedSubview(toggle(L("마우스 커서도 녹화"), key: "gifShowsCursor", fallback: false))

        let pins = page(L("고정"), tabs: tabs)
        pins.addArrangedSubview(withHelp(heading(L("고정 이미지")), text: L("드래그: 이동 · 가장자리: 크기 조절 · 휠: 확대/축소\nCtrl+휠: 투명도 · Space: 같은 창에서 주석 편집\n1/2: 회전 · 3/4: 반전 · 0: 원본 크기\n더블 클릭: 숨기기 · Shift+더블 클릭: 썸네일\n클릭 통과는 메뉴 막대 Promecapt에서 일괄 해제할 수 있습니다.")))
        pins.addArrangedSubview(toggle(L("앱 시작 시 고정 이미지 복원"), key: "restorePins", fallback: false))
        pins.addArrangedSubview(toggle(L("고정 이미지 그림자 표시"), key: "pinShadow", fallback: true))

        let history = page(L("기록"), tabs: tabs)
        history.addArrangedSubview(heading(L("로컬 캡처 기록")))
        let limit = NSPopUpButton()
        limit.addItems(withTitles: [L("최근 10개 보관"), L("최근 50개 보관"), L("최근 100개 보관")])
        limit.selectItem(at: [10, 50, 100].firstIndex(of: UserDefaults.standard.integer(forKey: "historyLimit")) ?? 1)
        bind(limit) { UserDefaults.standard.set([10, 50, 100][($0 as! NSPopUpButton).indexOfSelectedItem], forKey: "historyLimit") }
        history.addArrangedSubview(withHelp(limit, text: L("이미지와 OCR은 이 Mac에서 처리합니다. 기록 이동 시 바깥 화면을 복원하도록 선택 이미지와 당시 화면 전체·선택 위치를 이 Mac에 함께 보관합니다. 기록 지우기는 이 배경도 함께 지웁니다.")))
        let folder = NSButton(title: L("보관함 폴더 열기"), target: nil, action: nil)
        bind(folder) { [weak self] _ in self?.onOpenLibrary?() }
        history.addArrangedSubview(folder)
        let clear = NSButton(title: L("캡처 기록 지우기…"), target: nil, action: nil)
        bind(clear) { [weak self] _ in self?.onClearHistory?() }
        history.addArrangedSubview(clear)

        let about = page(L("정보"), tabs: tabs)
        about.spacing = 10
        aboutTab = tabs.tabViewItems.last
        let identity = NSStackView()
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.widthAnchor.constraint(equalToConstant: 54).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 54).isActive = true
        let identityText = NSStackView(views: [heading("Promecapt"), note(L("macOS 캡처·주석·화면 고정·GIF 녹화"))])
        identityText.orientation = .vertical; identityText.alignment = .leading; identityText.spacing = 4
        identity.addArrangedSubview(icon); identity.addArrangedSubview(identityText); identity.spacing = 16
        about.addArrangedSubview(identity)
        about.addArrangedSubview(note(L("버전 {0} · 빌드 {1}", AppInfo.version, AppInfo.build)))
        about.addArrangedSubview(note(AppInfo.architecture + " · " + ProcessInfo.processInfo.operatingSystemVersionString + " · " + AppInfo.revision))
        about.addArrangedSubview(heading(L("업데이트")))
        automaticButton = NSButton(checkboxWithTitle: L("자동으로 다운로드·설치하고 다시 실행"), target: nil, action: nil)
        bind(automaticButton) { [weak self] sender in self?.updates.setAutomatic((sender as! NSButton).state == .on); self?.refreshUpdates() }
        about.addArrangedSubview(withHelp(automaticButton, text: L("안정 버전만 확인합니다. 자동 업데이트는 선택 사항이며, 캡처·녹화·편집 중에는 재실행을 미룹니다.")))
        about.addArrangedSubview(latestLabel)
        about.addArrangedSubview(lastCheckLabel)
        checkButton = NSButton(title: L("업데이트 확인…"), target: nil, action: nil)
        bind(checkButton) { [weak self] _ in self?.updates.check() }
        let releases = NSButton(title: L("릴리스 보기"), target: nil, action: nil)
        bind(releases) { _ in NSWorkspace.shared.open(AppInfo.releases) }
        let website = NSButton(title: "GitHub", target: nil, action: nil)
        bind(website) { _ in NSWorkspace.shared.open(AppInfo.website) }
        about.addArrangedSubview(NSStackView(views: [checkButton, releases, website]))
        updateStatus.font = .systemFont(ofSize: 12); updateStatus.textColor = .secondaryLabelColor
        updateStatus.preferredMaxLayoutWidth = 510
        about.addArrangedSubview(updateStatus)
        if let url = AppInfo.supportURL {
            let support = NSButton(title: L("개발 후원…"), target: nil, action: nil)
            bind(support) { _ in NSWorkspace.shared.open(url) }
            about.addArrangedSubview(support)
        }
        about.addArrangedSubview(note("MIT · © 2026 PROMLEE · Sparkle (MIT)"))
        updateObserver = NotificationCenter.default.addObserver(forName: AppUpdates.changed, object: updates, queue: .main) { [weak self] _ in self?.refreshUpdates() }
        refreshUpdates()
    }
    required init?(coder: NSCoder) { fatalError() }
    private func refreshPermissionStatus() { accessibilityLabel.stringValue = L("손쉬운 사용 권한: {0}", CaptureTargetDetector.canReadElements ? L("허용됨") : L("허용 필요")) }
    func show() { refreshPermissionStatus(); refreshUpdates(); NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil) }
    func showAbout() { if let aboutTab { tabView?.selectTabViewItem(aboutTab) }; show() }
    private func refreshUpdates() {
        automaticButton.state = updates.automatic ? .on : .off
        automaticButton.isEnabled = updates.configured
        checkButton.isEnabled = updates.canCheck
        latestLabel.stringValue = L("최신 버전: {0}", updates.latestVersion ?? "—")
        lastCheckLabel.stringValue = L("마지막 확인: {0}", updates.lastChecked.map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short) } ?? L("확인한 적 없음"))
        updateStatus.stringValue = updates.status
    }
    deinit { if let permissionObserver { NotificationCenter.default.removeObserver(permissionObserver) }; if let updateObserver { NotificationCenter.default.removeObserver(updateObserver) } }
    private func refreshRecorders() {
        let bindings = ShortcutPreferences.bindings()
        for (action, recorder) in recorders { recorder.shortcut = bindings[action] }
    }
    private func page(_ title: String, tabs: NSTabView) -> NSStackView {
        let item = NSTabViewItem(identifier: title)
        item.label = title
        let content = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24)])
        item.view = content
        tabs.addTabViewItem(item)
        return stack
    }
    private func heading(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        return label
    }
    /// Native help button: click or keyboard activation opens a dismissible popover.
    private func withHelp(_ control: NSView, text: String) -> NSView {
        let button = NSButton(title: "", target: nil, action: nil)
        button.bezelStyle = .helpButton
        func title(of view: NSView) -> String? {
            if let button = view as? NSButton, !button.title.isEmpty { return button.title }
            if let field = view as? NSTextField, !field.stringValue.isEmpty { return field.stringValue }
            return view.subviews.compactMap { title(of: $0) }.first
        }
        button.setAccessibilityLabel("? " + (title(of: control) ?? window?.title ?? "Promecapt"))
        let readable = text
            .replacingOccurrences(of: ". ", with: ".\n")
            .replacingOccurrences(of: "。", with: "。\n")
            .replacingOccurrences(of: "\n\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        button.toolTip = readable
        bind(button) { [weak self] sender in
            guard let self else { return }
            self.helpPopover?.close()
            let label = NSTextField(wrappingLabelWithString: readable)
            label.font = .systemFont(ofSize: 13)
            label.textColor = .labelColor
            label.preferredMaxLayoutWidth = 340
            label.translatesAutoresizingMaskIntoConstraints = false
            let controller = NSViewController()
            controller.view = NSView()
            controller.view.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor, constant: -16),
                label.topAnchor.constraint(equalTo: controller.view.topAnchor, constant: 14),
                label.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor, constant: -14),
                label.widthAnchor.constraint(equalToConstant: 340)])
            let popover = NSPopover()
            popover.behavior = .transient
            popover.contentViewController = controller
            self.helpPopover = popover
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
        }
        let row = NSStackView(views: [control, button])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }
    private func note(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 12)
        label.preferredMaxLayoutWidth = 510
        return label
    }
    private func toggle(_ title: String, key: String, fallback: Bool, changed: ((Bool) -> Void)? = nil) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        button.state = (UserDefaults.standard.object(forKey: key) as? Bool ?? fallback) ? .on : .off
        bind(button) { sender in
            let value = (sender as! NSButton).state == .on
            UserDefaults.standard.set(value, forKey: key)
            changed?(value)
        }
        return button
    }
    private func bind(_ control: NSControl, _ action: @escaping (NSControl) -> Void) {
        actionID += 1; control.tag = actionID; actions[actionID] = action
        control.target = self; control.action = #selector(invoke(_:))
    }
    @objc private func invoke(_ sender: NSControl) { actions[sender.tag]?(sender) }
}

enum StatusIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            CaptureMark.draw(in: NSRect(x: 3, y: 3, width: 12, height: 12), color: .black)
            return true
        }
        image.isTemplate = true
        return image
    }
}
