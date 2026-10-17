// Verifies: REQ-024 AC1, AC2, AC5, AC7 · REQ-003 AC6, AC10, AC11
// Design: design/exports/superdesign/mobile/02-store-selection.html

import XCTest
@testable import Mekasa

/// Layer 0 coverage for per-store shopping lists and the store picker rules.
final class ShoppingStoresTests: XCTestCase {
    private let costco = SavedStore(id: "costco-1", name: "Costco Wholesale", address: "200 Warehouse Blvd", distanceMiles: 4.2)
    private let heb = SavedStore(id: "heb-1", name: "H-E-B", address: "100 Main St", distanceMiles: 1.4)

    private var saved: [SavedStore] { [costco, heb] }

    private var items: [ShoppingListItem] {
        [
            ShoppingListItem(id: "milk", name: "Milk", storeID: "costco-1"),
            ShoppingListItem(id: "eggs", name: "Eggs", isChecked: true, storeID: "costco-1"),
            ShoppingListItem(id: "tortillas", name: "Tortillas", storeID: "heb-1"),
            ShoppingListItem(id: "soap", name: "Dish soap"),
            ShoppingListItem(id: "old", name: "Batteries", storeID: "removed-store"),
            ShoppingListItem(
                id: "candy", name: "Candy", needsApproval: true, requestedBy: "Leo", kind: .request, storeID: "heb-1"
            ),
        ]
    }

    // MARK: - List membership (AC5)

    func testListKey_rowOnSavedStore() {
        XCTAssertEqual(ShoppingStores.listKey(for: "costco-1", saved: saved), "costco-1")
    }

    func testListKey_nilOrRemovedStoreIsAnyStore() {
        XCTAssertEqual(ShoppingStores.listKey(for: nil, saved: saved), ShoppingStores.anyStore)
        XCTAssertEqual(ShoppingStores.listKey(for: "removed-store", saved: saved), ShoppingStores.anyStore)
        XCTAssertEqual(ShoppingStores.listKey(for: "costco-1", saved: []), ShoppingStores.anyStore)
        XCTAssertEqual(ShoppingStores.anyStore, "any")
    }

    // MARK: - Filtering and counts (AC7)

    func testFilter_storeShowsOnlyItsRows() {
        XCTAssertEqual(ShoppingStores.filter(items, list: "costco-1", saved: saved).map(\.id), ["milk", "eggs"])
        XCTAssertEqual(ShoppingStores.filter(items, list: "heb-1", saved: saved).map(\.id), ["tortillas", "candy"])
    }

    func testFilter_anyStoreHoldsUnassignedAndRemovedStores() {
        XCTAssertEqual(ShoppingStores.filter(items, list: ShoppingStores.anyStore, saved: saved).map(\.id), ["soap", "old"])
    }

    func testFilter_allStoresShowsEverything() {
        XCTAssertEqual(ShoppingStores.filter(items, list: ShoppingStores.allStores, saved: saved), items)
    }

    func testCounts_onlyUncheckedRows() {
        let counts = ShoppingStores.counts(items, saved: saved)
        XCTAssertEqual(counts[ShoppingStores.allStores], 5)
        XCTAssertEqual(counts["costco-1"], 1)
        XCTAssertEqual(counts["heb-1"], 2)
        XCTAssertEqual(counts[ShoppingStores.anyStore], 2)
        XCTAssertEqual(ShoppingStores.count(items, list: "costco-1", saved: saved), 1)
    }

    func testTabs_allThenStoresThenAny() {
        let tabs = ShoppingStores.tabs(items, saved: saved)
        XCTAssertEqual(tabs.map(\.title), ["All stores", "Costco Wholesale", "H-E-B", "Any store"])
        XCTAssertEqual(tabs.map(\.count), [5, 1, 2, 2])
    }

    func testTabs_emptyWithoutSavedStores() {
        XCTAssertTrue(ShoppingStores.tabs(items, saved: []).isEmpty)
    }

    func testStoreNames() {
        XCTAssertEqual(ShoppingStores.storeName(for: "heb-1", saved: saved), "H-E-B")
        XCTAssertEqual(ShoppingStores.storeName(for: ShoppingStores.anyStore, saved: saved), "Any store")
        XCTAssertEqual(ShoppingStores.storeName(for: ShoppingStores.allStores, saved: saved), "All stores")
        XCTAssertEqual(ShoppingStores.rowStoreName(items[4], saved: saved), "Any store")
        XCTAssertEqual(ShoppingStores.rowStoreName(items[0], saved: saved), "Costco Wholesale")
    }

