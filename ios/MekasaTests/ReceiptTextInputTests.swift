import XCTest
@testable import Mekasa

/// Pasted-receipt text normalisation (REQ-005 AC7).
final class ReceiptTextInputTests: XCTestCase {

    func testNormalize_trimsLinesAndDropsBlanks() {
        let raw = "  BANANAS 1.29 \n\n\tWHOLE MILK 3.49\n   \nTOTAL 4.78\n"
        XCTAssertEqual(ReceiptTextInput.normalize(raw), "BANANAS 1.29\nWHOLE MILK 3.49\nTOTAL 4.78")
    }

    func testNormalize_handlesWindowsAndClassicMacLineEndings() {
        XCTAssertEqual(ReceiptTextInput.normalize("A 1\r\nB 2\rC 3"), "A 1\nB 2\nC 3")
    }

    func testNormalize_capsLength() {
        let raw = String(repeating: "EGGS 2.99\n", count: 2_000)
        XCTAssertEqual(ReceiptTextInput.normalize(raw).count, ReceiptTextInput.maxCharacters)
    }

    func testIsSubmittable_needsALineWithLetters() {
        XCTAssertFalse(ReceiptTextInput.isSubmittable(""))
        XCTAssertFalse(ReceiptTextInput.isSubmittable("   \n\n"))
        XCTAssertFalse(ReceiptTextInput.isSubmittable("1.29\n3.49\n9.77"), "Prices alone are not line items")
        XCTAssertTrue(ReceiptTextInput.isSubmittable("BANANAS 1.29"))
        XCTAssertTrue(ReceiptTextInput.isSubmittable("\n\n  milk  \n"))
    }

    func testLineCount_countsNonBlankLines() {
        XCTAssertEqual(ReceiptTextInput.lineCount(""), 0)
        XCTAssertEqual(ReceiptTextInput.lineCount("\n \n"), 0)
        XCTAssertEqual(ReceiptTextInput.lineCount("BANANAS 1.29"), 1)
        XCTAssertEqual(ReceiptTextInput.lineCount("BANANAS 1.29\n\nWHOLE MILK 3.49\nTOTAL 4.78"), 3)
    }
}
