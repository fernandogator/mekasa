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
        XCTAssertTrue(UITestLaunch.waitForShell(app), "Main shell did not appear under --uitesting")
    }

    func testMainShell_rootAndNavExist() {
        XCTAssertTrue(UITestLaunch.element(app, TestIdentifiers.rootView).exists
            || UITestLaunch.element(app, TestIdentifiers.mainShellView).exists)
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.addItemButton)
                .waitForExistence(timeout: UITestLaunch.elementTimeout)
        )
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.homeTab).exists
                || app.buttons[TestIdentifiers.homeTab].exists
        )
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.listTab).exists
                || app.buttons[TestIdentifiers.listTab].exists
        )
    }

    func testAddItemButton_opensAddItemsHub() {
        let add = UITestLaunch.element(app, TestIdentifiers.addItemButton)
        XCTAssertTrue(add.waitForExistence(timeout: UITestLaunch.elementTimeout))
        add.tap()
        XCTAssertTrue(
            UITestLaunch.element(app, TestIdentifiers.addItemsHub)
                .waitForExistence(timeout: UITestLaunch.elementTimeout)
        )
    }
}
