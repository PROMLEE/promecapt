import XCTest
import AppKit
@testable import Promecapt

final class SaveOptionsTests: XCTestCase {
    private let seoul = TimeZone(identifier: "Asia/Seoul")!
    // 2026-11-23 11:41:05 UTC
    private let date = Date(timeIntervalSince1970: 1_795_434_065)

    func testSuggestedNameIsReadableAndSortable() {
        XCTAssertEqual(SaveFileName.suggested(extension: "png", date: date, timeZone: seoul), "Promecapt 2026-11-23 20.41.05.png")
        XCTAssertEqual(SaveFileName.suggested(extension: "gif", date: date, timeZone: TimeZone(identifier: "UTC")!), "Promecapt 2026-11-23 11.41.05.gif")
        XCTAssertFalse(SaveFileName.suggested(extension: "png", date: date).contains(":"))
    }

    func testReplacingExtensionKeepsTypedName() {
        XCTAssertEqual(SaveFileName.replacingExtension("Promecapt 2026-11-23 20.41.05.png", with: "jpg"), "Promecapt 2026-11-23 20.41.05.jpg")
        XCTAssertEqual(SaveFileName.replacingExtension("receipt.JPEG", with: "tiff"), "receipt.tiff")
        XCTAssertEqual(SaveFileName.replacingExtension("v1.2 notes", with: "png"), "v1.2 notes.png")
        XCTAssertEqual(SaveFileName.replacingExtension("", with: "png"), "")
    }

    func testFormatMatchingAndPreference() {
        XCTAssertEqual(ImageSaveFormat.matching(extension: "JPG"), .jpeg)
        XCTAssertEqual(ImageSaveFormat.matching(extension: "tif"), .tiff)
        XCTAssertNil(ImageSaveFormat.matching(extension: "gif"))
        let saved = UserDefaults.standard.object(forKey: DefaultsKey.imageSaveFormat)
        defer { UserDefaults.standard.set(saved, forKey: DefaultsKey.imageSaveFormat) }
        UserDefaults.standard.removeObject(forKey: DefaultsKey.imageSaveFormat)
        XCTAssertEqual(ImageSaveFormat.preferred, .png)
        ImageSaveFormat.preferred = .jpeg
        XCTAssertEqual(ImageSaveFormat.preferred, .jpeg)
        UserDefaults.standard.set("webp", forKey: DefaultsKey.imageSaveFormat)
        XCTAssertEqual(ImageSaveFormat.preferred, .png)
    }

    func testPanelControllerKeepsFormatAndNameInStep() {
        let controller = ImageSavePanelController(format: .png, date: date)
        XCTAssertTrue(controller.panel.nameFieldStringValue.hasSuffix(".png"))
        XCTAssertEqual(controller.panel.allowedContentTypes, [.png])
        XCTAssertNotNil(controller.panel.accessoryView)
        controller.select(.jpeg)
        XCTAssertTrue(controller.panel.nameFieldStringValue.hasSuffix(".jpg"))
        XCTAssertEqual(controller.panel.allowedContentTypes, [.jpeg])
        XCTAssertEqual(controller.format(for: URL(fileURLWithPath: "/tmp/a.tiff")), .tiff)
        XCTAssertEqual(controller.format(for: URL(fileURLWithPath: "/tmp/a")), .jpeg)
    }
}
