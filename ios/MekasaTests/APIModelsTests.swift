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
}
