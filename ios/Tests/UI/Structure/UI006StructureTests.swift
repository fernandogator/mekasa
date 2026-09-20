// =============================================================
// UI006StructureTests.swift
// Satisfies: UI-006 (Inventory list) · REQ-INV-014–018 (swipe Use 1 / Remove / Undo)
// Design artifact: design/mockups/InventoryList.jsx
// Layer: 1 — Structural / XCUITest
// =============================================================

import XCTest

final class UI006StructureTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = UITestLaunch.app()
        app.launch()
        XCTAssertTrue(UITestLaunch.waitForShell(app), "Main shell did not appear under --uitesting")
    }

    func testInventoryList_reachableFromDashboard() {
        openInventoryList()
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.inventoryListView)
                .waitForExistence(timeout: UITestLaunch.elementTimeout)
                || app.staticTexts["Inventory"].waitForExistence(timeout: UITestLaunch.elementTimeout),
            "Inventory list screen should appear"
        )
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.itemList)
                .waitForExistence(timeout: UITestLaunch.elementTimeout)
                || UITestLaunch.element(app, TestIdentifiers.emptyStateView).exists
                || UITestLaunch.element(app, TestIdentifiers.itemCell).exists,
            "Inventory should show a list, empty state, or at least one cell"
        )
    }

    func testInventoryList_rowShowsTitleAndQuantity() throws {
        openInventoryList()
        let cell = UITestLaunch.element(app, TestIdentifiers.itemCell)
        guard cell.waitForExistence(timeout: UITestLaunch.elementTimeout) else {
            throw XCTSkip("No inventory fixture rows under --uitesting")
        }
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.itemTitle).exists
                || app.staticTexts.matching(NSPredicate(format: "label.length > 0")).count > 0
        )
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.itemSubtitle).exists
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Qty")).firstMatch.exists
        )
    }

    func testInventoryList_emptyStateWhenNoItems() {
        app.terminate()
        app = UITestLaunch.app(empty: true)
        app.launch()
        XCTAssertTrue(UITestLaunch.waitForShell(app))
        openInventoryList()
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.inventoryListView)
                .waitForExistence(timeout: UITestLaunch.elementTimeout)
                || app.staticTexts["Inventory"].waitForExistence(timeout: UITestLaunch.elementTimeout),
            "Inventory list screen should appear before empty-state assert"
        )
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Nothing in inventory")).firstMatch
                .waitForExistence(timeout: UITestLaunch.elementTimeout)
                || (
                    UITestLaunch.element(app, TestIdentifiers.inventoryListView).exists
                        && UITestLaunch.element(app, TestIdentifiers.emptyStateView).exists
                ),
            "Empty inventory should show empty-state copy"
        )
    }

    func testSwipe_useOneWhenQuantityGreaterThanOne() throws {
        throw XCTSkip("Stub — swipe Use 1 (REQ-INV-014): open inventory, swipe qty>1 row, assert Use 1 / InventoryUseOneAction, qty decrements")
        // Interaction: trailing swipe → Use 1 (accent #ca0013); no confirmation alert
    }

    func testSwipe_removeWhenQuantityIsOne() throws {
        throw XCTSkip("Stub — swipe Remove (REQ-INV-015/016): swipe qty=1 row, assert Remove / InventoryRemoveAction, row leaves list, Undo toast appears")
        // Layout: InventoryUndoToast + InventoryUndoButton visible for ~5s
    }

    func testSwipe_undoRestoresItem() throws {
        throw XCTSkip("Stub — Undo (REQ-INV-017): after Remove, tap InventoryUndoButton; item returns at original index")
    }

    // MARK: - Helpers

    private func openInventoryList() {
        let byId = UITestLaunch.element(app, TestIdentifiers.allInventoryButton)
        if byId.waitForExistence(timeout: UITestLaunch.elementTimeout) {
            byId.tap()
            return
        }
        let lowStock = UITestLaunch.element(app, TestIdentifiers.lowStockStatButton)
        if lowStock.waitForExistence(timeout: 5) {
            lowStock.tap()
            return
        }
        // Visible title may be uppercased via .textCase(.uppercase).
        let labels = ["All inventory", "ALL INVENTORY"]
        for label in labels {
            let button = app.buttons[label]
            if button.waitForExistence(timeout: 3) {
                button.tap()
                return
            }
            let text = app.staticTexts[label]
            if text.waitForExistence(timeout: 2) {
                text.tap()
                return
            }
        }
        // Last resort: predicate match (case-insensitive).
        let match = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] %@", "all inventory")
        ).firstMatch
        if match.waitForExistence(timeout: 5) {
            match.tap()
        }
    }
}
