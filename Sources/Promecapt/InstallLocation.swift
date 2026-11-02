import AppKit

enum InstallLocation {
    static func isInstalled(_ app: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let path = app.standardizedFileURL.path
        return ["/Applications/", home.appendingPathComponent("Applications").path + "/"].contains { path.hasPrefix($0) }
    }

    /// Called before hotkeys, capture sessions and the user library are opened.
    static func offerInstallation() -> Bool {
        let source = Bundle.main.bundleURL
        guard source.pathExtension == "app", !isInstalled(source) else { return false }
        let fm = FileManager.default
        let folder = fm.isWritableFile(atPath: "/Applications") ? URL(fileURLWithPath: "/Applications")
            : fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        let destination = folder.appendingPathComponent(source.lastPathComponent)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let prompt = NSAlert()
        prompt.messageText = L("응용 프로그램 폴더에 설치할까요?")
        prompt.informativeText = L("Promecapt를 {0}에 복사하고 설치된 앱을 실행합니다. 캡처 권한은 설치 후 허용하세요.", destination.path)
        prompt.addButton(withTitle: L("설치하고 실행"))
        prompt.addButton(withTitle: L("현재 위치에서 실행"))
        guard prompt.runModal() == .alertFirstButtonReturn else { return false }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .contains { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && $0.bundleURL?.standardizedFileURL == destination.standardizedFileURL }
        if running {
            showError(L("설치된 Promecapt를 먼저 종료한 뒤 다시 시도하세요."))
            return false
        }
        if fm.fileExists(atPath: destination.path) {
            let replace = NSAlert()
            replace.messageText = L("기존 Promecapt를 대치할까요?")
            replace.informativeText = destination.path
            replace.addButton(withTitle: L("대치")); replace.addButton(withTitle: L("취소"))
            guard replace.runModal() == .alertFirstButtonReturn else { return false }
        }
        let staging = folder.appendingPathComponent(".Promecapt-install-" + UUID().uuidString)
        let stagedApp = staging.appendingPathComponent(source.lastPathComponent)
        let previous = staging.appendingPathComponent("Previous.app")
        do {
            try fm.createDirectory(at: staging, withIntermediateDirectories: true)
            try fm.copyItem(at: source, to: stagedApp)
            if fm.fileExists(atPath: destination.path) { try fm.moveItem(at: destination, to: previous) }
            do { try fm.moveItem(at: stagedApp, to: destination) }
            catch {
                if fm.fileExists(atPath: previous.path) { try? fm.moveItem(at: previous, to: destination) }
                throw error
            }
            // Keep replaced apps recoverable; do not remove their contents permanently.
            if fm.fileExists(atPath: previous.path) { try? fm.trashItem(at: previous, resultingItemURL: nil) }
            if (try? fm.contentsOfDirectory(atPath: staging.path).isEmpty) == true { try? fm.removeItem(at: staging) }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: destination, configuration: configuration) { _, error in
                DispatchQueue.main.async {
                    if let error { showError(L("설치한 앱을 열지 못했습니다: {0}", error.localizedDescription)) }
                    NSApp.terminate(nil)
                }
            }
            return true
        } catch {
            showError(L("설치하지 못했습니다: {0}", error.localizedDescription))
            return false
        }
    }
}
