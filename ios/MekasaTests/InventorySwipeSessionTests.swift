import XCTest
@testable import Mekasa

/// Unit coverage for swipe Use 1 / Remove + Undo (REQ-INV-014–017).
final class InventorySwipeSessionTests: XCTestCase {

    @MainActor
    func testDeductOne_whenQuantityGreaterThanOne() {
        let session = AppSession()
        session.isUIPreview = true
        session.inventory = [
            InventoryItem(id: "a", name: "Milk", category: "Dairy", quantity: 3, source: .manual)
        ]
        let result = session.consumeInventoryItem(id: "a")
        if case let .decremented(_, remaining) = result {
            XCTAssertEqual(remaining, 2)
        } else {
            XCTFail("expected decremented")
        }
        XCTAssertEqual(session.inventory.first?.quantity, 2)
        XCTAssertFalse(session.showInventoryUndoToast)
    }

    @MainActor
    func testSoftRemove_showsUndoAndRestoresPosition() {
        let session = AppSession()
        session.isUIPreview = true
        session.inventory = [
            InventoryItem(id: "1", name: "Avocados", category: "Produce", quantity: 1, source: .manual),
            InventoryItem(id: "2", name: "Bread", category: "Pantry", quantity: 2, source: .manual),
        ]
        session.softRemoveInventoryItem(id: "1")
        XCTAssertEqual(session.inventory.map(\.id), ["2"])
        XCTAssertTrue(session.showInventoryUndoToast)

        session.undoInventoryRemove()
        XCTAssertEqual(session.inventory.map(\.id), ["1", "2"])
        XCTAssertFalse(session.showInventoryUndoToast)
    }

    func testMapper_skipsSoftDeletedDocs() {
        let item = FirestoreDocumentMapper.inventoryItem(
            id: "x",
            data: [
                "name": "Gone",
                "category": "Other",
                "quantity": 1,
                "deleted": true,
            ]
        )
        XCTAssertNil(item)
    }
}
