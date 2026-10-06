import XCTest
@testable import Mekasa

/// Unit coverage for duplicate grouping, survivor choice and merge (REQ-INV-021).
final class InventoryDuplicatesTests: XCTestCase {

    private let day: TimeInterval = 86_400

    private func item(
        _ id: String,
        _ name: String,
        category: String = "Produce",
        quantity: Int = 1,
        threshold: Int = 1,
        barcode: String? = nil,
        productId: String? = nil,
        imageURL: String? = nil,
        imageUpdatedAt: Date? = nil,
        updatedAt: Date = Date(timeIntervalSince1970: 1_000_000)
    ) -> InventoryItem {
        InventoryItem(
            id: id,
            name: name,
            category: category,
            quantity: quantity,
            lowStockThreshold: threshold,
            barcode: barcode,
            source: .manual,
            imageURL: imageURL,
            productId: productId,
            imageUpdatedAt: imageUpdatedAt,
            updatedAt: updatedAt
        )
    }

    // MARK: AC1 names

    func testDedupeName_exactAndSimplePlurals() {
        XCTAssertEqual(InventoryDuplicates.dedupeName("Organic Bananas"), "organic banana")
        XCTAssertEqual(InventoryDuplicates.dedupeName("  ORGANIC   banana! "), "organic banana")
        XCTAssertEqual(InventoryDuplicates.dedupeName("Berries"), "berry")
        XCTAssertEqual(InventoryDuplicates.dedupeName("Tomatoes"), "tomato")
        XCTAssertEqual(InventoryDuplicates.dedupeName("Peaches"), "peach")
        XCTAssertEqual(InventoryDuplicates.dedupeName("Jalapeño"), "jalapeno")
        XCTAssertEqual(InventoryDuplicates.dedupeName("Hummus"), "hummus")
        XCTAssertEqual(InventoryDuplicates.dedupeName("Glass"), "glass")
        XCTAssertEqual(InventoryDuplicates.dedupeName("Eggs"), "egg")
        XCTAssertEqual(InventoryDuplicates.dedupeName("Peas"), "pea")
        XCTAssertEqual(InventoryDuplicates.dedupeName("Gas"), "gas")
    }

    // MARK: AC1 groups

