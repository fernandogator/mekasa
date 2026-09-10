import XCTest
@testable import Mekasa

final class Features2to6Tests: XCTestCase {
    func testReceiptLineItemDTOMapsLocal() throws {
        let json = """
        {"name":"Bananas","category":"Produce","quantity":1,"price_paid":1.29}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(ReceiptLineItemDTO.self, from: json)
        let local = dto.toLocal()
        XCTAssertEqual(local.name, "Bananas")
        XCTAssertEqual(local.pricePaid, 1.29)
        XCTAssertEqual(local.source, .receipt)
    }

    func testConsumeByBarcodeResultDecodesUnknown() throws {
        let json = """
        {
          "found": false,
          "item": null,
          "unknown_event": {
            "id": "e1",
            "household_id": "h1",
            "barcode": "000",
            "scanned_by_uid": "u1",
            "created_at": "2026-09-10T01:00:00Z"
          }
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(ConsumeByBarcodeResultDTO.self, from: json)
        XCTAssertFalse(dto.found)
        XCTAssertEqual(dto.unknownEvent?.barcode, "000")
    }

    @MainActor
    func testUpdateLowStockThresholdUpdatesLocalItem() {
        let session = AppSession()
        session.isUIPreview = true
        session.addInventoryItem(
            InventoryItem(name: "Milk", category: "Dairy", quantity: 2, lowStockThreshold: 1, source: .manual)
        )
        let id = session.inventory[0].id
        session.updateLowStockThreshold(itemID: id, threshold: 3)
        XCTAssertEqual(session.inventory[0].lowStockThreshold, 3)
    }
}
