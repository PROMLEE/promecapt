import Foundation

/// Source strings remain stable keys so existing serialized annotation types do not change.
enum AppLanguage {
    static let codes = ["auto", "ko", "en", "ja", "zh-Hans"]
    static let names = ["시스템 설정 / System", "한국어", "English", "日本語", "简体中文"]
    static func resolved(_ choice: String, preferred: [String] = Locale.preferredLanguages) -> String {
        if codes.dropFirst().contains(choice) { return choice }
        for language in preferred {
            if language.hasPrefix("ko") { return "ko" }
            if language.hasPrefix("ja") { return "ja" }
            if language.hasPrefix("zh") { return "zh-Hans" }
            if language.hasPrefix("en") { return "en" }
        }
        return "en"
    }
    static var current: String { resolved(UserDefaults.standard.string(forKey: "appLanguage") ?? "auto") }
    static let translations: [String: [String: String]] = {
        var url = Bundle.main.url(forResource: "Translations", withExtension: "json")
        #if SWIFT_PACKAGE
        if url == nil { url = Bundle.module.url(forResource: "Translations", withExtension: "json") }
        #else
        if url == nil { url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Resources/Translations.json") }
        #endif
        guard let url, let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder().decode([String: [String: String]].self, from: data) else { return [:] }
        return result
    }()
    static func text(_ key: String, language: String) -> String {
        language == "ko" ? key : translations[language]?[key] ?? translations["en"]?[key] ?? key
    }
}

func L(_ key: String, _ arguments: Any...) -> String {
    var result = AppLanguage.text(key, language: AppLanguage.current)
    // Replace in a single scan: user text containing another placeholder stays literal.
    let pattern = try! NSRegularExpression(pattern: #"\{(\d+)\}"#)
    let matches = pattern.matches(in: result, range: NSRange(result.startIndex..., in: result))
    for match in matches.reversed() {
        guard let range = Range(match.range, in: result), let numberRange = Range(match.range(at: 1), in: result),
              let index = Int(result[numberRange]), arguments.indices.contains(index) else { continue }
        let value = AppLanguage.text(String(describing: arguments[index]), language: AppLanguage.current)
        result.replaceSubrange(range, with: value)
    }
    return result
}
