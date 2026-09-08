// =============================================================
// UI001StructureTests.swift
// Satisfies: UI-001 (Native Android Interface)
// Design artifact: design/mockups/ (all screens)
// Layer: 1 — Structural / XCUITest
// =============================================================

import XCTest

/// Android Compose UI lives under `android/`. iOS structural coverage is UI-002+.
final class UI001StructureTests: XCTestCase {
    func testAndroidInterface_placeholderOnIOS() throws {
        // TODO: Implement under android/src/test/ui/ when Jetpack Compose screens ship.
        throw XCTSkip("UI-001 is Android-only — covered by android Compose UI tests")
    }
}
