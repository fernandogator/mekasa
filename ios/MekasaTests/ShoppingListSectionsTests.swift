import XCTest
@testable import Mekasa

/// Layer 0 coverage for shopping list grouping, header summary and row chips
/// (REQ-011 AC4, REQ-012 AC4, REQ-014 AC2).
final class ShoppingListSectionsTests: XCTestCase {

    func testGroup_splitsPendingToBuyPurchased() {
        let grouped = ShoppingListSections.group(TestFixtures.standardShoppingList)
        XCTAssertEqual(grouped.pending.map(\.name), ["Paper towels"])
        XCTAssertEqual(grouped.toBuy.map(\.name), ["Eggs", "Avocados", "Dish soap"])
        XCTAssertEqual(grouped.purchased.map(\.name), ["2% milk"])
        XCTAssertFalse(grouped.isEmpty)
    }

    func testGroup_checkedRequestCountsAsPurchased() {
        let item = ShoppingListItem(
            name: "Candy", quantity: 1, isChecked: true, needsApproval: true, requestedBy: "Leo", kind: .request
        )
        let grouped = ShoppingListSections.group([item])
        XCTAssertEqual(grouped.purchased.count, 1)
        XCTAssertTrue(grouped.pending.isEmpty)
    }

    func testGroup_emptyList() {
        XCTAssertTrue(ShoppingListSections.group([]).isEmpty)
    }

    func testToBuySummary_countsOnlyApprovedUnchecked() {
        XCTAssertEqual(ShoppingListSections.toBuySummary(TestFixtures.standardShoppingList), "3 to buy")
        XCTAssertEqual(ShoppingListSections.toBuySummary(TestFixtures.singleShoppingItem), "1 to buy")
        XCTAssertEqual(ShoppingListSections.toBuySummary([]), "Nothing to buy")
        XCTAssertEqual(
            ShoppingListSections.toBuySummary([ShoppingListItem(name: "Milk", isChecked: true, kind: .auto)]),
            "Nothing to buy"
        )
    }

    func testChipLabel_autoRowsGetAutoChip() {
        XCTAssertEqual(ShoppingListSections.chipLabel(for: ShoppingListItem(name: "Eggs", kind: .auto)), "Auto")
        XCTAssertNil(ShoppingListSections.chipLabel(for: ShoppingListItem(name: "Avocados", kind: .custom)))
        XCTAssertEqual(
            ShoppingListSections.chipLabel(
                for: ShoppingListItem(name: "Candy", needsApproval: true, requestedBy: "Leo", kind: .request)
            ),
            "Needs approval"
        )
        // A checked-off request no longer needs approval and is not an auto row.
        XCTAssertNil(
            ShoppingListSections.chipLabel(
                for: ShoppingListItem(name: "Candy", isChecked: true, needsApproval: true, kind: .request)
            )
        )
    }

    func testPurchaseLockNotice_copy() {
        XCTAssertEqual(
            ShoppingListSections.purchaseLockNotice,
            "Only household owners can mark items purchased."
        )
    }
}
