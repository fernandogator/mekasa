import XCTest
@testable import Mekasa

/// Decodes thin API payloads used by onboarding.
final class APIModelsTests: XCTestCase {
    func testHouseholdDecodesSnakeCase() throws {
        let json = """
        {
          "id": "hh_1",
          "name": "Casa",
          "photo_url": null,
          "owner_uid": "uid_1",
          "address": "1842 Magnolia Ave",
          "latitude": 30.27,
          "longitude": -97.74,
          "store_ids": ["stub-heb"],
          "created_at": "2026-09-07T00:00:00Z",
          "updated_at": "2026-09-07T00:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let household = try decoder.decode(Household.self, from: json)
        XCTAssertEqual(household.id, "hh_1")
        XCTAssertEqual(household.ownerUID, "uid_1")
        XCTAssertEqual(household.storeIDs, ["stub-heb"])
        XCTAssertEqual(household.address, "1842 Magnolia Ave")
    }

    func testStoreSearchResponseDecodes() throws {
        let json = """
        {
          "household_id": "hh_1",
          "radius_miles": 15,
          "stores": [
            {
              "id": "stub-heb",
              "name": "H-E-B",
              "address": "100 Main",
              "latitude": 30.27,
              "longitude": -97.74,
              "distance_miles": 0.8,
              "provider": "stub"
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(StoreSearchResponse.self, from: json)
        XCTAssertEqual(response.householdId, "hh_1")
        XCTAssertEqual(response.radiusMiles, 15)
        XCTAssertEqual(response.stores.first?.name, "H-E-B")
    }

    func testPreviewFixturesHaveStores() {
        XCTAssertGreaterThanOrEqual(PreviewFixtures.nearbyStores.count, 3)
        XCTAssertEqual(PreviewFixtures.household().id, "preview-household")
    }

    func testInventoryItemDTODecodesAndMapsLocal() throws {
        let json = """
        {
          "id": "item_1",
          "household_id": "hh_1",
          "name": "Whole Milk",
          "category": "Dairy",
          "quantity": 2,
          "low_stock_threshold": 1,
          "price_paid": 3.49,
          "barcode": "041220576037",
          "source": "manual",
          "created_by_uid": "uid_1",
          "updated_by_uid": "uid_1",
          "created_at": "2026-09-08T02:00:00.123456Z",
          "updated_at": "2026-09-08T02:00:00.123456Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = fractional.date(from: value) ?? plain.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: value)
        }
        let dto = try decoder.decode(InventoryItemDTO.self, from: json)
        XCTAssertEqual(dto.householdId, "hh_1")
        XCTAssertEqual(dto.lowStockThreshold, 1)
        let local = dto.toLocal()
        XCTAssertEqual(local.name, "Whole Milk")
        XCTAssertEqual(local.quantity, 2)
        XCTAssertEqual(local.source, .manual)
        XCTAssertEqual(local.barcode, "041220576037")
    }

    func testInventoryListResponseDecodes() throws {
        let json = """
        {
          "household_id": "hh_1",
          "items": []
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(InventoryListResponse.self, from: json)
        XCTAssertEqual(response.householdId, "hh_1")
        XCTAssertTrue(response.items.isEmpty)
    }

    func testShoppingListItemDTODecodes() throws {
        let json = """
        {
          "id": "sl_1",
          "household_id": "hh_1",
          "name": "Bananas",
          "quantity": 3,
          "quantity_label": null,
          "is_checked": false,
          "needs_approval": false,
          "requested_by": null,
          "inventory_item_id": "item_1",
          "kind": "auto",
          "created_by_uid": "uid_1",
          "updated_by_uid": "uid_1",
          "created_at": "2026-09-08T02:00:00Z",
          "updated_at": "2026-09-08T02:00:00Z"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(ShoppingListItemDTO.self, from: json)
        let local = dto.toLocal()
        XCTAssertEqual(local.name, "Bananas")
        XCTAssertEqual(local.kind, .auto)
        XCTAssertEqual(local.inventoryItemID, "item_1")
    }
}
