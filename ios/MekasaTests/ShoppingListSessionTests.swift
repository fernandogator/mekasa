import XCTest
@testable import Mekasa

/// Unit coverage for local shopping list (REQ-011–014 client path).
final class ShoppingListSessionTests: XCTestCase {

    @MainActor
    func testEnsureSeeded_loadsDemoWhenEmpty() {
        let session = AppSession()
        session.ensureShoppingListSeeded()
        XCTAssertEqual(session.shoppingList.count, ShoppingListFixtures.demo.count)
        session.ensureShoppingListSeeded()
        XCTAssertEqual(session.shoppingList.count, ShoppingListFixtures.demo.count)
    }

    @MainActor
    func testSyncFromInventory_autoAddsLowStock() {
        let session = AppSession()
        session.didSeedShoppingList = true
        session.addInventoryItem(
            InventoryItem(name: "Pasta", category: "Pantry", quantity: 1, lowStockThreshold: 1, source: .manual)
        )
        XCTAssertTrue(session.shoppingList.contains { $0.name == "Pasta" && $0.kind == .auto })
    }

    @MainActor
    func testToggleChecked_marksPurchased() {
        let session = AppSession()
        session.didSeedShoppingList = true
        session.addCustomShoppingItem(name: "Tortillas", quantity: 2)
        let id = session.shoppingList[0].id
        session.toggleShoppingItemChecked(id: id)
        XCTAssertTrue(session.shoppingList[0].isChecked)
    }

    @MainActor
    func testApproveAndRejectRequest() {
        let session = AppSession()
        session.didSeedShoppingList = true
        session.shoppingList = [
            ShoppingListItem(name: "Candy", quantity: 1, needsApproval: true, requestedBy: "Leo", kind: .request)
        ]
        let id = session.shoppingList[0].id
        session.approveShoppingRequest(id: id)
        XCTAssertFalse(session.shoppingList[0].needsApproval)

        session.shoppingList = [
            ShoppingListItem(name: "Soda", quantity: 1, needsApproval: true, requestedBy: "Mia", kind: .request)
        ]
        let rejectID = session.shoppingList[0].id
        session.rejectShoppingRequest(id: rejectID)
        XCTAssertTrue(session.shoppingList.isEmpty)
    }
}
