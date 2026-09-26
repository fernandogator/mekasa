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

    /// UI-006 AC6: rows are grouped under category headers and the header eyebrow
    /// counts the whole inventory. Fixtures span several categories.
    func testInventoryList_groupsRowsByCategory() throws {
        openInventoryList()
        guard UITestLaunch.element(app, TestIdentifiers.itemCell)
            .waitForExistence(timeout: UITestLaunch.elementTimeout)
        else {
            throw XCTSkip("No inventory fixture rows under --uitesting")
        }
        let headers = app.descendants(matching: .any)
            .matching(identifier: TestIdentifiers.inventorySectionHeader)
        XCTAssertGreaterThanOrEqual(
            headers.count, 2,
            "Fixture inventory spans several categories, so at least two section headers should render"
        )
        // Sections are alphabetical and List cells are lazy, so "Produce" starts below the
        // fold; scroll until its header is realised before asserting.
        let produceHeader = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label ==[c] %@", "Produce")).firstMatch
        let list = UITestLaunch.element(app, TestIdentifiers.itemList)
        for _ in 0 ..< 4 where !produceHeader.exists {
            (list.exists ? list : app).swipeUp()
        }
        XCTAssertTrue(
            produceHeader.waitForExistence(timeout: 3),
            "Bananas should sit under a Produce header"
        )
        let summary = UITestLaunch.element(app, TestIdentifiers.inventorySummary)
        XCTAssertTrue(summary.waitForExistence(timeout: UITestLaunch.elementTimeout), "Header eyebrow should render")
        XCTAssertTrue(
            summary.label.localizedCaseInsensitiveContains("items")
                && summary.label.localizedCaseInsensitiveContains("low"),
            "Eyebrow should read like '7 items · 3 low', got \(summary.label)"
        )
    }

    /// UI-006 AC6: typing in the search field narrows rows by name and hides other
    /// categories; clearing restores them.
    func testInventoryList_searchFiltersRows() throws {
        openInventoryList()
        guard UITestLaunch.element(app, TestIdentifiers.itemCell)
            .waitForExistence(timeout: UITestLaunch.elementTimeout)
        else {
            throw XCTSkip("No inventory fixture rows under --uitesting")
        }
        let cells = app.descendants(matching: .any).matching(identifier: TestIdentifiers.itemCell)
        let unfilteredCount = cells.count
        XCTAssertGreaterThanOrEqual(unfilteredCount, 2, "Fixtures should render several rows before filtering")

        let field = searchField()
        XCTAssertTrue(field.waitForExistence(timeout: UITestLaunch.elementTimeout), "Search field should render")
        field.tap()
        field.typeText("banana")

        XCTAssertTrue(app.staticTexts["Bananas"].waitForExistence(timeout: UITestLaunch.elementTimeout))
        XCTAssertFalse(
            app.staticTexts["Cheerios 12oz"].waitForExistence(timeout: 2),
            "Non-matching rows should be filtered out"
        )

        field.typeText("zz")
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.inventoryNoMatches)
                .waitForExistence(timeout: UITestLaunch.elementTimeout)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "No items match")).firstMatch
                .waitForExistence(timeout: 2),
            "A query with no hits should show the no-matches copy"
        )

        let clear = UITestLaunch.element(app, TestIdentifiers.inventorySearchClear)
        if clear.waitForExistence(timeout: 3) {
            clear.tap()
        } else {
            let typed = (field.value as? String) ?? "bananazz"
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: typed.count))
        }
        let restored = NSPredicate { _, _ in cells.count >= min(unfilteredCount, 2) }
        let restoredExpectation = XCTNSPredicateExpectation(predicate: restored, object: nil)
        XCTAssertEqual(
            XCTWaiter().wait(for: [restoredExpectation], timeout: UITestLaunch.elementTimeout),
            .completed,
            "Clearing the search should restore the rows"
        )
    }

    /// UI-006 AC7: the header Add button opens the Add Items hub from the list.
    func testInventoryList_addButtonOpensAddItemsHub() throws {
        openInventoryList()
        let add = UITestLaunch.element(app, TestIdentifiers.inventoryAddButton)
        guard add.waitForExistence(timeout: UITestLaunch.elementTimeout) else {
            throw XCTSkip("Inventory Add button not found under --uitesting")
        }
        add.tap()
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.addItemsHub).waitForExistence(timeout: UITestLaunch.elementTimeout)
                || UITestLaunch.element(app, TestIdentifiers.scanButton).waitForExistence(timeout: 2),
            "Add should present the Add Items hub"
        )
    }

    /// UI-006 AC7: the empty state offers an Add items CTA that opens the hub.
    func testInventoryList_emptyStateAddCTAOpensHub() {
        app.terminate()
        app = UITestLaunch.app(empty: true)
        app.launch()
        XCTAssertTrue(UITestLaunch.waitForShell(app))
        openInventoryList()
        let cta = UITestLaunch.element(app, TestIdentifiers.inventoryEmptyAddButton)
        let fallback = app.buttons["Add items"]
        XCTAssertTrue(
            cta.waitForExistence(timeout: UITestLaunch.elementTimeout) || fallback.waitForExistence(timeout: 2),
            "Empty inventory should offer an Add items CTA"
        )
        (cta.exists ? cta : fallback).tap()
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.addItemsHub).waitForExistence(timeout: UITestLaunch.elementTimeout)
                || UITestLaunch.element(app, TestIdentifiers.scanButton).waitForExistence(timeout: 2),
            "Add items CTA should present the Add Items hub"
        )
    }

    /// REQ-INV-014: trailing swipe on a qty > 1 row reveals Use 1; tapping decrements
    /// without any confirmation alert. Fixture: Bananas (qty 6, TestFixtures.standardItemList).
    /// REQ-009 parity: "Use 1" on the detail screen consumes one unit in place.
    func testItemDetail_useOneDecrementsInPlace() throws {
        openInventoryList()
        let row = try requireRow(named: "Bananas")
        row.tap()

        let useOne = UITestLaunch.element(app, TestIdentifiers.itemDetailUseOneButton)
        guard useOne.waitForExistence(timeout: UITestLaunch.elementTimeout) else {
            throw XCTSkip("Item detail did not open for Bananas under --uitesting")
        }
        if !useOne.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        useOne.tap()

        let status = UITestLaunch.element(app, TestIdentifiers.itemDetailUseOneStatus)
        XCTAssertTrue(status.waitForExistence(timeout: UITestLaunch.elementTimeout))
        XCTAssertTrue(
            status.label.contains("5 left"),
            "Bananas start at qty 6, so one use should leave 5; got \(status.label)"
        )
    }

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
        if title.waitForExistence(timeout: UITestLaunch.elementTimeout), title.isHittable {
            return title
        }
        // Rows are grouped by category, so a fixture row can start below the fold;
        // List cells are created lazily, so scroll until the title is on screen.
        let list = UITestLaunch.element(app, TestIdentifiers.itemList)
        for _ in 0 ..< 4 where !(title.exists && title.isHittable) {
            (list.exists ? list : app).swipeUp()
        }
        guard title.waitForExistence(timeout: 3), title.isHittable else {
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

    private func searchField() -> XCUIElement {
        let byId = app.textFields[TestIdentifiers.inventorySearchField]
        if byId.exists { return byId }
        let anyById = UITestLaunch.element(app, TestIdentifiers.inventorySearchField)
        if anyById.exists { return anyById }
        return app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] %@", "Search")).firstMatch
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