    func testNewItemStore_selectedStoreElseAnyStore() {
        XCTAssertEqual(ShoppingStores.storeIDForNewItem(selected: "heb-1", saved: saved), "heb-1")
        XCTAssertNil(ShoppingStores.storeIDForNewItem(selected: ShoppingStores.allStores, saved: saved))
        XCTAssertNil(ShoppingStores.storeIDForNewItem(selected: ShoppingStores.anyStore, saved: saved))
        XCTAssertNil(ShoppingStores.storeIDForNewItem(selected: "removed-store", saved: saved))
    }

    func testValidSelection_fallsBackToAllStores() {
        XCTAssertEqual(ShoppingStores.validSelection("heb-1", saved: saved), "heb-1")
        XCTAssertEqual(ShoppingStores.validSelection("heb-1", saved: [costco]), ShoppingStores.allStores)
        XCTAssertEqual(ShoppingStores.validSelection(ShoppingStores.anyStore, saved: []), ShoppingStores.anyStore)
    }

    // MARK: - Store picker (REQ-003 AC11)

    func testPreselection_ignoresBareStoreIDs() {
        let household = Household(
            id: "hh_1",
            name: "Casa",
            photoURL: nil,
            ownerUID: "uid_1",
            address: nil,
            latitude: nil,
            longitude: nil,
            storeIDs: ["stub-heb", "costco-1"],
            stores: [costco],
            createdAt: nil,
            updatedAt: nil
        )
        XCTAssertEqual(ShoppingStores.preselectedIDs(household), ["costco-1"])
        XCTAssertEqual(ShoppingStores.preselectedIDs(TestFixtures.previewHousehold), [])
        XCTAssertEqual(ShoppingStores.preselectedIDs(nil), [])
    }

    func testPickerStores_keepsSavedStoresMissingFromSearch() {
        let nearby = [
            Store(id: "heb-1", name: "H-E-B", address: "100 Main St", latitude: 0, longitude: 0, distanceMiles: 1.4, provider: "places"),
            Store(id: "target-1", name: "Target", address: "500 Circle Dr", latitude: 0, longitude: 0, distanceMiles: 6.0, provider: "places"),
        ]
        let rows = ShoppingStores.pickerStores(nearby: nearby, saved: [costco, heb])
        XCTAssertEqual(rows.map(\.id), ["heb-1", "costco-1", "target-1"])
    }

    func testFilterStores_byNameOrAddress() {
        XCTAssertEqual(ShoppingStores.filterStores(saved, query: "cost").map(\.id), ["costco-1"])
        XCTAssertEqual(ShoppingStores.filterStores(saved, query: "main st").map(\.id), ["heb-1"])
        XCTAssertEqual(ShoppingStores.filterStores(saved, query: "  ").count, 2)
    }

    func testSelectedStores_keepListOrder() {
        XCTAssertEqual(ShoppingStores.selectedStores(saved, selected: ["heb-1", "costco-1"]), [costco, heb])
    }

    func testMiles() {
        XCTAssertEqual(ShoppingStores.miles(1.4), "1.4 mi")
        XCTAssertEqual(ShoppingStores.miles(12.6), "13 mi")
        XCTAssertEqual(ShoppingStores.miles(nil), "")
    }

    // MARK: - API models

    func testHouseholdDecodes_withStores() throws {
        let json = """
        {
          "id": "hh_1",
          "owner_uid": "uid_1",
          "store_ids": ["costco-1", "stub-heb"],
          "stores": [
            {"id": "costco-1", "name": "Costco Wholesale", "address": "200 Warehouse Blvd", "distance_miles": 4.2}
          ]
        }
        """.data(using: .utf8)!
        let household = try JSONDecoder().decode(Household.self, from: json)
        XCTAssertEqual(household.storeIDs, ["costco-1", "stub-heb"])
        XCTAssertEqual(household.stores, [
            SavedStore(id: "costco-1", name: "Costco Wholesale", address: "200 Warehouse Blvd", distanceMiles: 4.2),
        ])
        XCTAssertFalse(household.hasCoordinates)
    }

    func testHouseholdDecodes_withoutStores() throws {
        let json = """
        {"id": "hh_1", "owner_uid": "uid_1", "store_ids": ["stub-heb"], "latitude": 30.2, "longitude": -97.7}
        """.data(using: .utf8)!
        let household = try JSONDecoder().decode(Household.self, from: json)
        XCTAssertEqual(household.stores, [])
        XCTAssertTrue(household.hasCoordinates)
    }

