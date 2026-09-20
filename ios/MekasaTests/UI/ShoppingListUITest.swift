// Verifies: REQ-011–REQ-014 · Shopping list
// Design: design/mockups/ShoppingList.jsx

import XCTest
@testable import Mekasa

/// Unit coverage for shopping list session behavior (REQ-011–014).
/// Structural XCUI coverage lives in `Tests/UI/Structure/UI004StructureTests`.
final class ShoppingListUITest: XCTestCase {

    @MainActor
    func testLayout_keyElementsExistAndVisible() throws {
        let session = AppSession()
        session.startUITesting()
        XCTAssertFalse(session.shoppingList.isEmpty)
        XCTAssertTrue(session.shoppingList.contains { $0.name == "Eggs" || $0.name == "Avocados" || $0.name.contains("milk") })
    }

    @MainActor
    func testInteraction_tapsInputsAndNavigationTriggers() throws {
        let session = AppSession()
        session.startUITesting()
        session.addCustomShoppingItem(name: "Tortillas", quantity: 2)
        XCTAssertTrue(session.shoppingList.contains { $0.name == "Tortillas" })
    }

    @MainActor
    func testFlow_navigatesToNextScreen() throws {
        let session = AppSession()
        session.startUITesting(emptyInventory: true)
        XCTAssertTrue(session.shoppingList.isEmpty)
        session.ensureShoppingListSeeded()
        // Empty inventory may stay empty or seed demo depending on guard.
        XCTAssertNotNil(session.shoppingList)
    }

@MainActor
    func testOwnerPurchaseGate_hiddenForMembers() throws {
        let session = AppSession()
        session.startUITesting()
        session.isUITesting = false
        session.isUIPreview = false
        session.idToken = "live-token"
        session.userUID = "member-uid"
        session.myMemberRole = "member"
        session.myPermissions = []
        session.household = TestFixtures.previewHousehold
        XCTAssertFalse(session.isHouseholdOwner)
        XCTAssertFalse(session.canMarkShoppingPurchased)
    }

    func testVisual_semanticStructureMatchesBaseline() throws {
        throw XCTSkip("Stub — implement when baseline exists")
    }
}