    func testFindGroups_sameNameNeedsSameCategory() {
        let groups = InventoryDuplicates.findGroups([
            item("a", "Banana"),
            item("b", "Bananas"),
            item("c", "Bananas", category: "Pantry"),
        ])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].reason, .sameName)
        XCTAssertEqual(Set(groups[0].items.map(\.id)), ["a", "b"])
    }

    func testFindGroups_chainsLinksAndUsesStrongestReason() {
        let groups = InventoryDuplicates.findGroups([
            item("a", "Oat Milk", category: "Dairy", barcode: "0123"),
            item("b", "Whole Milk", category: "Dairy", barcode: "0123"),
            item("c", "Whole Milk", category: "Dairy"),
            item("d", "Bread", category: "Pantry"),
        ])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].reason, .sameBarcode)
        XCTAssertEqual(Set(groups[0].items.map(\.id)), ["a", "b", "c"])
    }

    func testFindGroups_sameProduct() {
        let groups = InventoryDuplicates.findGroups([
            item("a", "Sourdough", category: "Pantry", productId: "llm:abc"),
            item("b", "Sourdough Loaf", category: "Bakery", productId: "llm:abc"),
        ])
        XCTAssertEqual(groups.map(\.reason), [.sameProduct])
    }

    func testFindGroups_noDuplicates() {
        XCTAssertTrue(InventoryDuplicates.findGroups([item("a", "Apples"), item("b", "Pears")]).isEmpty)
    }

    // MARK: AC2 survivor

    func testSurvivor_newestRealPhotoWins() {
        let base = Date(timeIntervalSince1970: 2_000_000)
        let old = item("old", "Bananas", imageURL: "https://x/old.jpg", imageUpdatedAt: base, updatedAt: base.addingTimeInterval(9 * day))
        let new = item("new", "Banana", imageURL: "https://x/new.jpg", imageUpdatedAt: base.addingTimeInterval(day), updatedAt: base)
        let placeholder = item("ph", "Bananas", imageURL: "https://placehold.co/96x96?text=B", updatedAt: base.addingTimeInterval(20 * day))
        XCTAssertEqual(InventoryDuplicates.pickSurvivor([old, new, placeholder])?.id, "new")
    }

    func testSurvivor_withoutPhotos_mostRecentlyUpdatedWins() {
        let base = Date(timeIntervalSince1970: 2_000_000)
        let survivor = InventoryDuplicates.pickSurvivor([
            item("a", "Bananas", updatedAt: base),
            item("b", "Bananas", updatedAt: base.addingTimeInterval(day)),
        ])
        XCTAssertEqual(survivor?.id, "b")
    }

    func testSurvivor_missingImageTimeFallsBackToUpdatedAt() {
        let base = Date(timeIntervalSince1970: 2_000_000)
        let survivor = InventoryDuplicates.pickSurvivor([
            item("a", "Bananas", imageURL: "https://x/a.jpg", updatedAt: base.addingTimeInterval(2 * day)),
            item("b", "Bananas", imageURL: "https://x/b.jpg", imageUpdatedAt: base.addingTimeInterval(day), updatedAt: base.addingTimeInterval(3 * day)),
        ])
        XCTAssertEqual(survivor?.id, "a")
    }

    // MARK: AC3 merge

    func testMerged_keepsHigherValuesAndFillsGaps() throws {
        var other = item("b", "Bananas", quantity: 5, threshold: 1, barcode: "4011", productId: "plu:4011")
        other.pricePaid = 1.29
        let group = DuplicateGroup(
            reason: .sameName,
            keepID: "a",
            items: [item("a", "Organic Bananas", quantity: 2, threshold: 3, imageURL: "https://x/a.jpg"), other]
        )
        let merged = try XCTUnwrap(InventoryDuplicates.merged(group))
        XCTAssertEqual(merged.id, "a")
        XCTAssertEqual(merged.name, "Organic Bananas")
        XCTAssertEqual(merged.quantity, 5)
        XCTAssertEqual(merged.lowStockThreshold, 3)
        XCTAssertEqual(merged.barcode, "4011")
        XCTAssertEqual(merged.productId, "plu:4011")
        XCTAssertEqual(merged.pricePaid, 1.29)
        XCTAssertEqual(merged.imageURL, "https://x/a.jpg")
    }

    func testMerged_survivorValuesAreNotOverwritten() throws {
        let group = DuplicateGroup(
            reason: .sameBarcode,
            keepID: "a",
            items: [item("a", "Milk", barcode: "111", productId: "111"), item("b", "Milk", barcode: "111", productId: "222")]
        )
        let merged = try XCTUnwrap(InventoryDuplicates.merged(group))
        XCTAssertEqual(merged.productId, "111")
    }

    // MARK: AC5 copy

    func testCopy() {
        XCTAssertEqual(InventoryDuplicates.headline(groupCount: 1), "1 group found · review before merging")
        XCTAssertEqual(InventoryDuplicates.headline(groupCount: 2), "2 groups found · review before merging")
        XCTAssertEqual(InventoryDuplicates.confirmation(count: 2, name: "Bananas"), "Merged 2 items into Bananas")

        let withPhoto = DuplicateGroup(
            reason: .sameName,
            keepID: "a",
            items: [item("a", "Bananas", quantity: 1, imageURL: "https://x/a.jpg"), item("b", "Banana", quantity: 3)]
        )
        XCTAssertEqual(InventoryDuplicates.resultDetail(withPhoto), "keeps qty 3 (higher) · newest photo")
        let noPhoto = DuplicateGroup(reason: .sameName, keepID: "a", items: [item("a", "Pears"), item("b", "Pear")])
        XCTAssertEqual(InventoryDuplicates.resultDetail(noPhoto), "keeps qty 1 (higher)")

        XCTAssertNil(InventoryDuplicates.bulkConfirmation([]))
        XCTAssertEqual(InventoryDuplicates.bulkConfirmation([withPhoto]), "Merged 2 items into Bananas")
        XCTAssertEqual(InventoryDuplicates.bulkConfirmation([withPhoto, noPhoto]), "Merged 4 items into 2 items")
    }

    func testPhotoAge() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func age(_ offset: TimeInterval, url: String? = "https://x/a.jpg") -> String {
            InventoryDuplicates.photoAge(
                item("a", "A", imageURL: url, imageUpdatedAt: now.addingTimeInterval(-offset)),
                now: now,
                calendar: calendar
            )
        }
        XCTAssertEqual(age(0), "Photo updated today")
        XCTAssertEqual(age(day), "Photo updated yesterday")
        XCTAssertEqual(age(2 * day), "Photo updated 2 days ago")
        XCTAssertEqual(age(0, url: nil), "No photo")
        XCTAssertEqual(age(0, url: "https://placehold.co/96"), "No photo")
    }

    // MARK: AC5 Not duplicates

    func testDismissedDuplicates_lapseWhenItemsChange() throws {
        let suite = "InventoryDuplicatesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let group = DuplicateGroup(reason: .sameName, keepID: "a", items: [item("a", "Pears"), item("b", "Pear")])
        let dismissed = DismissedDuplicates(householdID: "hh_1", defaults: defaults)
        dismissed.dismiss(group)
        XCTAssertTrue(dismissed.contains(group))
        XCTAssertTrue(dismissed.visible([group]).isEmpty)
        XCTAssertFalse(DismissedDuplicates(householdID: "hh_2", defaults: defaults).contains(group))

        let changed = DuplicateGroup(
            reason: .sameName,
            keepID: "a",
            items: [item("a", "Pears"), item("b", "Pear", updatedAt: Date(timeIntervalSince1970: 3_000_000))]
        )
        XCTAssertFalse(dismissed.contains(changed))
    }

    // MARK: API models

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func itemJSON(_ id: String, imageUpdatedAt: String? = nil) -> String {
        let imageTime = imageUpdatedAt.map { "\"\($0)\"" } ?? "null"
        return """
        {
          "id": "\(id)",
          "household_id": "hh_1",
          "name": "Bananas",
          "category": "Produce",
          "quantity": 3,
          "low_stock_threshold": 1,
          "price_paid": null,
          "barcode": null,
          "image_url": "https://x/\(id).jpg",
          "image_updated_at": \(imageTime),
          "product_id": null,
          "source": "manual",
          "created_by_uid": "uid_1",
          "updated_by_uid": "uid_1",
          "created_at": "2026-09-08T02:00:00Z",
          "updated_at": "2026-09-08T02:00:00Z"
        }
        """
    }

    func testDuplicatesResponseDecodes() throws {
        let json = """
        {
          "household_id": "hh_1",
          "groups": [
            {"reason": "same_name", "keep_id": "a", "items": [\(itemJSON("a", imageUpdatedAt: "2026-09-10T00:00:00Z")), \(itemJSON("b"))]}
          ]
        }
        """.data(using: .utf8)!
        let response = try decoder().decode(InventoryDuplicatesResponseDTO.self, from: json)
        let group = try XCTUnwrap(response.groups.first?.toLocal())
        XCTAssertEqual(group.reason, .sameName)
        XCTAssertEqual(group.survivor?.id, "a")
        XCTAssertEqual(group.survivor?.imageUpdatedAt, ISO8601DateFormatter().date(from: "2026-09-10T00:00:00Z"))
        XCTAssertNil(group.others.first?.imageUpdatedAt)
    }

    func testMergeResponseDecodes() throws {
        let json = """
        {
          "household_id": "hh_1",
          "item": \(itemJSON("a")),
          "removed_ids": ["b"],
          "shopping_list_items": []
        }
        """.data(using: .utf8)!
        let response = try decoder().decode(InventoryMergeResponseDTO.self, from: json)
        XCTAssertEqual(response.item.id, "a")
        XCTAssertEqual(response.removedIds, ["b"])
        XCTAssertTrue(response.shoppingListItems.isEmpty)
    }

    // MARK: AC6 local merge

    @MainActor
    func testLocalMerge_updatesInventoryAndRelinksShoppingList() async throws {
        let session = AppSession()
        session.isUIPreview = true
        session.inventory = [
            item("x", "Bread", category: "Pantry"),
            item("a", "Bananas", quantity: 1, imageURL: "https://x/a.jpg"),
            item("b", "Banana", quantity: 4),
        ]
        session.shoppingList = [ShoppingListItem(id: "s1", name: "Banana", inventoryItemID: "b", kind: .auto)]

        let found = await session.findDuplicateGroups()
        let group = try XCTUnwrap(try found.get().first)
        XCTAssertEqual(group.keepID, "a")

        let result = await session.mergeDuplicateGroup(group)
        XCTAssertEqual(try result.get(), "Merged 2 items into Bananas")
        XCTAssertEqual(session.inventory.map(\.id), ["x", "a"])
        XCTAssertEqual(session.inventory.last?.quantity, 4)
        XCTAssertEqual(session.shoppingList.first?.inventoryItemID, "a")
    }
}