    func testStoreSearchResponse_needsLocation() throws {
        let missing = """
        {"household_id": "hh_1", "radius_miles": 15, "stores": [], "needs_location": true}
        """.data(using: .utf8)!
        XCTAssertTrue(try JSONDecoder().decode(StoreSearchResponse.self, from: missing).needsLocation)

        let older = """
        {"household_id": "hh_1", "radius_miles": 15, "stores": []}
        """.data(using: .utf8)!
        XCTAssertFalse(try JSONDecoder().decode(StoreSearchResponse.self, from: older).needsLocation)
    }

    func testShoppingListItemDTO_decodesStoreID() throws {
        let json = """
        {
          "id": "row-1", "household_id": "hh_1", "name": "Milk", "quantity": 2,
          "is_checked": false, "needs_approval": false, "kind": "custom", "store_id": "costco-1"
        }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(ShoppingListItemDTO.self, from: json)
        XCTAssertEqual(dto.storeId, "costco-1")
        XCTAssertEqual(dto.toLocal().storeID, "costco-1")
    }

    func testShoppingListItemDTO_missingStoreIDIsAnyStore() throws {
        let json = """
        {
          "id": "row-1", "household_id": "hh_1", "name": "Milk", "quantity": 2,
          "is_checked": false, "needs_approval": false, "kind": "auto", "store_id": null
        }
        """.data(using: .utf8)!
        let local = try JSONDecoder().decode(ShoppingListItemDTO.self, from: json).toLocal()
        XCTAssertNil(local.storeID)
        XCTAssertEqual(local.kind, .auto)
    }

    func testFirestoreShoppingRow_keepsStoreID() {
        let item = FirestoreDocumentMapper.shoppingListItem(
            id: "shop-1",
            data: ["name": "Milk", "quantity": 1, "store_id": "heb-1"]
        )
        XCTAssertEqual(item?.storeID, "heb-1")
        XCTAssertNil(FirestoreDocumentMapper.shoppingListItem(id: "shop-2", data: ["name": "Eggs"])?.storeID)
    }

    func testCreateBody_sendsStoreID() throws {
        let body = ShoppingListItemCreateBody(from: ShoppingListItem(name: "Milk", storeID: "costco-1"))
        let json = try XCTUnwrap(String(data: JSONEncoder().encode(body), encoding: .utf8))
        XCTAssertTrue(json.contains("\"store_id\":\"costco-1\""), json)
    }

    func testMoveBody_encodesExplicitNullToClear() throws {
        let cleared = try XCTUnwrap(String(data: JSONEncoder().encode(ShoppingListMoveBody(storeID: nil)), encoding: .utf8))
        XCTAssertEqual(cleared, "{\"store_id\":null}")
        let moved = try XCTUnwrap(String(data: JSONEncoder().encode(ShoppingListMoveBody(storeID: "heb-1")), encoding: .utf8))
        XCTAssertEqual(moved, "{\"store_id\":\"heb-1\"}")
    }

    func testStoreSelectionBody_sendsIDsAndDetailsInOrder() throws {
        let data = try JSONEncoder().encode(StoreSelectionBody(stores: [heb, costco]))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["store_ids"] as? [String], ["heb-1", "costco-1"])
        let details = try XCTUnwrap(object["stores"] as? [[String: Any]])
        XCTAssertEqual(details.map { $0["id"] as? String }, ["heb-1", "costco-1"])
        XCTAssertEqual(details.first?["distance_miles"] as? Double, 1.4)
    }

    // MARK: - Session (REQ-024 AC7)

    @MainActor
    func testAddAndMove_keepStoreID() throws {
        let session = AppSession()
        session.startUITesting()
        session.addCustomShoppingItem(name: "Paper plates", quantity: 1, storeID: "costco-1")
        let added = try XCTUnwrap(session.shoppingList.first)
        XCTAssertEqual(added.storeID, "costco-1")

        session.moveShoppingItem(id: added.id, toStoreID: nil)
        XCTAssertNil(session.shoppingList.first { $0.id == added.id }?.storeID)
        session.moveShoppingItem(id: added.id, toStoreID: "heb-1")
        XCTAssertEqual(session.shoppingList.first { $0.id == added.id }?.storeID, "heb-1")
    }

    @MainActor
    func testSaveStores_inPreviewUpdatesHousehold() async {
        let session = AppSession()
        session.startUITesting()
        let saved = await session.saveStores(PreviewFixtures.savedStores)
        XCTAssertTrue(saved)
        XCTAssertEqual(session.household?.stores, PreviewFixtures.savedStores)
        XCTAssertEqual(session.household?.storeIDs, PreviewFixtures.savedStores.map(\.id))
    }
}
