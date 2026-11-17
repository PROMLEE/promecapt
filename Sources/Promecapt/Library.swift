import AppKit
import ImageIO

struct HistoryEntry: Codable, Identifiable {
    var id: UUID
    var date: Date
    var selection: NSRect? = nil
    var filename: String { "\(id.uuidString).png" }
}

struct PinRecord: Codable {
    var id: UUID
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var opacity: Double
    var group: String
    var annotations: [AnnotationObject]? = nil
    var animated: Bool? = nil
}

/// `entries`, `pending` and the caches belong to the caller's (main) thread.
/// Image encoding and history file changes run in order on `io`.
final class Library {
    let root: URL
    private(set) var entries: [HistoryEntry] = []
    private let manager = FileManager.default
    private let io = DispatchQueue(label: "com.promlee.promecapt.library", qos: .utility)
    private var pending: [UUID: (image: NSImage, context: CaptureHistoryContext?)] = [:]
    private var thumbnails: [UUID: NSImage] = [:]
    private var savedPinRevisions: [UUID: Int] = [:]
    /// Called on the main thread when a queued history image could not be written.
    var onWriteFailure: ((Error) -> Void)?
    var historyLimit: Int { max(1, UserDefaults.standard.object(forKey: DefaultsKey.historyLimit) as? Int ?? 50) }

