import UIKit
import XCTest
@testable import Mekasa

/// In-store capture copy + code checks for unidentified receipt lines (REQ-004 / REQ-005).
final class CaptureGuidanceTests: XCTestCase {

    func testMessage_namesTheStoreWhenKnown() {
        XCTAssertEqual(
            CaptureGuidance.message(itemName: "Bananas", storeName: "HEB"),
            "We could not find the HEB Bananas. Please scan the item and take a picture."
        )
    }

    func testMessage_fallsBackWithoutStore() {
        XCTAssertEqual(
            CaptureGuidance.message(itemName: " Bananas ", storeName: "  "),
            "We could not find Bananas in the catalog. Please scan the item and take a picture."
        )
        XCTAssertEqual(
            CaptureGuidance.message(itemName: "Bananas", storeName: nil),
            "We could not find Bananas in the catalog. Please scan the item and take a picture."
        )
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

    func testReceiptScanResponse_decodesStoreContext() throws {
        let json = Data("""
        {"household_id": "h1", "engine": "gemini", "store_id": "heb", "store_name": "HEB",
         "items": [{"name": "Bananas", "category": "Produce", "quantity": 1, "price_paid": 0.62,
                    "identified": false, "store_item_id": "heb-bananas"}]}
        """.utf8)
        let dto = try JSONDecoder().decode(ReceiptScanResponseDTO.self, from: json)
        XCTAssertEqual(dto.storeId, "heb")
        XCTAssertEqual(dto.storeName, "HEB")
        XCTAssertEqual(dto.items.first?.storeItemId, "heb-bananas")
    }

    func testReceiptScanResponse_toleratesMissingStoreFields() throws {
        let json = Data("""
        {"household_id": "h1", "engine": "text",
         "items": [{"name": "Bananas", "category": "Produce", "quantity": 1, "identified": false}]}
        """.utf8)
        let dto = try JSONDecoder().decode(ReceiptScanResponseDTO.self, from: json)
        XCTAssertNil(dto.storeId)
        XCTAssertNil(dto.items.first?.storeItemId)
    }
}
