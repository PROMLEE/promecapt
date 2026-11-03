import AppKit

/// Stable preference IDs; hiding a button never disables its action or shortcut.
enum ToolbarItem: String, CaseIterable {
    case region, select, pencil, marker, rectangle, ellipse, line, arrow, text, number, conceal
    case undo, redo, ocr, record, copy, save, pin, close
    static let changed = Notification.Name("PromecaptToolbarChanged")
    static let key = "captureToolbarHiddenItems"
    static let defaultHidden: Set<String> = ["undo", "redo", "close"]
    static var hidden: Set<String> {
        guard let saved = UserDefaults.standard.stringArray(forKey: key) else { return defaultHidden }
        return Set(saved)
    }
    var isVisible: Bool { !Self.hidden.contains(rawValue) }
    var title: String {
        switch self {
        case .region: return L("캡처 영역 이동 / 크기 조절")
        case .select: return L("주석 선택")
        case .pencil: return L("펜")
        case .marker: return L("형광펜")
        case .rectangle: return L("사각형")
        case .ellipse: return L("타원")
        case .line: return L("선")
        case .arrow: return L("화살표")
        case .text: return L("텍스트")
        case .number: return L("번호")
        case .conceal: return L("가리기")
        case .undo: return L("실행 취소 (⌘Z)")
        case .redo: return L("다시 실행 (⌘⇧Z)")
        case .ocr: return "OCR"
        case .record: return L("GIF 녹화")
        case .copy: return L("복사")
        case .save: return L("저장")
        case .pin: return L("고정")
        case .close: return L("닫기")
        }
    }
    func setVisible(_ visible: Bool) {
        var values = Self.hidden
        if visible { values.remove(rawValue) } else { values.insert(rawValue) }
        UserDefaults.standard.set(values.sorted(), forKey: Self.key)
        NotificationCenter.default.post(name: Self.changed, object: nil)
    }
    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
        NotificationCenter.default.post(name: changed, object: nil)
    }
}
