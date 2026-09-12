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
        let app = UITestLaunch.app()
        app.launch()
        XCTAssertTrue(
            UITestLaunch.waitForShell(app),
            "Expected main shell when launched with --uitesting"
        )
        XCTAssertFalse(
            UITestLaunch.element(app, TestIdentifiers.welcomeView).exists,
            "Welcome should be skipped in UI testing mode"
        )
    }

    func testOnboarding_welcomeScreen_placeholderWithoutUITesting() throws {
        // TODO: Launch without --uitesting once CI has Firebase-free welcome fixtures.
        throw XCTSkip("Welcome-path structural pass requires non-uitesting launch profile")
    }
}
