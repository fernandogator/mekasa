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
    }

    func testTrashStation_reachableFromAddHub() {
        XCTAssertTrue(app.buttons[TestIdentifiers.addItemButton].waitForExistence(timeout: 5))
        app.buttons[TestIdentifiers.addItemButton].tap()
        let trashEntry = app.descendants(matching: .any)[TestIdentifiers.trashStationView]
        XCTAssertTrue(trashEntry.waitForExistence(timeout: 5))
        trashEntry.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[TestIdentifiers.scanPromptLabel].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[TestIdentifiers.itemList].exists
                || app.descendants(matching: .any)[TestIdentifiers.emptyStateView].exists
        )
        XCTAssertTrue(app.descendants(matching: .any)[TestIdentifiers.scanButton].exists)
    }

    func testTrashStation_emptyStateWhenNoInventory() {
        app.terminate()
        app = UITestLaunch.app(empty: true)
        app.launch()
        app.buttons[TestIdentifiers.addItemButton].tap()
        app.descendants(matching: .any)[TestIdentifiers.trashStationView].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[TestIdentifiers.emptyStateView].waitForExistence(timeout: 5)
        )
    }
}
