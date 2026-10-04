// =============================================================
// UI001StructureTests.swift
// Satisfies: UI-001 (Native Android Interface)
// Design artifact: design/mockups/ (all screens)
// Layer: 1 — Structural / XCUITest
// =============================================================

import XCTest

/// Android Compose UI lives under `android-fable/`. iOS structural coverage is UI-002+.
final class UI001StructureTests: XCTestCase {
    func testAndroidInterface_placeholderOnIOS() throws {
        throw XCTSkip("UI-001 is Android-only — covered by android-fable Compose UI tests")
    }
}
