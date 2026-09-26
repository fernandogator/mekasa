import XCTest
@testable import Mekasa

/// Layer 0: inventory search + category grouping + header summary (UI-006 AC6–AC7).
final class InventoryListModelTests: XCTestCase {
    private func item(
        _ name: String,
        category: String,
        quantity: Int = 2,
        threshold: Int = 1
    ) -> InventoryItem {
        InventoryItem(
            id: name.lowercased(),
            name: name,
            category: category,
            quantity: quantity,
            lowStockThreshold: threshold,
            source: .manual
        )
    }

    private var pantry: [InventoryItem] {
        [
            item("Whole Milk", category: "Dairy", quantity: 1),
            item("Cheddar", category: "Dairy"),
            item("Bananas", category: "Produce", quantity: 6),
            item("Cheerios", category: "Pantry", quantity: 0),
            item("Paper Towels", category: "Household"),
        ]
    }

    func testMatches_blankQueryMatchesEverything() {
        for row in pantry {
            XCTAssertTrue(InventoryListModel.matches(row, query: ""))
            XCTAssertTrue(InventoryListModel.matches(row, query: "   "))
        }
    }

    func testMatches_isCaseInsensitiveOnNameAndCategory() {
        let milk = item("Whole Milk", category: "Dairy")
        XCTAssertTrue(InventoryListModel.matches(milk, query: "milk"))
        XCTAssertTrue(InventoryListModel.matches(milk, query: "WHOLE"))
        XCTAssertTrue(InventoryListModel.matches(milk, query: "dai"))
        XCTAssertFalse(InventoryListModel.matches(milk, query: "snack"))
    }

    func testFilter_byCategoryReturnsWholeGroup() {
        let dairy = InventoryListModel.filter(pantry, query: "dairy").map(\.name)
        XCTAssertEqual(Set(dairy), ["Whole Milk", "Cheddar"])
    }

    func testSections_sortedByCategoryThenName() {
        let sections = InventoryListModel.sections(pantry)
        XCTAssertEqual(sections.map(\.category), ["Dairy", "Household", "Pantry", "Produce"])
        XCTAssertEqual(sections.first?.items.map(\.name), ["Cheddar", "Whole Milk"])
    }

    func testSections_queryDropsEmptyCategories() {
        let sections = InventoryListModel.sections(pantry, query: "che")
        XCTAssertEqual(sections.map(\.category), ["Dairy", "Pantry"])
        XCTAssertEqual(sections.flatMap { $0.items.map(\.name) }, ["Cheddar", "Cheerios"])
    }

    func testSections_noMatchesIsEmpty() {
        XCTAssertTrue(InventoryListModel.sections(pantry, query: "zzz").isEmpty)
        XCTAssertEqual(InventoryListModel.noMatchesMessage(query: " zzz "), "No items match “zzz”.")
    }

    func testSummary_countsWholeInventoryAndLowRows() {
        // Whole Milk (1 ≤ 1) and Cheerios (0 ≤ 1) are low; the rest are not.
        XCTAssertEqual(InventoryListModel.summary(pantry), "5 items · 2 low")
        XCTAssertEqual(InventoryListModel.summary([item("Eggs", category: "Dairy", quantity: 0)]), "1 item · 1 low")
        XCTAssertEqual(InventoryListModel.summary([]), "0 items · 0 low")
    }

    func testFixtures_groupIntoOneSectionPerCategory() {
        let sections = InventoryListModel.sections(TestFixtures.standardItemList)
        let categories = Set(TestFixtures.standardItemList.map(\.category))
        XCTAssertEqual(sections.count, categories.count)
        XCTAssertEqual(sections.map(\.category), sections.map(\.category).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        })
        XCTAssertEqual(
            InventoryListModel.sections(TestFixtures.standardItemList, query: "bananas").flatMap(\.items).map(\.name),
            ["Bananas"]
        )
    }
}
