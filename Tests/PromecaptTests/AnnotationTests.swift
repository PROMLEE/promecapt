import XCTest
import AppKit
@testable import Promecapt

final class AnnotationTests: XCTestCase {
    func testOCRUsesOnlyTheRequestedRegionAndLeavesDocumentIntact() throws {
        let canvas = CanvasView(image: fixture())
        canvas.tool = .rectangle
        var recognizedSize: NSSize?
        canvas.beginOCRSelection(in: NSRect(x: 10, y: 10, width: 60, height: 50)) { recognizedSize = $0.size }
        XCTAssertTrue(canvas.isSelectingOCR)
        let crop = try XCTUnwrap(canvas.completeOCRSelection(NSRect(x: 20, y: 20, width: 25, height: 15)))
        XCTAssertEqual(crop.size, NSSize(width: 25, height: 15))
        XCTAssertEqual(recognizedSize, crop.size)
        XCTAssertFalse(canvas.isSelectingOCR)
        XCTAssertEqual(canvas.tool, .rectangle)
        XCTAssertTrue(canvas.document.objects.isEmpty)
        canvas.beginOCRSelection { _ in XCTFail("Cancelled selection must not run OCR") }
        XCTAssertTrue(canvas.cancelInteraction())
        XCTAssertFalse(canvas.isSelectingOCR)
    }
    func testTextCommitAndConsecutiveBadges() {
        let canvas = CanvasView(image: fixture())
        canvas.tool = .text
        canvas.beginText(at: NSPoint(x: 10, y: 10))
        canvas.activeTextInput?.stringValue = "한글 Promecapt"
        canvas.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification))
        XCTAssertNotNil(canvas.activeTextInput)
        canvas.flushText()
        XCTAssertEqual(canvas.document.objects.first?.text, "한글 Promecapt")
        XCTAssertEqual(canvas.document.objects.first?.tool, .text)
        canvas.tool = .number
        canvas.addNumber(at: NSPoint(x: 20, y: 20)); canvas.addNumber(at: NSPoint(x: 70, y: 20))
        XCTAssertEqual(canvas.document.objects.filter { $0.tool == .number }.map(\.text), ["1", "2"])
        XCTAssertEqual(canvas.nextNumber, 3)
    }
    private func fixture() -> NSImage {
        Imaging.render(size: NSSize(width: 100, height: 80)) {
            NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 100, height: 80).fill()
        }
    }
    private func rectangle() -> AnnotationObject {
        AnnotationObject(tool: .rectangle, points: [NSPoint(x: 10, y: 10), NSPoint(x: 50, y: 40)],
                         color: AnnotationColor(.red), lineWidth: 4, strength: 14, concealStyle: .mosaic)
    }
    func testSelectionMoveResizeAndUndoPreserveSource() throws {
        let source = fixture(), canvas = CanvasView(image: fixture()), object = rectangle()
        canvas.addAnnotation(object)
        let original = Imaging.png(canvas.image)
        XCTAssertNil(canvas.selectedID)
        canvas.tool = .select; canvas.selectAnnotation(object.id)
        XCTAssertEqual(canvas.tool, .select)
        XCTAssertEqual(canvas.selectedID, object.id)
        canvas.moveSelection(dx: 15, dy: 10)
        XCTAssertEqual(canvas.selectedAnnotation?.bounds.origin, NSPoint(x: 25, y: 20))
        canvas.undoEdit(); XCTAssertEqual(Imaging.png(canvas.image), original)
        canvas.redoEdit(); XCTAssertEqual(canvas.selectedAnnotation?.bounds.origin, NSPoint(x: 25, y: 20))
        canvas.resizeSelection(to: NSRect(x: 5, y: 5, width: 70, height: 50))
        XCTAssertEqual(canvas.selectedAnnotation?.bounds.size, NSSize(width: 70, height: 50))
        canvas.lineWidth = 12; canvas.color = .blue
        XCTAssertEqual(canvas.selectedAnnotation?.lineWidth, 12)
        XCTAssertEqual(canvas.selectedAnnotation?.color, AnnotationColor(.blue))
        XCTAssertEqual(Imaging.png(canvas.document.base), Imaging.png(source))
        canvas.deleteSelection(); XCTAssertEqual(Imaging.png(canvas.image), Imaging.png(source))
        canvas.undoEdit(); XCTAssertEqual(canvas.document.objects.count, 1)
    }
    func testObjectSerializationAndCaptureCrop() throws {
        let object = rectangle()
        let data = try JSONEncoder().encode([object])
        XCTAssertEqual(try JSONDecoder().decode([AnnotationObject].self, from: data), [object])
        let cropped = AnnotationDocument(base: fixture(), objects: [object]).cropped(to: NSRect(x: 5, y: 5, width: 80, height: 60))
        XCTAssertEqual(cropped.objects[0].bounds.origin, NSPoint(x: 5, y: 5))
        XCTAssertEqual(cropped.base.size, NSSize(width: 80, height: 60))
        XCTAssertTrue(object.contains(NSPoint(x: 10, y: 25), tolerance: 2))
        XCTAssertFalse(object.contains(NSPoint(x: 30, y: 25), tolerance: 2))
    }
}
