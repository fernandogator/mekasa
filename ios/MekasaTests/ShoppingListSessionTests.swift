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

    /// Purchase / approve / deny are owner-only (REQ-014); a bare session has no role,
    /// so these run as the local owner the way preview mode does.
    @MainActor
    private func ownerSession() -> AppSession {
        let session = AppSession()
        session.isUIPreview = true
        session.didSeedShoppingList = true
        return session
    }

    @MainActor
    func testToggleChecked_marksPurchased() {
        let session = ownerSession()
        session.addCustomShoppingItem(name: "Tortillas", quantity: 2)
        let id = session.shoppingList[0].id
        session.toggleShoppingItemChecked(id: id)
        XCTAssertTrue(session.shoppingList[0].isChecked)
        XCTAssertNil(session.lastError)
    }

    @MainActor
    func testToggleChecked_blockedForNonOwner() {
        let session = AppSession()
        session.didSeedShoppingList = true
        session.shoppingList = [ShoppingListItem(name: "Tortillas", quantity: 2)]
        session.toggleShoppingItemChecked(id: session.shoppingList[0].id)
        XCTAssertFalse(session.shoppingList[0].isChecked)
        XCTAssertEqual(session.lastError, "Only household owners can mark items purchased.")
    }

    @MainActor
    func testApproveAndRejectRequest() {
        let session = ownerSession()
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