    init(root: URL? = nil) throws {
        self.root = root ?? manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Promepaste", isDirectory: true) // Preserve the existing library across the rename.
        try manager.createDirectory(at: self.root.appendingPathComponent("history"), withIntermediateDirectories: true)
        try manager.createDirectory(at: self.root.appendingPathComponent("pins"), withIntermediateDirectories: true)
        if manager.fileExists(atPath: historyIndex.path) {
            let data = try Data(contentsOf: historyIndex)
            if let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) { entries = decoded }
            else {
                // A damaged index must not lock the user out of the app or their captures.
                quarantine(historyIndex)
                entries = recoveredHistory()
                try? saveIndex(entries)
            }
            entries = entries.filter { manager.fileExists(atPath: historyURL($0).path) }
        }
    }

    private var historyIndex: URL { root.appendingPathComponent("history.json") }
    private var pinIndex: URL { root.appendingPathComponent("pins.json") }
    private func pinFile(_ id: UUID, _ suffix: String) -> URL { root.appendingPathComponent("pins/\(id.uuidString)\(suffix)") }

    private func saveIndex(_ entries: [HistoryEntry]) throws {
        try JSONEncoder().encode(entries).write(to: historyIndex, options: .atomic)
    }

    /// Keeps an unreadable index beside the library instead of overwriting it.
    private func quarantine(_ file: URL) {
        let name = "\(file.deletingPathExtension().lastPathComponent).corrupt-\(Int(Date().timeIntervalSince1970)).json"
        try? manager.moveItem(at: file, to: file.deletingLastPathComponent().appendingPathComponent(name))
    }

    private func imageFiles(in folder: String) -> [(id: UUID, url: URL, date: Date)] {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let files = (try? manager.contentsOfDirectory(at: root.appendingPathComponent(folder), includingPropertiesForKeys: keys)) ?? []
        return files.compactMap { url in
            // "-screen" and "-base" companions do not parse as a UUID and are skipped.
            guard url.pathExtension == "png", let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { return nil }
            return (id, url, (try? url.resourceValues(forKeys: Set(keys)))?.contentModificationDate ?? Date())
        }.sorted { $0.date > $1.date }
    }

    private func recoveredHistory() -> [HistoryEntry] {
        imageFiles(in: "history").map { HistoryEntry(id: $0.id, date: $0.date) }
    }

    func historyURL(_ entry: HistoryEntry) -> URL {
        root.appendingPathComponent("history").appendingPathComponent(entry.filename)
    }

    /// Records the capture immediately; PNG encoding and file writes happen in the background.
    @discardableResult func add(_ image: NSImage, context: CaptureHistoryContext? = nil) throws -> HistoryEntry {
        let entry = HistoryEntry(id: UUID(), date: Date(), selection: context?.selection)
        let next = Array(([entry] + entries).prefix(historyLimit))
        let expired = entries.filter { old in !next.contains { $0.id == old.id } }
        try saveIndex(next)
        entries = next
        pending[entry.id] = (image, context)
        for old in expired { pending[old.id] = nil; thumbnails[old.id] = nil }
        let imageURL = historyURL(entry), contextURL = historyContextURL(entry)
        let expiredURLs = expired.flatMap { [historyURL($0), historyContextURL($0)] }
        io.async { [weak self] in
            var failure: Error?
            do {
                guard let png = Imaging.png(image) else { throw CocoaError(.fileWriteUnknown) }
                try png.write(to: imageURL, options: .atomic)
                if let context {
                    guard let background = Imaging.png(context.image) else { throw CocoaError(.fileWriteUnknown) }
                    try background.write(to: contextURL, options: .atomic)
                }
            } catch { failure = error }
            for url in expiredURLs { try? FileManager.default.removeItem(at: url) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.pending[entry.id] = nil
                guard let failure else { return }
                self.entries.removeAll { $0.id == entry.id }
                self.thumbnails[entry.id] = nil
                try? self.saveIndex(self.entries)
                try? FileManager.default.removeItem(at: imageURL)
                try? FileManager.default.removeItem(at: contextURL)
                self.onWriteFailure?(failure)
            }
        }
        return entry
    }

    /// Waits for queued history writes, e.g. before quitting or installing an update.
    func flush() { io.sync {} }

    func clearHistory() throws {
        try saveIndex([])
        entries = []; pending.removeAll(); thumbnails.removeAll()
        let folder = root.appendingPathComponent("history")
        // After queued writes, so a capture still being saved is removed as well.
        io.sync {
            for file in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [] where file.pathExtension == "png" {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    func image(_ entry: HistoryEntry) -> NSImage? {
        if let queued = pending[entry.id] { return queued.image }
        return NSImage(contentsOf: historyURL(entry)).map(Imaging.normalized)
    }

    /// Small aspect-preserving preview, decoded once per entry without loading the full bitmap.
    func thumbnail(_ entry: HistoryEntry, fitting box: NSSize = NSSize(width: 56, height: 36)) -> NSImage? {
        if let cached = thumbnails[entry.id] { return cached }
        var result: NSImage?
        if let queued = pending[entry.id]?.image, queued.size.width > 0, queued.size.height > 0 {
            let scale = min(box.width / queued.size.width, box.height / queued.size.height, 1)
            let size = NSSize(width: max(1, queued.size.width * scale), height: max(1, queued.size.height * scale))
            let small = Imaging.render(size: NSSize(width: size.width * 2, height: size.height * 2)) {
                queued.draw(in: NSRect(x: 0, y: 0, width: size.width * 2, height: size.height * 2), from: .zero, operation: .copy, fraction: 1)
            }
            small.size = size
            result = small
        } else if let source = CGImageSourceCreateWithURL(historyURL(entry) as CFURL, nil) {
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: Int(max(box.width, box.height) * 2)]
            if let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary), cg.width > 0, cg.height > 0 {
                let scale = min(box.width / CGFloat(cg.width), box.height / CGFloat(cg.height), 1)
                result = NSImage(cgImage: cg, size: NSSize(width: max(1, CGFloat(cg.width) * scale), height: max(1, CGFloat(cg.height) * scale)))
            }
        }
        thumbnails[entry.id] = result
        return result
    }

    func historyContextURL(_ entry: HistoryEntry) -> URL {
        root.appendingPathComponent("history/\(entry.id.uuidString)-screen.png")
    }
    func historyItem(_ entry: HistoryEntry) -> CaptureHistoryItem? {
        if let queued = pending[entry.id] { return CaptureHistoryItem(image: queued.image, context: queued.context) }
        guard let image = image(entry) else { return nil }
        var item = CaptureHistoryItem(image: image)
        if let selection = entry.selection, let background = NSImage(contentsOf: historyContextURL(entry)) {
            item.context = CaptureHistoryContext(image: Imaging.normalized(background), selection: selection)
        }
        return item
    }
    func gifData(for record: PinRecord) -> Data? {
        guard record.animated == true else { return nil }
        return try? Data(contentsOf: pinFile(record.id, ".gif"))
    }

    func savePins(_ pins: [PinController], keeping deferred: [PinRecord] = []) throws {
        let currentRecords = try pins.map { pin -> PinRecord in
            guard let window = pin.window else { throw CocoaError(.fileWriteUnknown) }
            // Moving or resizing a pin only changes pins.json; media is rewritten when its content changed.
            if savedPinRevisions[pin.id] != pin.contentRevision || !manager.fileExists(atPath: pinFile(pin.id, ".png").path) {
                guard let data = Imaging.png(pin.image) else { throw CocoaError(.fileWriteUnknown) }
                try data.write(to: pinFile(pin.id, ".png"), options: .atomic)
                if let document = pin.annotationDocument {
                    guard let base = Imaging.png(document.base) else { throw CocoaError(.fileWriteUnknown) }
                    try base.write(to: pinFile(pin.id, "-base.png"), options: .atomic)
                }
                if let gif = pin.gifData { try gif.write(to: pinFile(pin.id, ".gif"), options: .atomic) }
                savedPinRevisions[pin.id] = pin.contentRevision
            }
            let frame = window.frame
            return PinRecord(id: pin.id, x: frame.minX, y: frame.minY, width: frame.width,
                height: frame.height, opacity: window.alphaValue, group: pin.group, annotations: pin.annotationDocument?.objects, animated: pin.gifData == nil ? nil : true)
        }
        let currentIDs = Set(currentRecords.map(\.id))
        savedPinRevisions = savedPinRevisions.filter { currentIDs.contains($0.key) }
        let records = currentRecords + deferred.filter { !currentIDs.contains($0.id) }
        try JSONEncoder().encode(records).write(to: pinIndex, options: .atomic)
        let live = Set(records.flatMap { ["\($0.id.uuidString).png"] + ($0.annotations == nil ? [] : ["\($0.id.uuidString)-base.png"]) + ($0.animated == true ? ["\($0.id.uuidString).gif"] : []) })
        for file in try manager.contentsOfDirectory(at: root.appendingPathComponent("pins"), includingPropertiesForKeys: nil) {
            if ["png", "gif"].contains(file.pathExtension) && !live.contains(file.lastPathComponent) { try manager.removeItem(at: file) }
        }
    }

    func annotationDocument(for record: PinRecord) -> AnnotationDocument? {
        guard let annotations = record.annotations,
              let base = NSImage(contentsOf: pinFile(record.id, "-base.png")) else { return nil }
        return AnnotationDocument(base: Imaging.normalized(base), objects: annotations)
    }

    func pinRecords() throws -> [PinRecord] {
        guard manager.fileExists(atPath: pinIndex.path) else { return [] }
        let data = try Data(contentsOf: pinIndex)
        if let records = try? JSONDecoder().decode([PinRecord].self, from: data) { return records }
        // Rebuild from the saved images first: the next save removes media that no record refers to.
        quarantine(pinIndex)
        let recovered = imageFiles(in: "pins").enumerated().compactMap { index, file -> PinRecord? in
            guard let image = NSImage(contentsOf: file.url).map(Imaging.normalized), image.size.width > 0, image.size.height > 0 else { return nil }
            let scale = min(1, 640 / image.size.width, 480 / image.size.height)
            // Cascade recovered pins so they do not cover each other exactly.
            let offset = Double(index % 10) * 32
            return PinRecord(id: file.id, x: 80 + offset, y: 80 + offset, width: image.size.width * scale, height: image.size.height * scale,
                opacity: 1, group: "", animated: manager.fileExists(atPath: pinFile(file.id, ".gif").path) ? true : nil)
        }
        try JSONEncoder().encode(recovered).write(to: pinIndex, options: .atomic)
        return recovered
    }

    func pinImage(for record: PinRecord) -> NSImage? {
        NSImage(contentsOf: pinFile(record.id, ".png")).map(Imaging.normalized)
    }

    func restorePins() throws -> [(PinRecord, NSImage)] {
        return try pinRecords().compactMap { record in
            guard let image = pinImage(for: record) else { return nil }
            return (record, image)
        }
    }
}
