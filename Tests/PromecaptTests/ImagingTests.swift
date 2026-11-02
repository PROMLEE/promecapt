import XCTest
import AppKit
@testable import Promecapt

final class ImagingTests: XCTestCase {
    private func fixture() -> NSImage {
        Imaging.render(size: NSSize(width: 80, height: 40)) {
            NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: 40, height: 40).fill()
            NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1).setFill()
            NSRect(x: 40, y: 0, width: 40, height: 40).fill()
        }
    }

    private func channelValues<T: FixedWidthInteger>(_ count: Int, _ read: (UnsafeMutablePointer<T>) -> Void) -> [UInt] {
        var values = [T](repeating: 0, count: count)
        values.withUnsafeMutableBufferPointer { read($0.baseAddress!) }
        return values.map { UInt($0) }
    }
    private func pixel(_ image: NSImage, _ x: Int, _ y: Int) -> String {
        let rep = Imaging.bitmap(image)!
        let channels = channelValues(rep.samplesPerPixel) { rep.getPixel($0, atX: x, y: y) }
        return String(format: "#%02X%02X%02X", channels[0], channels[1], channels[2])
    }

    func testRenderPreservesPixelsAndPNGRoundTrip() throws {
        let image = fixture()
        let png = try XCTUnwrap(Imaging.png(image))
        let decoded = try XCTUnwrap(NSImage(data: png))
        let rep = try XCTUnwrap(Imaging.bitmap(decoded))
        XCTAssertEqual(rep.pixelsWide, 80)
        XCTAssertEqual(rep.pixelsHigh, 40)
        XCTAssertEqual(pixel(decoded, 10, 10), "#FF0000")
        XCTAssertEqual(pixel(decoded, 60, 10), "#0000FF")
    }

    func testTransformsAndCropPreserveContent() {
        let image = fixture()
        let flipped = Imaging.transformed(image, flipX: true)
        XCTAssertEqual(pixel(flipped, 10, 10), "#0000FF")
        XCTAssertEqual(pixel(flipped, 60, 10), "#FF0000")
        let rotated = Imaging.transformed(image, quarterTurns: 1)
        XCTAssertEqual(rotated.size, NSSize(width: 40, height: 80))
        let restored = Imaging.transformed(rotated, quarterTurns: -1)
        XCTAssertEqual(pixel(restored, 10, 10), "#FF0000")
        let cropped = Imaging.crop(image, rect: NSRect(x: 40, y: 0, width: 40, height: 40))
        XCTAssertEqual(cropped.size, NSSize(width: 40, height: 40))
        XCTAssertEqual(pixel(cropped, 10, 10), "#0000FF")
    }

    func testInvalidCropDoesNotDestroyImage() {
        let image = fixture()
        XCTAssertTrue(Imaging.crop(image, rect: .zero) === image)
        XCTAssertTrue(Imaging.crop(image, rect: NSRect(x: 1000, y: 1000, width: 10, height: 10)) === image)
    }

    func testColorParsingRejectsNonColorText() {
        XCTAssertEqual(Imaging.hex(Imaging.parseColor("  #2C77FF\n")!), "#2C77FF")
        for invalid in ["red", "#12345", "#GG0000", "123456", "#12345678"] {
            XCTAssertNil(Imaging.parseColor(invalid))
        }
    }

    func testUndoAndRedoRestorePixelContent() {
        let canvas = CanvasView(image: fixture())
        canvas.commit(Imaging.transformed(canvas.image, flipX: true))
        XCTAssertEqual(pixel(canvas.image, 10, 10), "#0000FF")
        canvas.undoEdit()
        XCTAssertEqual(pixel(canvas.image, 10, 10), "#FF0000")
        canvas.redoEdit()
        XCTAssertEqual(pixel(canvas.image, 10, 10), "#0000FF")
    }

    func testFiltersOnlyModifySelectedRegion() {
        let image = Imaging.render(size: NSSize(width: 80, height: 40)) {
            NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 80, height: 40).fill()
            NSColor.black.setFill(); NSRect(x: 20, y: 10, width: 4, height: 20).fill()
        }
        for mosaic in [true, false] {
            let result = Imaging.filtered(image, rect: NSRect(x: 10, y: 5, width: 30, height: 30), mosaic: mosaic)
            XCTAssertEqual(pixel(result, 60, 20), pixel(image, 60, 20))
            XCTAssertNotEqual(Imaging.png(result), Imaging.png(image))
            let gentle = Imaging.filtered(image, rect: NSRect(x: 10, y: 5, width: 30, height: 30), mosaic: mosaic, strength: 3)
            let strong = Imaging.filtered(image, rect: NSRect(x: 10, y: 5, width: 30, height: 30), mosaic: mosaic, strength: 35)
            XCTAssertNotEqual(Imaging.png(gentle), Imaging.png(strong))
            XCTAssertEqual(pixel(strong, 60, 20), pixel(image, 60, 20))
        }
    }

    func testDrawingThicknessAndConcealStrengthAreIndependent() {
        let canvas = CanvasView(image: fixture())
        canvas.tool = .rectangle
        canvas.adjustParameter(by: 3)
        XCTAssertEqual(canvas.lineWidth, 7)
        canvas.tool = .conceal
        canvas.adjustParameter(by: 3)
        XCTAssertEqual(canvas.effectStrength, 17)
        XCTAssertEqual(canvas.lineWidth, 7)
        canvas.concealStyle = .blackbox
        canvas.adjustParameter(by: 10)
        XCTAssertEqual(canvas.effectStrength, 17)
    }
}
