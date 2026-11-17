/// `UserDefaults` keys. The string values are persisted user data and must not change.
enum DefaultsKey {
    static let hotkeyProfile = "hotkeyProfile", historyLimit = "historyLimit", captureDelay = "captureDelay"
    static let showDock = "showDock", lastKnownUpdateVersion = "lastKnownUpdateVersion", appLanguage = "appLanguage"
    static let restorePins = "restorePins", pinShadow = "pinShadow", lastCaptureRect = "lastCaptureRect"
    static let captureTargetDetail = "captureTargetDetail", captureHelpExpanded = "captureHelpExpanded"
    static let autoSelectAnnotations = "autoSelectAnnotations", autoCopy = "autoCopy", showDashboard = "showDashboard"
    static let rememberRegion = "rememberRegion", gifShowsCursor = "gifShowsCursor", gifMaxDimension = "gifMaxDimension"
    static let gifFrameRate = "gifFrameRate", gifDuration = "gifDuration", autoDetectTargets = "autoDetectTargets"
}
