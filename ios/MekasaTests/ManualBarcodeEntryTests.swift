import XCTest
@testable import Mekasa

/// Trash-station typed-UPC fallback (REQ-008 / UI-005 AC4).
final class ManualBarcodeEntryTests: XCTestCase {

    func testSanitize_keepsAsciiDigitsOnly() {
        XCTAssertEqual(ManualBarcodeEntry.sanitize("049000028911"), "049000028911")
        XCTAssertEqual(ManualBarcodeEntry.sanitize("0 4900-0028 911"), "049000028911")
        XCTAssertEqual(ManualBarcodeEntry.sanitize("abc123"), "123")
        XCTAssertEqual(ManualBarcodeEntry.sanitize("١٢٣456"), "456", "Non-ASCII digits are dropped")
        XCTAssertEqual(ManualBarcodeEntry.sanitize(""), "")
    }

    func testSanitize_capsAtGTIN14() {
        let long = String(repeating: "7", count: 20)
        XCTAssertEqual(ManualBarcodeEntry.sanitize(long).count, ManualBarcodeEntry.maxLength)
        XCTAssertEqual(ManualBarcodeEntry.maxLength, 14)
    }

    func testIsSubmittable_requiresAtLeastSixDigits() {
        XCTAssertEqual(ManualBarcodeEntry.minLength, 6)
        XCTAssertFalse(ManualBarcodeEntry.isSubmittable(""))
        XCTAssertFalse(ManualBarcodeEntry.isSubmittable("12345"))
        XCTAssertTrue(ManualBarcodeEntry.isSubmittable("123456"))
        XCTAssertTrue(ManualBarcodeEntry.isSubmittable("049000028911"))
        XCTAssertTrue(ManualBarcodeEntry.isSubmittable("00049000028911"))
    }

    func testIsSubmittable_rejectsUnsanitizedInput() {
        XCTAssertFalse(ManualBarcodeEntry.isSubmittable("0490 0002 8911"))
        XCTAssertFalse(ManualBarcodeEntry.isSubmittable("04900002891x"))
        XCTAssertFalse(ManualBarcodeEntry.isSubmittable(String(repeating: "1", count: 15)))
    }

    /// The same session path the camera uses handles a typed code.
    @MainActor
    func testTypedCode_consumesMatchingInventory() async {
        let session = AppSession()
        session.didSeedShoppingList = true
        session.addInventoryItem(
            InventoryItem(name: "Diet Coke", category: "Beverages", quantity: 2, barcode: "049000028911", source: .barcode)
        )
        let result = await session.consumeInventoryByBarcode(ManualBarcodeEntry.sanitize("0490 0002 8911"))
        guard case let .decremented(name, remaining) = result else {
            return XCTFail("Expected decremented, got \(result)")
        }
        XCTAssertEqual(name, "Diet Coke")
        XCTAssertEqual(remaining, 1)
    }
}
