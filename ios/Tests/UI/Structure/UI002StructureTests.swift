// =============================================================
// UI002StructureTests.swift
// Satisfies: UI-002 (Native iOS Interface)
// Design artifact: design/mockups/ (all screens)
// Layer: 1 — Structural / XCUITest
// =============================================================

import XCTest

final class UI002StructureTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = UITestLaunch.app()
        app.launch()
    }

    func testMainShell_rootAndNavExist() {
        XCTAssertTrue(app.otherElements[TestIdentifiers.rootView].waitForExistence(timeout: 5)
            || app.otherElements[TestIdentifiers.mainShellView].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[TestIdentifiers.addItemButton].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[TestIdentifiers.homeTab].exists || app.otherElements[TestIdentifiers.homeTab].exists)
        XCTAssertTrue(app.buttons[TestIdentifiers.listTab].exists || app.otherElements[TestIdentifiers.listTab].exists)
    }

    func testAddItemButton_opensAddItemsHub() {
        let add = app.buttons[TestIdentifiers.addItemButton]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(app.otherElements[TestIdentifiers.addItemsHub].waitForExistence(timeout: 5)
            || app.descendants(matching: .any)[TestIdentifiers.addItemsHub].waitForExistence(timeout: 5))
    }
}
