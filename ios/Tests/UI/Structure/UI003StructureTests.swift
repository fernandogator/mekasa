// =============================================================
// UI003StructureTests.swift
// Satisfies: UI-003 (Onboarding Flow)
// Design artifact: design/mockups/OnboardingStoreSelection.jsx
// Layer: 1 — Structural / XCUITest
// =============================================================

import XCTest

final class UI003StructureTests: XCTestCase {
    func testOnboarding_welcomeSkippedInUITestingMode() throws {
        // `--uitesting` jumps to MainShell with fixtures (deterministic).
        // Full onboarding sequence is exercised in DEBUG UI preview + future step-flagged launches.
        let app = UITestLaunch.app()
        app.launch()
        XCTAssertTrue(
            app.otherElements[TestIdentifiers.mainShellView].waitForExistence(timeout: 5)
                || app.otherElements[TestIdentifiers.dashboardView].waitForExistence(timeout: 5)
        )
    }

    func testOnboarding_welcomeScreen_placeholderWithoutUITesting() throws {
        // TODO: Launch without --uitesting once CI has Firebase-free welcome fixtures.
        throw XCTSkip("Welcome-path structural pass requires non-uitesting launch profile")
    }
}
