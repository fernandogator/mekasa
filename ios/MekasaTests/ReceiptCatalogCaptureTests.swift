import XCTest
@testable import Mekasa

/// Receipt lines resolved by a capture go back to the shared catalog with their
/// receipt text, so the next scan of the same receipt matches them.
/// Satisfies: REQ-RCP-007 AC5, REQ-RCP-020 AC6/AC7, REQ-RCP-021 AC3/AC7
/// Spec version: 1.0
final class ReceiptCatalogCaptureTests: XCTestCase {
    private let api = URL(string: "https://mekasa-api.example.run.app")!
    private let photoID = "0b5c7e4e-7f3e-4d0c-9c1e-6d2b8a9f1c22"

    func testScanResponseKeepsReceiptTextChainAndCatalogMatch() throws {
        let json = Data("""
        {"household_id": "h1", "engine": "gemini", "store_name": "H-E-B #412", "store_chain_id": "heb",
         "items": [
           {"name": "A2 Milk Whole", "category": "Dairy", "quantity": 1, "identified": true,
            "barcode": "0070852993188", "image_url": "/v1/product-photos/\(photoID)",
            "receipt_text": "A2 MLK WHL 59OZ", "receipt_code": null,
            "matched_product_id": "0070852993188", "match_method": "alias"},
           {"name": "Bananas", "category": "Produce", "quantity": 1, "identified": false,
            "receipt_text": "BANANAS"}
         ]}
        """.utf8)
        let dto = try JSONDecoder().decode(ReceiptScanResponseDTO.self, from: json)
        XCTAssertEqual(dto.storeChainId, "heb")
        XCTAssertEqual(dto.items[0].matchMethod, "alias")
        XCTAssertEqual(dto.items[0].matchedProductId, "0070852993188")

        let matched = dto.items[0].toLocal()
        XCTAssertTrue(matched.isIdentified)
        XCTAssertEqual(matched.receiptText, "A2 MLK WHL 59OZ")
        XCTAssertEqual(matched.imageURL, "/v1/product-photos/\(photoID)")
        XCTAssertEqual(dto.items[1].toLocal().receiptText, "BANANAS")
    }

    func testOlderScanResponseWithoutCatalogFieldsStillDecodes() throws {
        let json = Data("""
        {"household_id": "h1", "engine": "text",
         "items": [{"name": "Bananas", "category": "Produce", "quantity": 1, "identified": false}]}
        """.utf8)
        let dto = try JSONDecoder().decode(ReceiptScanResponseDTO.self, from: json)
        XCTAssertNil(dto.storeChainId)
        XCTAssertNil(dto.items[0].receiptText)
        XCTAssertNil(dto.items[0].matchMethod)
    }

    func testCatalogCaptureCodeAcceptsOnlyUpcAndPlu() {
        XCTAssertEqual(CatalogCaptureCode("4011"), .plu("4011"))
        XCTAssertEqual(CatalogCaptureCode("94011"), .plu("94011"))
        XCTAssertEqual(CatalogCaptureCode("04963406"), .upc("04963406"))
        XCTAssertEqual(CatalogCaptureCode("0070852993188"), .upc("0070852993188"))
        XCTAssertNil(CatalogCaptureCode("123456"), "6–7 digits are neither a PLU nor a UPC")
        XCTAssertNil(CatalogCaptureCode("123456789012345"))
        XCTAssertNil(CatalogCaptureCode("40a1"))
        XCTAssertNil(CatalogCaptureCode(""))
        XCTAssertNil(CatalogCaptureCode(nil))
    }

