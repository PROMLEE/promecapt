import AppKit

extension AppDelegate {
    func installMainMenu() {
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

    @discardableResult private func add(_ title: String, _ action: Selector, to targetMenu: NSMenu? = nil) -> NSMenuItem {
        let entry = (targetMenu ?? menu).addItem(withTitle: title, action: action, keyEquivalent: "")
        entry.target = self
        return entry
    }

    func rebuildMenu() {
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
        if !deferredPinRecords.isEmpty {
            add(L("이전 고정 이미지 복원 ({0})", deferredPinRecords.count), #selector(restoreDeferredPins))
            add(L("이전 고정 이미지 지우기…"), #selector(discardDeferredPins))
        }
        let groups = NSMenu()
        for group in Set(pins.map(\.group)).sorted() {
            let entry = add(group.isEmpty ? L("미지정") : group, #selector(toggleGroup(_:)), to: groups)
            entry.representedObject = group
        }
        let groupItem = menu.addItem(withTitle: L("그룹 표시 / 숨기기"), action: nil, keyEquivalent: "")
        groupItem.submenu = groups
        let history = NSMenu()
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm:ss"
        for entry in library.entries {
            let item = add(formatter.string(from: entry.date), #selector(openHistory(_:)), to: history)
            item.representedObject = entry.id.uuidString
            item.image = library.thumbnail(entry)
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

    func configureStatusItem(forcePosition: Bool = false) {
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
    @objc func keepStatusIconVisible() {
        guard let item else { configureStatusItem(forcePosition: true); return }
        item.isVisible = true
    }
    @objc func restoreStatusIcon() { configureStatusItem(forcePosition: true) }
}
