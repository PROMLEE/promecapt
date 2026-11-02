import AppKit

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

final class Library {
    let root: URL
    private(set) var entries: [HistoryEntry] = []
    private let manager = FileManager.default
    var historyLimit: Int { max(1, UserDefaults.standard.object(forKey: "historyLimit") as? Int ?? 50) }

    init(root: URL? = nil) throws {
        self.root = root ?? manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Promepaste", isDirectory: true) // Preserve the existing library across the rename.
        try manager.createDirectory(at: self.root.appendingPathComponent("history"), withIntermediateDirectories: true)
        try manager.createDirectory(at: self.root.appendingPathComponent("pins"), withIntermediateDirectories: true)
        let index = self.root.appendingPathComponent("history.json")
        if manager.fileExists(atPath: index.path) {
            entries = try JSONDecoder().decode([HistoryEntry].self, from: Data(contentsOf: index))
            entries = entries.filter { manager.fileExists(atPath: historyURL($0).path) }
        }
    }

    func historyURL(_ entry: HistoryEntry) -> URL {
        root.appendingPathComponent("history").appendingPathComponent(entry.filename)
    }

    @discardableResult func add(_ image: NSImage, context: CaptureHistoryContext? = nil) throws -> HistoryEntry {
        guard let png = Imaging.png(image) else { throw CocoaError(.fileWriteUnknown) }
        let entry = HistoryEntry(id: UUID(), date: Date(), selection: context?.selection)
        try png.write(to: historyURL(entry), options: .atomic)
        if let context {
            guard let background = Imaging.png(context.image) else { throw CocoaError(.fileWriteUnknown) }
            try background.write(to: historyContextURL(entry), options: .atomic)
        }
        let next = Array(([entry] + entries).prefix(historyLimit))
        try JSONEncoder().encode(next).write(to: root.appendingPathComponent("history.json"), options: .atomic)
        let expired = entries.filter { old in !next.contains { $0.id == old.id } }
        entries = next
        for old in expired { try? manager.removeItem(at: historyURL(old)); try? manager.removeItem(at: historyContextURL(old)) }
        return entry
    }

    func clearHistory() throws {
        try JSONEncoder().encode([HistoryEntry]()).write(to: root.appendingPathComponent("history.json"), options: .atomic)
        let previous = entries
        entries = []
        for entry in previous { try manager.removeItem(at: historyURL(entry)); try? manager.removeItem(at: historyContextURL(entry)) }
    }

    func image(_ entry: HistoryEntry) -> NSImage? {
        NSImage(contentsOf: historyURL(entry)).map(Imaging.normalized)
    }

    func historyContextURL(_ entry: HistoryEntry) -> URL {
        root.appendingPathComponent("history/\(entry.id.uuidString)-screen.png")
    }
    func historyItem(_ entry: HistoryEntry) -> CaptureHistoryItem? {
        guard let image = image(entry) else { return nil }
        var item = CaptureHistoryItem(image: image)
        if let selection = entry.selection, let background = NSImage(contentsOf: historyContextURL(entry)) {
            item.context = CaptureHistoryContext(image: Imaging.normalized(background), selection: selection)
        }
        return item
    }
    func gifData(for record: PinRecord) -> Data? {
        guard record.animated == true else { return nil }
        return try? Data(contentsOf: root.appendingPathComponent("pins/\(record.id.uuidString).gif"))
    }

    func savePins(_ pins: [PinController], keeping deferred: [PinRecord] = []) throws {
        let currentRecords = try pins.map { pin -> PinRecord in
            guard let data = Imaging.png(pin.image) else { throw CocoaError(.fileWriteUnknown) }
            try data.write(to: root.appendingPathComponent("pins/\(pin.id.uuidString).png"), options: .atomic)
            if let document = pin.annotationDocument {
                guard let base = Imaging.png(document.base) else { throw CocoaError(.fileWriteUnknown) }
                try base.write(to: root.appendingPathComponent("pins/\(pin.id.uuidString)-base.png"), options: .atomic)
            }
            if let gif = pin.gifData { try gif.write(to: root.appendingPathComponent("pins/\(pin.id.uuidString).gif"), options: .atomic) }
            let frame = pin.window!.frame
            return PinRecord(id: pin.id, x: frame.minX, y: frame.minY, width: frame.width,
                height: frame.height, opacity: pin.window!.alphaValue, group: pin.group, annotations: pin.annotationDocument?.objects, animated: pin.gifData == nil ? nil : true)
        }
        let currentIDs = Set(currentRecords.map(\.id))
        let records = currentRecords + deferred.filter { !currentIDs.contains($0.id) }
        try JSONEncoder().encode(records).write(to: root.appendingPathComponent("pins.json"), options: .atomic)
        let live = Set(records.flatMap { ["\($0.id.uuidString).png"] + ($0.annotations == nil ? [] : ["\($0.id.uuidString)-base.png"]) + ($0.animated == true ? ["\($0.id.uuidString).gif"] : []) })
        for file in try manager.contentsOfDirectory(at: root.appendingPathComponent("pins"), includingPropertiesForKeys: nil) {
            if ["png", "gif"].contains(file.pathExtension) && !live.contains(file.lastPathComponent) { try manager.removeItem(at: file) }
        }
    }

    func annotationDocument(for record: PinRecord) -> AnnotationDocument? {
        guard let annotations = record.annotations,
              let base = NSImage(contentsOf: root.appendingPathComponent("pins/\(record.id.uuidString)-base.png")) else { return nil }
        return AnnotationDocument(base: Imaging.normalized(base), objects: annotations)
    }

    func pinRecords() throws -> [PinRecord] {
        let url = root.appendingPathComponent("pins.json")
        guard manager.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([PinRecord].self, from: Data(contentsOf: url))
    }

    func restorePins() throws -> [(PinRecord, NSImage)] {
        return try pinRecords().compactMap { record in
            guard let image = NSImage(contentsOf: root.appendingPathComponent("pins/\(record.id.uuidString).png")) else { return nil }
            return (record, Imaging.normalized(image))
        }
    }
}
