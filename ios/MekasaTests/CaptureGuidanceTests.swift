import UIKit
import XCTest
@testable import Mekasa

/// In-store capture copy + code checks for unidentified receipt lines (REQ-004 / REQ-005).
final class CaptureGuidanceTests: XCTestCase {

    func testMessage_asksForLocalStoreItem() {
        XCTAssertEqual(
            CaptureGuidance.message(storeName: " H-E-B "),
            "This looks like a local H-E-B item. Scan its barcode and take a picture so Mekasa recognizes it next time."
        )
    }

    func testMessage_fallsBackWithoutStore() {
        let expected = "This looks like a local item. Scan its barcode and take a picture so Mekasa recognizes it next time."
        XCTAssertEqual(CaptureGuidance.message(storeName: "  "), expected)
        XCTAssertEqual(CaptureGuidance.message(storeName: nil), expected)
    }

    func testActionTitle() {
        XCTAssertEqual(CaptureGuidance.actionTitle, "Scan & photograph")
    }

    func testCodes_acceptPLUAndGTIN() {
        XCTAssertTrue(CaptureGuidance.isValidCode("4011"), "Produce PLU")
        XCTAssertTrue(CaptureGuidance.isValidCode("078742370545"))
        XCTAssertFalse(CaptureGuidance.isValidCode("401"))
        XCTAssertFalse(CaptureGuidance.isValidCode("40 11"))
        XCTAssertEqual(CaptureGuidance.sanitizeCode(" 0787-4237 0545 "), "078742370545")
        XCTAssertEqual(CaptureGuidance.sanitizeCode(String(repeating: "1", count: 20)).count, 14)
    }

    func testPhotoEncoding_downscalesLargeImages() throws {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let big = UIGraphicsImageRenderer(size: CGSize(width: 4000, height: 3000), format: format).image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4000, height: 3000))
        }
        let data = try XCTUnwrap(ItemPhotoEncoding.jpegData(from: big))
        let decoded = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(max(decoded.size.width, decoded.size.height), ItemPhotoEncoding.maxDimension)
    }

    func testReceiptScanResponse_decodesStoreName() throws {
        let json = Data("""
        {"household_id": "h1", "engine": "gemini", "store_name": "HEB",
         "items": [{"name": "Bananas", "category": "Produce", "quantity": 1, "price_paid": 0.62,
                    "identified": false}]}
        """.utf8)
        let dto = try JSONDecoder().decode(ReceiptScanResponseDTO.self, from: json)
        XCTAssertEqual(dto.storeName, "HEB")
        XCTAssertEqual(dto.items.first?.identified, false)
    }

    func testReceiptScanResponse_ignoresRetiredStoreFields() throws {
        // Older API revisions sent store_id / store_item_id (prototype store tables); decoding stays tolerant.
        let json = Data("""
        {"household_id": "h1", "engine": "gemini", "store_id": "heb", "store_name": "HEB",
         "items": [{"name": "Bananas", "category": "Produce", "quantity": 1,
                    "identified": false, "store_item_id": "heb-bananas"}]}
        """.utf8)
        let dto = try JSONDecoder().decode(ReceiptScanResponseDTO.self, from: json)
        XCTAssertEqual(dto.storeName, "HEB")
        XCTAssertEqual(dto.items.count, 1)
    }

    func testReceiptScanResponse_toleratesMissingStoreName() throws {
        let json = Data("""
        {"household_id": "h1", "engine": "text",
         "items": [{"name": "Bananas", "category": "Produce", "quantity": 1, "identified": false}]}
        """.utf8)
        let dto = try JSONDecoder().decode(ReceiptScanResponseDTO.self, from: json)
        XCTAssertNil(dto.storeName)
    }

    func testReceiptStoreContext_onlyCarriesStoreName() {
        let context = ReceiptStoreContext(storeName: "HEB")
        XCTAssertEqual(
            CaptureGuidance.message(storeName: context.storeName),
            "This looks like a local HEB item. Scan its barcode and take a picture so Mekasa recognizes it next time."
        )
    }
}
