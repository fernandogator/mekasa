// =============================================================
// UI004StructureTests.swift
// Satisfies: UI-004 (Home Dashboard)
// Design artifact: design/mockups/Dashboard.jsx
// Layer: 1 — Structural / XCUITest
// =============================================================

import XCTest

final class UI004StructureTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = UITestLaunch.app()
        app.launch()
        XCTAssertTrue(UITestLaunch.waitForShell(app), "Main shell did not appear under --uitesting")
    }

    func testDashboard_primaryContainersExist() {
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.dashboardView)
                .waitForExistence(timeout: UITestLaunch.elementTimeout)
                || app.scrollViews.firstMatch.waitForExistence(timeout: UITestLaunch.elementTimeout)
        )
        XCTAssertTrue(UITestLaunch.addItemButton(app).exists)
    }

    func testDashboard_homePhotoHeroExists() {
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.homePhotoHero)
                .waitForExistence(timeout: UITestLaunch.elementTimeout)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Good")).firstMatch
                    .waitForExistence(timeout: 5),
            "Dashboard should show the home photo hero / greeting"
        )
    }

    func testDashboard_requestQueueOrEmptyStateExists() {
        let queue = UITestLaunch.element(app, TestIdentifiers.requestQueue)
        let empty = UITestLaunch.element(app, TestIdentifiers.emptyStateView)
        XCTAssertTrue(
            queue.waitForExistence(timeout: UITestLaunch.elementTimeout)
                || empty.waitForExistence(timeout: 5),
            "Dashboard must show request queue or empty state"
        )
    }

    /// UI-004 AC4: shopping teaser summarises open rows and jumps to the List tab.
    /// Fixtures: 4 unchecked rows (1 pending + 3 to buy).
    func testDashboard_shoppingTeaserOpensList() {
        let teaser = UITestLaunch.element(app, TestIdentifiers.dashboardShoppingTeaser)
        if !teaser.waitForExistence(timeout: 5) {
            app.swipeUp()
        }
        XCTAssertTrue(teaser.waitForExistence(timeout: UITestLaunch.elementTimeout), "Shopping teaser missing")
        XCTAssertTrue(
            teaser.label.contains("4 items to pick up"),
            "Teaser should count unchecked rows; got \(teaser.label)"
        )
        if !teaser.isHittable {
            app.swipeUp()
        }
        teaser.tap()
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.shoppingListView)
                .waitForExistence(timeout: UITestLaunch.elementTimeout),
            "Tapping the teaser should switch to the List tab"
        )
    }

    func testDashboard_addOpensHubThenScanPath() {
        UITestLaunch.addItemButton(app).tap()
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.addItemsHub)
                .waitForExistence(timeout: UITestLaunch.elementTimeout)
                || app.staticTexts["Add to the house"].waitForExistence(timeout: UITestLaunch.elementTimeout)
        )
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.scanButton)
                .waitForExistence(timeout: UITestLaunch.elementTimeout)
                || app.buttons["Scan barcode"].waitForExistence(timeout: UITestLaunch.elementTimeout)
                || app.staticTexts["Scan barcode"].waitForExistence(timeout: UITestLaunch.elementTimeout)
        )
    }

    /// REQ-019 parity: Family tab shows who's signed in, which house, and role · status per member.
    func testFamily_accountHouseholdAndMemberCards() {
        let familyTab = app.buttons["Family"]
        XCTAssertTrue(familyTab.waitForExistence(timeout: UITestLaunch.elementTimeout))
        familyTab.tap()

        let account = UITestLaunch.element(app, TestIdentifiers.familyAccountTitle)
        XCTAssertTrue(account.waitForExistence(timeout: UITestLaunch.elementTimeout), "Account card missing")
        XCTAssertEqual(account.label, "UI Test")
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.familyOfflineNotice).exists,
            "--uitesting runs in preview mode, so the offline notice should show"
        )

        let house = UITestLaunch.element(app, TestIdentifiers.familyHouseholdTitle)
        XCTAssertTrue(house.exists)
        XCTAssertEqual(house.label, "The Test House")
        XCTAssertEqual(UITestLaunch.element(app, TestIdentifiers.familyHouseholdAddress).label, "100 Test St")

        let subtitles = app.staticTexts.matching(identifier: TestIdentifiers.familyMemberSubtitle)
        XCTAssertTrue(subtitles.firstMatch.waitForExistence(timeout: UITestLaunch.elementTimeout))
        XCTAssertTrue(
            subtitles.firstMatch.label.contains("·"),
            "Member subtitle should read 'Role · status'; got \(subtitles.firstMatch.label)"
        )
    }

    private func openListTab() {
        let listTab = UITestLaunch.element(app, TestIdentifiers.listTab)
        if listTab.waitForExistence(timeout: UITestLaunch.elementTimeout) {
            listTab.tap()
        } else if app.buttons["List"].waitForExistence(timeout: 5) {
            app.buttons["List"].tap()
        }
    }

    func testShoppingList_itemListStructure() {
        openListTab()
        let list = UITestLaunch.element(app, TestIdentifiers.itemList)
        let empty = UITestLaunch.element(app, TestIdentifiers.emptyStateView)
        let shopping = UITestLaunch.element(app, TestIdentifiers.shoppingListView)
        XCTAssertTrue(
            list.waitForExistence(timeout: UITestLaunch.elementTimeout)
                || empty.waitForExistence(timeout: 5)
                || shopping.waitForExistence(timeout: 5)
                || app.staticTexts["Eggs"].waitForExistence(timeout: 5)
                || app.staticTexts["Avocados"].waitForExistence(timeout: 5),
            "Shopping list should show items, empty state, or the list screen"
        )
        if list.exists {
            XCTAssertTrue(
                UITestLaunch.element(app, TestIdentifiers.itemCell).exists
                    || UITestLaunch.element(app, TestIdentifiers.requestCell).exists
                    || app.staticTexts["Eggs"].exists
                    || app.staticTexts["2% milk"].exists,
                "Expected a shopping row (item or pending request)"
            )
        }
    }

    /// REQ-011 AC4: rows grouped into Needs approval / To buy / Purchased with a
    /// "N to buy" header summary. Fixtures: 1 pending, 3 to buy, 1 purchased.
    func testShoppingList_groupsIntoSectionsWithSummary() {
        openListTab()
        let headers = app.staticTexts.matching(identifier: TestIdentifiers.shoppingSectionHeader)
        XCTAssertTrue(
            headers.firstMatch.waitForExistence(timeout: UITestLaunch.elementTimeout),
            "Expected section headers on the shopping list"
        )
        XCTAssertGreaterThanOrEqual(headers.count, 2, "Fixtures should produce at least two sections")

        let summary = UITestLaunch.element(app, TestIdentifiers.shoppingToBuySummary)
        XCTAssertTrue(summary.waitForExistence(timeout: UITestLaunch.elementTimeout))
        XCTAssertTrue(
            summary.label.localizedCaseInsensitiveContains("3 to buy"),
            "Summary should count approved, unchecked rows; got \(summary.label)"
        )
    }

    /// REQ-011 AC4: auto-added rows carry an "Auto" chip.
    func testShoppingList_autoRowsShowAutoChip() {
        openListTab()
        // The chip text may be folded into the row button's accessibility label, so
        // accept either the chip element or an "auto-added" row label.
        let chips = app.staticTexts.matching(identifier: TestIdentifiers.shoppingAutoChip)
        let autoRows = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "auto-added"))
        XCTAssertTrue(
            chips.firstMatch.waitForExistence(timeout: UITestLaunch.elementTimeout)
                || autoRows.firstMatch.waitForExistence(timeout: 5),
            "Expected an Auto chip on the Eggs / 2% milk rows"
        )
    }

    /// REQ-012 AC4: the trash control removes a row from the list.
    func testShoppingList_removeButtonRemovesRow() {
        openListTab()
        // The row's toggle button carries "Avocados, not purchased"; the remove control
        // is a sibling button labelled "Remove Avocados".
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Avocados")).firstMatch
        let remove = app.buttons.matching(NSPredicate(format: "label == %@", "Remove Avocados")).firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: UITestLaunch.elementTimeout))
        XCTAssertTrue(row.exists)
        if !remove.isHittable {
            app.swipeUp()
        }
        remove.tap()

        let gone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: gone, object: remove)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: UITestLaunch.elementTimeout),
            .completed,
            "Remove control for Avocados should disappear once the row is removed"
        )
        XCTAssertFalse(row.exists, "Avocados row should be gone after removal")
    }
}
