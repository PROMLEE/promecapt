import AppKit
import Sparkle

enum AppInfo {
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? L("개발 버전") }
    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—" }
    static var revision: String { Bundle.main.object(forInfoDictionaryKey: "PromecaptRevision") as? String ?? "—" }
    static var architecture: String {
        #if arch(arm64)
        return "Apple Silicon (arm64)"
        #else
        return "Intel (x86_64)"
        #endif
    }
    static let website = URL(string: "https://github.com/PROMLEE/promecapt")!
    static let releases = URL(string: "https://github.com/PROMLEE/promecapt/releases")!
    static var supportURL: URL? {
        guard let address = Bundle.main.object(forInfoDictionaryKey: "PromecaptSupportURL") as? String,
              let url = URL(string: address), url.scheme == "https",
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return nil }
        return url
    }
}

/// Sparkle owns archive validation, replacement, rollback and relaunch. No custom installer shell is run.
final class AppUpdates: NSObject, SPUUpdaterDelegate {
    static let changed = Notification.Name("PromecaptUpdateStateChanged")
    private var controller: SPUStandardUpdaterController!
    var isBusy: () -> Bool = { false }
    var saveBeforeInstall: () throws -> Void = {}
    private(set) var status = ""
    private(set) var latestVersion = UserDefaults.standard.string(forKey: "lastKnownUpdateVersion")
    private var observations: [NSKeyValueObservation] = []
    private var postponed: (() -> Void)?
    private var retryTimer: Timer?

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
    }
    var configured: Bool {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32,
              let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let url = URL(string: feed), Self.allowedFeed(url) else { return false }
        return Bundle.main.bundleURL.pathExtension == "app"
    }
    private static func allowedFeed(_ url: URL) -> Bool {
        if url.scheme == "https" { return true }
        #if DEBUG
        return Bundle.main.bundleIdentifier == "com.promlee.promecapt.update-test"
            && url.scheme == "http" && url.host == "127.0.0.1"
        #else
        return false
        #endif
    }
    var canCheck: Bool { configured && controller.updater.canCheckForUpdates }
    var automatic: Bool { configured && controller.updater.automaticallyChecksForUpdates && controller.updater.automaticallyDownloadsUpdates }
    var lastChecked: Date? { controller.updater.lastUpdateCheckDate }
    func start() {
        guard configured else { status = L("이 빌드는 자동 업데이트가 구성되지 않았습니다."); return }
        observations = [
            controller.updater.observe(\.canCheckForUpdates) { [weak self] _, _ in self?.notify() },
            controller.updater.observe(\.lastUpdateCheckDate) { [weak self] _, _ in self?.notify() },
            controller.updater.observe(\.automaticallyChecksForUpdates) { [weak self] _, _ in self?.notify() },
            controller.updater.observe(\.automaticallyDownloadsUpdates) { [weak self] _, _ in self?.notify() }
        ]
        controller.startUpdater()
    }
    func setAutomatic(_ enabled: Bool) {
        guard configured else { return }
        if enabled {
            controller.updater.automaticallyChecksForUpdates = true
            controller.updater.automaticallyDownloadsUpdates = true
        } else {
            controller.updater.automaticallyDownloadsUpdates = false
            controller.updater.automaticallyChecksForUpdates = false
        }
        if enabled {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.automatic, self.canCheck, !self.isBusy() else { return }
                self.controller.updater.checkForUpdatesInBackground()
            }
        }
        notify()
    }
    func check() {
        guard canCheck else { return }
        status = L("업데이트 확인 중…"); notify()
        controller.checkForUpdates(nil)
    }
    private func notify() {
        DispatchQueue.main.async { NotificationCenter.default.post(name: Self.changed, object: self) }
    }
    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        if isBusy() {
            throw NSError(domain: "Promecapt.Updates", code: 1, userInfo: [NSLocalizedDescriptionKey: L("캡처·녹화·편집을 마친 뒤 업데이트할 수 있습니다.")])
        }
    }
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        latestVersion = item.displayVersionString
        UserDefaults.standard.set(item.displayVersionString, forKey: "lastKnownUpdateVersion")
        status = L("새 버전 {0}을 사용할 수 있습니다.", item.displayVersionString); notify()
    }
    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        latestVersion = AppInfo.version
        UserDefaults.standard.set(AppInfo.version, forKey: "lastKnownUpdateVersion")
        status = L("최신 버전입니다."); notify()
    }
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        status = error.localizedDescription; notify()
    }
    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem, untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        guard isBusy() else { return false }
        enqueueInstallation(installHandler)
        return true
    }
    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationBlock installHandler: @escaping () -> Void) -> Bool {
        // Opted-in automatic updates install and relaunch once work is safe to interrupt.
        enqueueInstallation(installHandler)
        return true
    }
    private func enqueueInstallation(_ handler: @escaping () -> Void) {
        postponed = handler
        status = L("작업을 마치면 업데이트를 설치하고 다시 실행합니다."); notify()
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.attemptInstallation() }
        DispatchQueue.main.async { [weak self] in self?.attemptInstallation() }
    }
    private func attemptInstallation() {
        guard !isBusy(), let install = postponed else { return }
        do { try saveBeforeInstall() }
        catch { status = error.localizedDescription; notify(); return }
        retryTimer?.invalidate(); retryTimer = nil; postponed = nil
        install()
    }
    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        do { try saveBeforeInstall() }
        catch { status = error.localizedDescription; notify() }
    }
    deinit { retryTimer?.invalidate() }
}
