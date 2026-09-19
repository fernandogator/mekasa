import XCTest
@testable import Mekasa

/// Unit coverage for Firestore doc → local model mapping (REQ-020).
final class FirestoreDocumentMapperTests: XCTestCase {

    func testInventoryItem_mapsCoreFields() {
        let item = FirestoreDocumentMapper.inventoryItem(
            id: "inv-1",
            data: [
                "name": "Milk",
                "category": "Dairy",
                "quantity": 2,
                "low_stock_threshold": 1,
                "price_paid": 3.49,
                "barcode": "123",
                "source": "barcode",
                "image_url": "https://example.com/m.jpg",
                "updated_at": Date(timeIntervalSince1970: 1_700_000_000),
            ]
        )
        XCTAssertEqual(item?.id, "inv-1")
        XCTAssertEqual(item?.name, "Milk")
        XCTAssertEqual(item?.quantity, 2)
        XCTAssertEqual(item?.source, .barcode)
        XCTAssertEqual(item?.barcode, "123")
        XCTAssertEqual(item?.imageURL, "https://example.com/m.jpg")
    }

    func testShoppingListItem_mapsFlags() {
        let item = FirestoreDocumentMapper.shoppingListItem(
            id: "shop-1",
            data: [
                "name": "Eggs",
                "quantity": 1,
                "quantity_label": "×1 dozen",
                "is_checked": false,
                "needs_approval": true,
                "requested_by": "Maya",
                "kind": "request",
            ]
        )
        XCTAssertEqual(item?.name, "Eggs")
        XCTAssertEqual(item?.needsApproval, true)
        XCTAssertEqual(item?.kind, .request)
        XCTAssertEqual(item?.requestedBy, "Maya")
        XCTAssertEqual(item?.displayQuantity, "×1 dozen")
    }

    func testInventoryItem_rejectsMissingName() {
        XCTAssertNil(FirestoreDocumentMapper.inventoryItem(id: "x", data: ["quantity": 1]))
    }
}
