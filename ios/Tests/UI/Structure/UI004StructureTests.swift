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
        XCTAssertTrue(UITestLaunch.element(app, TestIdentifiers.addItemButton).exists)
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

    func testDashboard_addOpensHubThenScanPath() {
        UITestLaunch.element(app, TestIdentifiers.addItemButton).tap()
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.addItemsHub)
                .waitForExistence(timeout: UITestLaunch.elementTimeout)
        )
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.scanButton)
                .waitForExistence(timeout: UITestLaunch.elementTimeout)
        )
    }

    func testShoppingList_itemListStructure() {
        let listTab = UITestLaunch.element(app, TestIdentifiers.listTab)
        if listTab.waitForExistence(timeout: UITestLaunch.elementTimeout) {
            listTab.tap()
        }
        let list = UITestLaunch.element(app, TestIdentifiers.itemList)
        let empty = UITestLaunch.element(app, TestIdentifiers.emptyStateView)
        XCTAssertTrue(
            list.waitForExistence(timeout: UITestLaunch.elementTimeout)
                || empty.waitForExistence(timeout: 5)
        )
        if list.exists {
            XCTAssertTrue(UITestLaunch.element(app, TestIdentifiers.itemCell).exists)
        }
    }
}
