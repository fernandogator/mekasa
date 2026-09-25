// Verifies: UI-006 (Inventory list thumbnails + item detail + swipe)
// AC1–AC5 · REQ-INV-014–018
// Design: design/mockups/InventoryList.jsx, design/mockups/ItemDetail.jsx
// Samples: design/pages/inventory-list.html, design/pages/item-detail.html
//
// 3-layer coverage:
//   Layer 1 — Tests/UI/Structure/UI006StructureTests.swift
//   Layer 2 — Tests/Snapshots/UI006SnapshotTests.swift
//   Layer 3 — Scripts/ui_vision_cases.json + Scripts/verify_ui_vision.py

import XCTest
@testable import Mekasa

/// Layer 0: inventory list / detail state exercised through `AppSession` with the
/// same fixtures `InventoryListView` renders under `--uitesting`.
final class InventoryScreenUITest: XCTestCase {

    @MainActor
    func testLayout_rowShowsThumbnailOrPlaceholder() {
        let session = AppSession()
        session.startUITesting()

        XCTAssertEqual(session.inventory.count, TestFixtures.standardItemList.count)
        // Every fixture row has a thumbnail URL; the view falls back to a placeholder when nil.
        XCTAssertTrue(session.inventory.allSatisfy { $0.imageURL?.isEmpty == false })
        // Subtitle shows "Qty N · Category" — categories must be display-cased raw values.
        for item in session.inventory {
            XCTAssertNotNil(InventoryCategory(rawValue: item.category), "\(item.name) category should be a known display value")
        }
        // The list is sorted by name; "Bananas" (qty 6) and "Cheerios 12oz" (qty 1) drive swipe tests.
        let sorted = session.inventory.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        XCTAssertEqual(sorted.first?.name, "Bananas")
        XCTAssertEqual(sorted.first?.quantity, 6)
        XCTAssertEqual(sorted.dropFirst().first?.name, "Cheerios 12oz")
        XCTAssertEqual(sorted.dropFirst().first?.quantity, 1)
    }

    @MainActor
    func testInteraction_tapRowOpensItemDetail() {
        let session = AppSession()
        session.startUITesting()

        // Row tap navigates by item id; detail resolves the row from the session.
        let target = session.inventory.first { $0.name == "Organic Oat Milk" }
        XCTAssertNotNil(target)
        XCTAssertEqual(session.inventory.first { $0.id == target?.id }?.barcode, "012345678905")

        // Detail threshold stepper writes back through the session (clamped at 0).
        session.updateLowStockThreshold(itemID: target!.id, threshold: -3)
        XCTAssertEqual(session.inventory.first { $0.id == target!.id }?.lowStockThreshold, 0)
        session.updateLowStockThreshold(itemID: target!.id, threshold: 5)
        let updated = session.inventory.first { $0.id == target!.id }
        XCTAssertEqual(updated?.lowStockThreshold, 5)
        XCTAssertEqual(updated?.isLowStock, true, "qty 2 with threshold 5 is low stock")
        XCTAssertTrue(
            session.shoppingList.contains { $0.inventoryItemID == target!.id && !$0.isChecked },
            "Low-stock row auto-appears on the shopping list (REQ-011)"
        )
    }

    @MainActor
    func testFlow_detailShowsHeroAndOpensLightbox() {
        let session = AppSession()
        session.startUITesting()

        // Hero image is the live product URL for a barcode-sourced row.
        let coke = session.inventory.first { $0.barcode == "049000028911" }
        XCTAssertEqual(coke?.source, .barcode)
        XCTAssertEqual(coke?.imageURL?.hasPrefix("https://"), true)
        XCTAssertNotNil(coke?.imageURL.flatMap(URL.init(string:)), "Lightbox needs a loadable URL")
    }

    @MainActor
    func testInteraction_swipeUseOneDecrementsQuantity() {
        let session = AppSession()
        session.startUITesting()
        let bananas = session.inventory.first { $0.name == "Bananas" }!
        XCTAssertEqual(bananas.quantity, 6)

        let result = session.consumeInventoryItem(id: bananas.id)
        guard case let .decremented(name, remaining) = result else {
            return XCTFail("qty > 1 should decrement, got \(result)")
        }
        XCTAssertEqual(name, "Bananas")
        XCTAssertEqual(remaining, 5)
        XCTAssertEqual(session.inventory.first { $0.id == bananas.id }?.quantity, 5)
        XCTAssertFalse(session.showInventoryUndoToast, "Use 1 never shows the Undo toast (REQ-INV-014)")
    }

    @MainActor
    func testInteraction_swipeRemoveShowsUndoToast() {
        let session = AppSession()
        session.startUITesting()
        let cheerios = session.inventory.first { $0.name == "Cheerios 12oz" }!
        XCTAssertEqual(cheerios.quantity, 1)
        let before = session.inventory.count

        session.softRemoveInventoryItem(id: cheerios.id)
        XCTAssertEqual(session.inventory.count, before - 1)
        XCTAssertFalse(session.inventory.contains { $0.id == cheerios.id })
        XCTAssertTrue(session.showInventoryUndoToast, "Remove shows the Undo toast (REQ-INV-015/016)")
        XCTAssertEqual(session.activity.first?.title, "Removed Cheerios 12oz")
    }

    @MainActor
    func testFlow_undoRestoresRemovedItem() {
        let session = AppSession()
        session.startUITesting()
        let ids = session.inventory.map(\.id)
        let cheerios = session.inventory.first { $0.name == "Cheerios 12oz" }!
        let originalIndex = ids.firstIndex(of: cheerios.id)!

        session.softRemoveInventoryItem(id: cheerios.id)
        session.undoInventoryRemove()

        XCTAssertEqual(session.inventory.map(\.id), ids, "Undo restores the row at its original index (REQ-INV-017)")
        XCTAssertEqual(session.inventory.firstIndex { $0.id == cheerios.id }, originalIndex)
        XCTAssertFalse(session.showInventoryUndoToast)

        // Undo with nothing pending is a no-op.
        session.undoInventoryRemove()
        XCTAssertEqual(session.inventory.map(\.id), ids)
    }
}
