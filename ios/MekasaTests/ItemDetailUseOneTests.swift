import XCTest
@testable import Mekasa

/// Item detail "Use 1" status copy (REQ-009 parity with the Android row action).
final class ItemDetailUseOneTests: XCTestCase {

    func testUseOneMessage_perResult() {
        XCTAssertEqual(
            ItemDetailView.useOneMessage(for: .decremented(name: "Eggs", remaining: 2)),
            "Used 1 — 2 left"
        )
        XCTAssertEqual(
            ItemDetailView.useOneMessage(for: .depleted(name: "Eggs")),
            "Marked gone — now on the shopping list if it’s tracked"
        )
        XCTAssertNil(ItemDetailView.useOneMessage(for: .unknown))
    }

    @MainActor
    func testConsumeFromDetail_matchesSessionPath() {
        let session = AppSession()
        session.didSeedShoppingList = true
        session.addInventoryItem(
            InventoryItem(name: "Eggs", category: "Dairy", quantity: 1, lowStockThreshold: 1, source: .manual)
        )
        let id = session.inventory[0].id

        let result = session.consumeInventoryItem(id: id)
        XCTAssertEqual(ItemDetailView.useOneMessage(for: result), "Marked gone — now on the shopping list if it’s tracked")
        XCTAssertEqual(session.inventory[0].quantity, 0)
        XCTAssertTrue(session.shoppingList.contains { $0.name == "Eggs" && $0.kind == .auto })
    }
}
