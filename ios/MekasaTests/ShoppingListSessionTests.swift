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

    /// REQ-012 AC4: any member can remove a row, no owner role required.
    @MainActor
    func testRemoveShoppingItem_removesRowForNonOwner() {
        let session = AppSession()
        session.didSeedShoppingList = true
        session.shoppingList = TestFixtures.standardShoppingList
        let before = session.activity.count

        session.removeShoppingItem(id: "shop-4")

        XCTAssertFalse(session.shoppingList.contains { $0.id == "shop-4" })
        XCTAssertEqual(session.shoppingList.count, TestFixtures.standardShoppingList.count - 1)
        XCTAssertEqual(session.activity.count, before + 1)
        XCTAssertEqual(session.activity.first?.title, "Removed Avocados from list")
        XCTAssertNil(session.lastError)
    }

    /// REQ-012: a teen is asked for what they want, and the row waits for an owner.
    @MainActor
    func testTeenRequest_needsOwnerApproval() {
        let session = AppSession()
        session.didSeedShoppingList = true
        session.userUID = "teen-user"
        session.displayName = "Nico"
        session.myMemberRole = "teen"
        session.household = Household(
            id: "family-house",
            name: "Guerrero Home",
            photoURL: nil,
            ownerUID: "owner-user",
            address: nil,
            latitude: nil,
            longitude: nil,
            storeIDs: [],
            createdAt: nil,
            updatedAt: nil
        )

        XCTAssertTrue(session.submitsShoppingRequests)
        XCTAssertFalse(session.isHouseholdOwner)

        session.addCustomShoppingItem(name: "Oreos", quantity: 1)

        let item = try XCTUnwrap(session.shoppingList.first)
        XCTAssertEqual(item.name, "Oreos")
        XCTAssertTrue(item.needsApproval)
        XCTAssertEqual(item.kind, .request)
        XCTAssertEqual(item.requestedBy, "Nico")
        XCTAssertFalse(item.isChecked)
    }

    /// Owners add straight onto the list. Preview mode is treated as an owner.
    @MainActor
    func testOwnerAdd_isNotARequest() {
        let session = ownerSession()
        XCTAssertFalse(session.submitsShoppingRequests)
        session.addCustomShoppingItem(name: "Tortillas", quantity: 1)
        let item = try XCTUnwrap(session.shoppingList.first)
        XCTAssertEqual(item.name, "Tortillas")
        XCTAssertFalse(item.needsApproval)
        XCTAssertEqual(item.kind, .custom)
        XCTAssertNil(item.requestedBy)
    }

    @MainActor
    func testRemoveShoppingItem_unknownIDIsNoOp() {
        let session = AppSession()
        session.didSeedShoppingList = true
        session.shoppingList = TestFixtures.standardShoppingList

        session.removeShoppingItem(id: "does-not-exist")

        XCTAssertEqual(session.shoppingList, TestFixtures.standardShoppingList)
    }
}
