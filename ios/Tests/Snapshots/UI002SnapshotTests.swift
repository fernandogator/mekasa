// =============================================================
// UI002SnapshotTests.swift
// Satisfies: UI-002 (Native iOS Interface)
// Design artifact: design/mockups/ (all screens)
// Baseline location: Tests/Snapshots/__Snapshots__/
// Layer: 2 — Visual Snapshot / swift-snapshot-testing
// =============================================================

import SnapshotTesting
import SwiftUI
import XCTest
@testable import Mekasa

@MainActor
final class UI002SnapshotTests: XCTestCase {
    func testMainShell_default_iPhone13Pro() throws {
        let vc = SnapshotHost.controller { _ in MainShellView() }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Pro, precision: 0.98))
    }

    func testMainShell_empty_iPhone13Pro() throws {
        let vc = SnapshotHost.controller(empty: true) { _ in MainShellView() }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Pro, precision: 0.98))
    }

    func testMainShell_dark_iPhone13Pro() throws {
        let vc = SnapshotHost.controller { _ in MainShellView() }
        try MekasaSnapshots.assertScreen(
            of: vc,
            as: .image(on: .iPhone13Pro, precision: 0.98, traits: .init(userInterfaceStyle: .dark))
        )
    }

    func testMainShell_small_iPhone13Mini() throws {
        let vc = SnapshotHost.controller { _ in MainShellView() }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Mini, precision: 0.98))
    }

    func testMainShell_large_iPadPro11() throws {
        let vc = SnapshotHost.controller { _ in MainShellView() }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPadPro11, precision: 0.98))
    }
}
