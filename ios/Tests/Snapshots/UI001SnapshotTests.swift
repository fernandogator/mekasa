// =============================================================
// UI001SnapshotTests.swift
// Satisfies: UI-001 (Native Android Interface)
// Design artifact: design/mockups/ (all screens)
// Baseline location: Tests/Snapshots/__Snapshots__/
// Layer: 2 — Visual Snapshot / swift-snapshot-testing
// =============================================================

import XCTest

final class UI001SnapshotTests: XCTestCase {
    func testAndroidInterface_placeholderOnIOS() throws {
        // TODO: Android Compose screenshot baselines under android/
        throw XCTSkip("UI-001 is Android-only")
    }
}
