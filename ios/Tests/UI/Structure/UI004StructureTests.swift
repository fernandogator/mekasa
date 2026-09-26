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

    func testShoppingList_itemListStructure() {
        let listTab = UITestLaunch.element(app, TestIdentifiers.listTab)
        if listTab.waitForExistence(timeout: UITestLaunch.elementTimeout) {
            listTab.tap()
        } else if app.buttons["List"].waitForExistence(timeout: 5) {
            app.buttons["List"].tap()
        }
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
}
