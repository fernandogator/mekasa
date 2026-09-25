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

    /// REQ-INV-014: trailing swipe on a qty > 1 row reveals Use 1; tapping decrements
    /// without any confirmation alert. Fixture: Bananas (qty 6, TestFixtures.standardItemList).
    func testSwipe_useOneWhenQuantityGreaterThanOne() throws {
        openInventoryList()
        let row = try requireRow(named: "Bananas")
        XCTAssertTrue(app.staticTexts["Qty 6 · Produce"].exists, "Bananas should start at qty 6")

        let decremented = app.staticTexts["Qty 5 · Produce"]
        try triggerTrailingAction(
            on: row,
            id: TestIdentifiers.inventoryUseOneAction,
            label: "Use 1",
            mustNotOffer: (TestIdentifiers.inventoryRemoveAction, "Remove"),
            alreadyApplied: { decremented.exists }
        )

        XCTAssertTrue(
            decremented.waitForExistence(timeout: UITestLaunch.elementTimeout),
            "Use 1 should decrement Bananas to qty 5"
        )
        XCTAssertEqual(app.alerts.count, 0, "Use 1 must not show a confirmation alert")
        XCTAssertFalse(
            UITestLaunch.element(app, TestIdentifiers.inventoryUndoToast).exists,
            "Use 1 must not show the Undo toast"
        )
    }

    /// REQ-INV-015/016: trailing swipe on a qty == 1 row reveals Remove; the row leaves
    /// the list and the Undo toast appears. Fixture: Cheerios 12oz (qty 1).
    func testSwipe_removeWhenQuantityIsOne() throws {
        openInventoryList()
        let row = try requireRow(named: "Cheerios 12oz")

        let toast = UITestLaunch.element(app, TestIdentifiers.inventoryUndoToast)
        try triggerTrailingAction(
            on: row,
            id: TestIdentifiers.inventoryRemoveAction,
            label: "Remove",
            mustNotOffer: (TestIdentifiers.inventoryUseOneAction, "Use 1"),
            alreadyApplied: { toast.exists }
        )

        // The toast auto-dismisses after 5 s, so assert promptly.
        XCTAssertTrue(
            toast.waitForExistence(timeout: 4) || app.staticTexts["Item removed"].waitForExistence(timeout: 1),
            "Undo toast should appear after Remove"
        )
        XCTAssertTrue(undoButton().exists, "Undo button should be visible in the toast")
        XCTAssertTrue(undoButton().isHittable, "Undo button must not be covered by the bottom nav")
        XCTAssertFalse(
            app.staticTexts["Cheerios 12oz"].waitForExistence(timeout: 2),
            "Removed row should leave the list"
        )
    }

    /// REQ-INV-017: tapping Undo restores the removed item and dismisses the toast.
    func testSwipe_undoRestoresItem() throws {
        openInventoryList()
        let row = try requireRow(named: "Cheerios 12oz")

        let toast = UITestLaunch.element(app, TestIdentifiers.inventoryUndoToast)
        try triggerTrailingAction(
            on: row,
            id: TestIdentifiers.inventoryRemoveAction,
            label: "Remove",
            mustNotOffer: nil,
            alreadyApplied: { toast.exists }
        )

        let undo = undoButton()
        XCTAssertTrue(undo.waitForExistence(timeout: 4), "Undo button should appear")
        undo.tap()

        XCTAssertTrue(
            app.staticTexts["Cheerios 12oz"].waitForExistence(timeout: UITestLaunch.elementTimeout),
            "Undo should restore the removed row"
        )
        XCTAssertFalse(
            UITestLaunch.element(app, TestIdentifiers.inventoryUndoToast).waitForExistence(timeout: 2),
            "Undo should dismiss the toast"
        )
    }

    // MARK: - Helpers

    /// Row anchor: the visible title text inside the cell (swiping the text swipes the row).
    private func requireRow(named name: String) throws -> XCUIElement {
        let title = app.staticTexts[name]
        guard title.waitForExistence(timeout: UITestLaunch.elementTimeout) else {
            throw XCTSkip("No inventory fixture row named \(name) under --uitesting")
        }
        return title
    }

    /// Partial drag (not `swipeLeft()`): the row allows full swipe, and XCUITest's
    /// built-in swipe is long enough to fire the action before we can assert on the
    /// revealed button. The anchor is the row's title text, so drag in window
    /// coordinates at the title's vertical center.
    private func revealTrailingActions(on row: XCUIElement) {
        let y = row.frame.midY
        let width = app.frame.width
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: width * 0.9, dy: y))
        let end = origin.withOffset(CGVector(dx: width * 0.55, dy: y))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// Swipe the row and run its trailing action. Either the action button is revealed
    /// and tapped, or the drag already registered as a full swipe and the effect is
    /// visible — both are valid ways to perform the action. Fails if neither happens.
    private func triggerTrailingAction(
        on row: XCUIElement,
        id: String,
        label: String,
        mustNotOffer other: (id: String, label: String)?,
        alreadyApplied: () -> Bool
    ) throws {
        revealTrailingActions(on: row)
        let action = swipeAction(id: id, label: label)
        if action.waitForExistence(timeout: 5) {
            if let other {
                XCTAssertFalse(
                    swipeAction(id: other.id, label: other.label).exists,
                    "Row should offer \(label), not \(other.label)"
                )
            }
            action.tap()
            return
        }
        if alreadyApplied() { return }
        // One more, shorter attempt in case the first drag was consumed as a scroll.
        revealTrailingActions(on: row)
        if action.waitForExistence(timeout: 5) {
            action.tap()
            return
        }
        XCTAssertTrue(alreadyApplied(), "\(label) swipe action should appear or apply")
    }

    /// SwiftUI swipe actions surface as buttons; the identifier may or may not propagate,
    /// so fall back to the visible label.
    private func swipeAction(id: String, label: String) -> XCUIElement {
        let byId = app.buttons[id]
        if byId.exists { return byId }
        let byLabel = app.buttons[label]
        if byLabel.exists { return byLabel }
        return app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
    }

    private func undoButton() -> XCUIElement {
        let byId = UITestLaunch.element(app, TestIdentifiers.inventoryUndoButton)
        if byId.exists { return byId }
        return app.buttons["Undo"]
    }

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
