import XCTest
@testable import Promecapt

final class NumericStepperTests: XCTestCase {
    func testNumericEntryClampsToTheCurrentToolRange() {
        XCTAssertEqual(NumericStepper.parsedValue("12", min: 1, max: 32), 12)
        XCTAssertEqual(NumericStepper.parsedValue("99", min: 1, max: 32), 32)
        XCTAssertEqual(NumericStepper.parsedValue("0", min: 1, max: 32), 1)
        XCTAssertEqual(NumericStepper.parsedValue("80", min: 2, max: 80), 80)
        XCTAssertNil(NumericStepper.parsedValue("text", min: 1, max: 32))
        XCTAssertNil(NumericStepper.parsedValue("1.5", min: 1, max: 32))
    }
    func testCaptureUsesCrosshairOnlyForAreaSelection() {
        XCTAssertEqual(CapturePointerStyle.forMode(selectingRegion: true, selectingOCR: false), .crosshair)
        XCTAssertEqual(CapturePointerStyle.forMode(selectingRegion: false, selectingOCR: false), .arrow)
        XCTAssertEqual(CapturePointerStyle.forMode(selectingRegion: false, selectingOCR: true), .crosshair)
    }
}