    func testCaptureBodySendsCodePhotoReceiptTextAndChainTogether() throws {
        let body = try XCTUnwrap(CatalogCaptureCode("0070852993188")).request(
            photoID: photoID,
            receiptText: "  A2 MLK WHL 59OZ ",
            storeChainId: "heb"
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: String]
        )
        XCTAssertEqual(object, [
            "upc": "0070852993188",
            "photo_id": photoID,
            "receipt_text": "A2 MLK WHL 59OZ",
            "store_chain_id": "heb",
        ])
    }

    func testPluCaptureWithoutPhotoOrTextOmitsThem() throws {
        let body = try XCTUnwrap(CatalogCaptureCode("4011")).request(photoID: nil, receiptText: "   ", storeChainId: nil)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: String]
        )
        XCTAssertEqual(object, ["plu_code": "4011"])
    }

    func testCaptureResponseDecodesUpdatedItem() throws {
        let json = Data("""
        {"outcome": "created", "photo_applied_as": "product_image", "scan_event_id": "e1",
         "confirmation_counted": true, "product": {"product_id": "0070852993188"},
         "inventory_item_id": "item_1",
         "inventory_item": {"id": "item_1", "household_id": "hh_1", "name": "A2 Milk Whole",
                            "category": "Dairy", "quantity": 1, "barcode": "0070852993188",
                            "image_url": "/v1/product-photos/\(photoID)", "source": "receipt"}}
        """.utf8)
        let dto = try JSONDecoder().decode(ProductCaptureResponseDTO.self, from: json)
        XCTAssertEqual(dto.outcome, "created")
        XCTAssertEqual(dto.photoAppliedAs, "product_image")
        XCTAssertEqual(dto.inventoryItem?.barcode, "0070852993188")
    }

    func testProductPhotoUploadDecodes() throws {
        let json = Data("""
        {"photo_id": "\(photoID)", "image_url": "/v1/product-photos/\(photoID)", "expires_at": null}
        """.utf8)
        let dto = try JSONDecoder().decode(ProductPhotoUploadDTO.self, from: json)
        XCTAssertEqual(dto.photoId, photoID)
        XCTAssertEqual(dto.imageUrl, "/v1/product-photos/\(photoID)")
    }

    func testRelativeProductPhotoResolvesOnApiHostAndLoadsWithToken() throws {
        let relative = try XCTUnwrap(URL(string: "/v1/product-photos/\(photoID)"))
        XCTAssertEqual(
            PrivateItemPhoto.resolve(relative, apiBaseURL: api).absoluteString,
            "https://mekasa-api.example.run.app/v1/product-photos/\(photoID)"
        )
        XCTAssertTrue(PrivateItemPhoto.isPrivate(relative, apiBaseURL: api))
        XCTAssertTrue(PrivateItemPhoto.isPrivate("https://mekasa-api.example.run.app/v1/product-photos/\(photoID)", apiBaseURL: api))
        XCTAssertFalse(PrivateItemPhoto.isPrivate("https://evil.example.com/v1/product-photos/\(photoID)", apiBaseURL: api))
        XCTAssertFalse(PrivateItemPhoto.isPrivate("/v1/product-photos/not-a-uuid", apiBaseURL: api))

        let offURL = try XCTUnwrap(URL(string: "https://images.openfoodfacts.org/x.jpg"))
        XCTAssertEqual(PrivateItemPhoto.resolve(offURL, apiBaseURL: api), offURL)
    }

    func testSharingNoticeIsRememberedPerUser() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ReceiptCatalogCaptureTests"))
        defaults.removePersistentDomain(forName: "ReceiptCatalogCaptureTests")
        XCTAssertFalse(ProductPhotoSharingNotice.hasSeen(uid: "u1", defaults: defaults))
        ProductPhotoSharingNotice.markSeen(uid: "u1", defaults: defaults)
        XCTAssertTrue(ProductPhotoSharingNotice.hasSeen(uid: "u1", defaults: defaults))
        XCTAssertFalse(ProductPhotoSharingNotice.hasSeen(uid: "u2", defaults: defaults))
        XCTAssertFalse(ProductPhotoSharingNotice.sheetCopy.contains("only"), "copy never says household-only")
    }
}
