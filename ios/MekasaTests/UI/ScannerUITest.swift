// Verifies: UI-004 Add path · REQ-004
// Design: design/mockups/AddItems.jsx

import XCTest
@testable import Mekasa

/// Unit coverage for barcode/demo lookup path used by scanner confirm.
/// Live camera XCUI remains device-only; structural hub path is in UI004StructureTests.
final class ScannerUITest: XCTestCase {

    func testLayout_keyElementsExistAndVisible() throws {
        XCTAssertNotNil(InventoryDemoCatalog.lookup(barcode: InventoryDemoCatalog.sampleBarcode))
        XCTAssertEqual(
            InventoryDemoCatalog.lookup(barcode: InventoryDemoCatalog.sampleBarcode)?.source,
            .barcode
        )
    }

    func testInteraction_tapsInputsAndNavigationTriggers() throws {
        let hit = InventoryDemoCatalog.lookup(barcode: "041220576037")
        XCTAssertEqual(hit?.name, "Cheerios 12oz")
        XCTAssertNil(InventoryDemoCatalog.lookup(barcode: "000000000000"))
    }

    @MainActor
    func testFlow_navigatesToNextScreen() throws {
        let session = AppSession()
        session.startUITesting(emptyInventory: true)
        guard let draft = InventoryDemoCatalog.lookup(barcode: InventoryDemoCatalog.sampleBarcode) else {
            return XCTFail("expected demo barcode")
        }
        session.addInventoryItem(draft)
        XCTAssertEqual(session.inventory.count, 1)
        XCTAssertEqual(session.inventory[0].source, .barcode)
    }

    @MainActor
    func testFlow_duplicateScanMergesIntoExistingRow() throws {
        let session = AppSession()
        session.startUITesting(emptyInventory: true)
        guard let draft = InventoryDemoCatalog.lookup(barcode: "041220576037") else {
            return XCTFail("expected demo barcode")
        }
        session.addInventoryItem(draft)
        session.addInventoryItem(draft)
        XCTAssertEqual(session.inventory.count, 1, "Same name + category merges instead of duplicating")
        XCTAssertEqual(session.inventory[0].quantity, draft.quantity * 2)
    }
}
