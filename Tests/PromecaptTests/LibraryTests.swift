import XCTest
import AppKit
@testable import Promecapt

final class LibraryTests: XCTestCase {
    func testHistorySurvivesReloadAndClear() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try Library(root: root)
        let image = Imaging.render(size: NSSize(width: 20, height: 10)) {
            NSColor.green.setFill(); NSRect(x: 0, y: 0, width: 20, height: 10).fill()
        }
        let entry = try store.add(image)
        let reloaded = try Library(root: root)
        XCTAssertEqual(reloaded.entries.first?.id, entry.id)
        XCTAssertNotNil(reloaded.image(entry))
        try reloaded.clearHistory()
        XCTAssertTrue(try Library(root: root).entries.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.historyURL(entry).path))
    }

    func testHistoryPrunesOldImages() throws {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: "historyLimit")
        defer { defaults.set(previous, forKey: "historyLimit") }
        defaults.set(2, forKey: "historyLimit")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try Library(root: root)
        let image = Imaging.render(size: NSSize(width: 2, height: 2)) { NSColor.red.setFill(); NSRect(x: 0, y: 0, width: 2, height: 2).fill() }
        let first = try store.add(image)
        try store.add(image)
        let last = try store.add(image)
        XCTAssertEqual(store.entries.count, 2)
        XCTAssertEqual(store.entries.first?.id, last.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.historyURL(first).path))
    }
}
