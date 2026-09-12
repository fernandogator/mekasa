// =============================================================
// UI005StructureTests.swift
// Satisfies: UI-005 (Trash Station Mode)
// Design artifact: design/mockups/TrashStationMode.jsx
// Layer: 1 — Structural / XCUITest
// =============================================================

import XCTest

final class UI005StructureTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = UITestLaunch.app()
        app.launch()
        XCTAssertTrue(UITestLaunch.waitForShell(app), "Main shell did not appear under --uitesting")
    }

    func testTrashStation_reachableFromAddHub() {
        let add = UITestLaunch.addItemButton(app)
        XCTAssertTrue(add.waitForExistence(timeout: UITestLaunch.elementTimeout))
        add.tap()
        let trashEntry = UITestLaunch.element(app, TestIdentifiers.trashStationView)
        if trashEntry.waitForExistence(timeout: UITestLaunch.elementTimeout) {
            trashEntry.tap()
        } else {
            app.staticTexts["Trash station"].tap()
        }
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.scanPromptLabel)
                .waitForExistence(timeout: UITestLaunch.elementTimeout)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "scan")).firstMatch
                    .waitForExistence(timeout: UITestLaunch.elementTimeout)
        )
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.itemList).exists
                || UITestLaunch.element(app, TestIdentifiers.emptyStateView).exists
                || UITestLaunch.element(app, TestIdentifiers.scanButton).exists
                || app.buttons["Scan"].exists
        )
    }

    func testTrashStation_emptyStateWhenNoInventory() {
        app.terminate()
        app = UITestLaunch.app(empty: true)
        app.launch()
        XCTAssertTrue(UITestLaunch.waitForShell(app))
        UITestLaunch.addItemButton(app).tap()
        let trashEntry = UITestLaunch.element(app, TestIdentifiers.trashStationView)
        if trashEntry.waitForExistence(timeout: UITestLaunch.elementTimeout) {
            trashEntry.tap()
        } else {
            app.staticTexts["Trash station"].tap()
        }
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.emptyStateView)
                .waitForExistence(timeout: UITestLaunch.elementTimeout)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "empty")).firstMatch
                    .waitForExistence(timeout: 5)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "nothing")).firstMatch
                    .waitForExistence(timeout: 5)
        )
    }
}
