import XCTest
@testable import Mekasa

/// Dashboard shopping teaser copy (UI-004 AC4).
final class ShoppingTeaserTests: XCTestCase {

    func testOpenItems_excludesCheckedOnly() {
        let open = ShoppingTeaser.openItems(TestFixtures.standardShoppingList)
        XCTAssertEqual(open.map(\.name), ["Paper towels", "Eggs", "Avocados", "Dish soap"])
    }

    func testHeadline_pluralises() {
        XCTAssertEqual(ShoppingTeaser.headline(TestFixtures.standardShoppingList), "4 items to pick up")
        XCTAssertEqual(ShoppingTeaser.headline(TestFixtures.singleShoppingItem), "1 item to pick up")
        XCTAssertEqual(ShoppingTeaser.headline([]), "List is clear")
        XCTAssertEqual(
            ShoppingTeaser.headline([ShoppingListItem(name: "Milk", isChecked: true, kind: .auto)]),
            "List is clear"
        )
    }

    func testPreview_limitsToThreeNames() {
        XCTAssertEqual(
            ShoppingTeaser.preview(TestFixtures.standardShoppingList),
            "Paper towels, Eggs, Avocados +1 more"
        )
        XCTAssertEqual(ShoppingTeaser.preview(TestFixtures.singleShoppingItem), "Bread")
        XCTAssertNil(ShoppingTeaser.preview([]))
        XCTAssertEqual(
            ShoppingTeaser.preview(TestFixtures.standardShoppingList, limit: 4),
            "Paper towels, Eggs, Avocados, Dish soap"
        )
    }
}
