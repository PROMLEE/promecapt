import XCTest
import AppKit
@testable import Promecapt

final class ShortcutTests: XCTestCase {
    func testFunctionKeyPicker() throws {
        let f1 = try XCTUnwrap(Shortcut.functionKey(1))
        XCTAssertEqual(f1.keyCode, 122)
        XCTAssertEqual(f1.modifiers, 0)
        XCTAssertEqual(f1.display, "F1")
        XCTAssertEqual(Shortcut(keyCode: 122, flags: .function), f1)
        XCTAssertEqual(Set((1...20).compactMap(Shortcut.functionKey)).count, 20)
        XCTAssertNil(Shortcut.functionKey(0))
        XCTAssertNil(Shortcut.functionKey(21))
    }
    func testImageCommandsUsePhysicalKeys() {
        XCTAssertEqual(ImageKeyboardCommand.resolve(keyCode: 8, flags: .command), .copy)
        XCTAssertEqual(ImageKeyboardCommand.resolve(keyCode: 6, flags: [.command,.shift]), .redo)
        XCTAssertNil(ImageKeyboardCommand.resolve(keyCode: 8, flags: []))
    }
    func testCustomBindingsAndDuplicateValidation() throws {
        let binding = Shortcut(keyCode: 12, flags: [.control,.option,.shift,.command])
        XCTAssertEqual(binding.display, "⌃⌥⇧⌘Q")
        XCTAssertEqual(try JSONDecoder().decode(Shortcut.self, from: JSONEncoder().encode(binding)), binding)
        XCTAssertNotNil(ShortcutPreferences.duplicate(in: [.capture: binding, .paste: binding]))
        XCTAssertNil(ShortcutPreferences.duplicate(in: [.capture: binding]))
        XCTAssertFalse(Shortcut(keyCode: 8, flags: []).isValid)
    }
    func testClipboardHasPNGAndTIFF() throws {
        let board = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        defer { board.releaseGlobally() }
        let image = Imaging.render(size: NSSize(width: 80, height: 40)) {
            NSColor.black.setFill(); NSRect(x: 0, y: 0, width: 80, height: 40).fill()
        }
        XCTAssertTrue(copyImage(image, to: board))
        XCTAssertTrue(board.types?.contains(.png) == true)
        XCTAssertTrue(board.types?.contains(.tiff) == true)
        let pasted = try XCTUnwrap(NSImage(pasteboard: board))
        XCTAssertEqual(Imaging.bitmap(pasted)?.pixelsWide, 80)
        XCTAssertEqual(Imaging.bitmap(pasted)?.pixelsHigh, 40)
    }
}
