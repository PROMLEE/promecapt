import XCTest
import AppKit
@testable import Promecapt

final class SelectionTests: XCTestCase {
    func testSelectionCanMoveResizeAndExportRetinaCoordinates() {
        var selection = CaptureSelection(bounds: NSRect(x: 0, y: 0, width: 800, height: 600))
        selection.begin(at: NSPoint(x: 200, y: 150))
        selection.update(to: NSPoint(x: 100, y: 50))
        XCTAssertEqual(selection.rect, NSRect(x: 100, y: 50, width: 100, height: 100))
        XCTAssertEqual(selection.pixelRect(imageSize: NSSize(width: 1600, height: 1200)), NSRect(x: 200, y: 100, width: 200, height: 200))
        selection.begin(at: NSPoint(x: 150, y: 100))
        selection.update(to: NSPoint(x: 790, y: 590))
        XCTAssertEqual(selection.rect, NSRect(x: 700, y: 500, width: 100, height: 100))
        selection.begin(at: NSPoint(x: 700, y: 500))
        selection.update(to: NSPoint(x: 650, y: 450))
        XCTAssertEqual(selection.rect, NSRect(x: 650, y: 450, width: 150, height: 150))
        for handle in CaptureSelection.Handle.allCases {
            XCTAssertEqual(selection.handle(at: selection.point(for: handle)), handle)
        }
    }
}
