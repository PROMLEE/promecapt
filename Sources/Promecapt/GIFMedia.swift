import AppKit
import ImageIO
import UniformTypeIdentifiers

enum GIFMedia {
    static let pasteboardType = NSPasteboard.PasteboardType(UTType.gif.identifier)
    static func poster(_ data: Data) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetType(source) as String? == UTType.gif.identifier,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
    static func copy(_ data: Data, to pasteboard: NSPasteboard = .general) throws {
        guard let image = poster(data) else { throw CocoaError(.fileReadCorruptFile) }
        // Keep a real GIF file available for apps that accept file attachments on paste.
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Promecapt/Clipboard")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("Promecapt-\(UUID().uuidString).gif")
        try data.write(to: file, options: .atomic)
        let item = NSPasteboardItem()
        item.setData(data, forType: pasteboardType)
        item.setString(file.absoluteString, forType: .fileURL)
        if let png = Imaging.png(image) { item.setData(png, forType: .png) }
        pasteboard.clearContents()
        guard pasteboard.writeObjects([item]) else { throw CocoaError(.fileWriteUnknown) }
        // Preserve the current clipboard file. Older attachment copies expire after a day.
        for old in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
            if old != file, let date = try? old.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               date < Date().addingTimeInterval(-86400) { try? FileManager.default.removeItem(at: old) }
        }
    }
    static func save(_ data: Data) {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.gif]
        panel.nameFieldStringValue = "Promecapt-\(Int(Date().timeIntervalSince1970)).gif"
        if panel.runModal() == .OK, let url = panel.url {
            do { try data.write(to: url, options: .atomic) }
            catch { showError(L("GIF 저장 실패: {0}", error.localizedDescription)) }
        }
    }
}

/// Let the containing pin keep its move, resize, wheel and context-menu interactions.
final class AnimatedGIFView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    init(data: Data) {
        super.init(frame: .zero)
        image = NSImage(data: data); imageScaling = .scaleProportionallyUpOrDown
        animates = true
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { fatalError() }
}

final class GIFResultController: NSWindowController, NSWindowDelegate {
    let data: Data
    let poster: NSImage
    var onPin: ((Data, NSImage) -> Void)?
    var onClose: ((GIFResultController) -> Void)?
    init(data: Data) throws {
        guard let poster = GIFMedia.poster(data) else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data; self.poster = poster
        let previewSize = NSSize(width: max(360, min(720, poster.size.width)), height: max(180, min(440, poster.size.height)))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: NSSize(width: previewSize.width + 24, height: previewSize.height + 92)),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = L("Promecapt · GIF 결과")
        window.isReleasedWhenClosed = false; window.delegate = self; window.minSize = NSSize(width: 384, height: 260)
        let content = window.contentView!
        let preview = AnimatedGIFView(data: data)
        let info = NSTextField(labelWithString: "\(Int(poster.size.width)) × \(Int(poster.size.height)) px · \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
        info.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        let actions = NSStackView()
        actions.spacing = 8
        for (title, selector, key) in [(L("복사"), #selector(copyGIF), "c"), (L("고정"), #selector(pinGIF), "\r"), (L("저장…"), #selector(saveGIF), "s")] {
            let button = NSButton(title: title, target: self, action: selector)
            button.bezelStyle = .rounded; button.keyEquivalent = key; button.keyEquivalentModifierMask = .command
            actions.addArrangedSubview(button)
        }
        let close = NSButton(title: L("닫기"), target: self, action: #selector(closeResult)); close.bezelStyle = .rounded
        actions.addArrangedSubview(close)
        for view in [preview, info, actions] { view.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(view) }
        NSLayoutConstraint.activate([
            preview.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12), preview.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            preview.topAnchor.constraint(equalTo: content.topAnchor, constant: 12), preview.bottomAnchor.constraint(equalTo: info.topAnchor, constant: -8),
            info.leadingAnchor.constraint(equalTo: preview.leadingAnchor), info.bottomAnchor.constraint(equalTo: actions.topAnchor, constant: -8),
            actions.trailingAnchor.constraint(equalTo: preview.trailingAnchor), actions.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12)
        ])
        window.center()
    }
    required init?(coder: NSCoder) { fatalError() }
    func show() { NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil) }
    @objc private func copyGIF() { do { try GIFMedia.copy(data) } catch { showError(error.localizedDescription) } }
    @objc private func saveGIF() { GIFMedia.save(data) }
    @objc private func pinGIF() { onPin?(data, poster); close() }
    @objc private func closeResult() { close() }
    func windowWillClose(_ notification: Notification) { onClose?(self) }
}
