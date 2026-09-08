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
    }

    func testDashboard_primaryContainersExist() {
        XCTAssertTrue(
            app.otherElements[TestIdentifiers.dashboardView].waitForExistence(timeout: 5)
                || app.scrollViews.firstMatch.waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons[TestIdentifiers.addItemButton].exists)
    }

    func testDashboard_requestQueueOrEmptyStateExists() {
        let queue = app.descendants(matching: .any)[TestIdentifiers.requestQueue]
        let empty = app.descendants(matching: .any)[TestIdentifiers.emptyStateView]
        XCTAssertTrue(
            queue.waitForExistence(timeout: 5) || empty.waitForExistence(timeout: 2),
            "Dashboard must show request queue or empty state"
        )
    }

    func testDashboard_addOpensHubThenScanPath() {
        app.buttons[TestIdentifiers.addItemButton].tap()
        let hub = app.descendants(matching: .any)[TestIdentifiers.addItemsHub]
        XCTAssertTrue(hub.waitForExistence(timeout: 5))
        let scan = app.descendants(matching: .any)[TestIdentifiers.scanButton]
        XCTAssertTrue(scan.waitForExistence(timeout: 5))
    }

    func testShoppingList_itemListStructure() {
        let listTab = app.buttons[TestIdentifiers.listTab]
        if listTab.waitForExistence(timeout: 3) {
            listTab.tap()
        }
        let list = app.descendants(matching: .any)[TestIdentifiers.itemList]
        let empty = app.descendants(matching: .any)[TestIdentifiers.emptyStateView]
        XCTAssertTrue(list.waitForExistence(timeout: 5) || empty.waitForExistence(timeout: 2))
        if list.exists {
            XCTAssertTrue(app.descendants(matching: .any)[TestIdentifiers.itemCell].exists)
        }
    }
}
