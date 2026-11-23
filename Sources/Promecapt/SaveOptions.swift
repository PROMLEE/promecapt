import AppKit
import UniformTypeIdentifiers

/// Image file formats offered by the save panel. Raw values are persisted in `UserDefaults`.
enum ImageSaveFormat: String, CaseIterable {
    case png, jpeg, tiff

    var label: String {
        switch self {
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        case .tiff: return "TIFF"
        }
    }
    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .tiff: return "tiff"
        }
    }
    var contentType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .tiff: return .tiff
        }
    }
    var bitmapType: NSBitmapImageRep.FileType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .tiff: return .tiff
        }
    }

    /// The format a file name extension asks for, or nil for an unsupported extension.
    static func matching(extension name: String) -> ImageSaveFormat? {
        switch name.lowercased() {
        case "png": return .png
        case "jpg", "jpeg": return .jpeg
        case "tif", "tiff": return .tiff
        default: return nil
        }
    }

    /// The format chosen at the last successful save; PNG until one is chosen.
    static var preferred: ImageSaveFormat {
        get { UserDefaults.standard.string(forKey: DefaultsKey.imageSaveFormat).flatMap(ImageSaveFormat.init(rawValue:)) ?? .png }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: DefaultsKey.imageSaveFormat) }
    }
}

/// Suggested save names that sort by time and read like macOS screenshot names.
enum SaveFileName {
    /// For example `Promecapt 2026-11-23 20.41.05.png`. Finder shows colons as slashes, so time uses periods.
    static func suggested(extension ext: String, date: Date = Date(), timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let stamp = String(format: "%04d-%02d-%02d %02d.%02d.%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0,
                           c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
        return "Promecapt \(stamp).\(ext)"
    }

    /// Swaps a known image extension for `ext`, keeping whatever name the user typed.
    static func replacingExtension(_ name: String, with ext: String) -> String {
        let url = URL(fileURLWithPath: name)
        guard ImageSaveFormat.matching(extension: url.pathExtension) != nil else {
            return name.isEmpty ? name : "\(name).\(ext)"
        }
        return "\(url.deletingPathExtension().lastPathComponent).\(ext)"
    }
}

/// Keeps the save panel's format menu, allowed type and file name extension in step.
final class ImageSavePanelController: NSObject {
    let panel = NSSavePanel()
    private let popup = NSPopUpButton(frame: .zero, pullsDown: false)
    private(set) var format: ImageSaveFormat

    init(format: ImageSaveFormat = .preferred, date: Date = Date()) {
        self.format = format
        super.init()
        for option in ImageSaveFormat.allCases {
            popup.addItem(withTitle: option.label)
            popup.lastItem?.representedObject = option.rawValue
        }
        popup.selectItem(at: ImageSaveFormat.allCases.firstIndex(of: format) ?? 0)
        popup.target = self
        popup.action = #selector(formatChanged)
        let label = NSTextField(labelWithString: L("파일 형식:"))
        let row = NSStackView(views: [label, popup])
        row.orientation = .horizontal
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        row.frame.size = row.fittingSize
        panel.accessoryView = row
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = SaveFileName.suggested(extension: format.fileExtension, date: date)
    }

    @objc private func formatChanged() {
        guard let raw = popup.selectedItem?.representedObject as? String,
              let selected = ImageSaveFormat(rawValue: raw) else { return }
        select(selected)
    }

    func select(_ selected: ImageSaveFormat) {
        format = selected
        popup.selectItem(at: ImageSaveFormat.allCases.firstIndex(of: selected) ?? 0)
        panel.allowedContentTypes = [selected.contentType]
        panel.nameFieldStringValue = SaveFileName.replacingExtension(panel.nameFieldStringValue, with: selected.fileExtension)
    }

    /// The format to write for the chosen URL: its extension wins, then the menu choice.
    func format(for url: URL) -> ImageSaveFormat {
        ImageSaveFormat.matching(extension: url.pathExtension) ?? format
    }
}
