// =============================================================
// UI005SnapshotTests.swift
// Satisfies: UI-005 (Trash Station Mode)
// Design artifact: design/mockups/TrashStationMode.jsx
// Baseline location: Tests/Snapshots/__Snapshots__/
// Layer: 2 — Visual Snapshot / swift-snapshot-testing
// =============================================================

import SnapshotTesting
import SwiftUI
import XCTest
@testable import Mekasa

@MainActor
final class UI005SnapshotTests: XCTestCase {
    func testTrashStation_default_iPhone13Pro() throws {
        let vc = SnapshotHost.controller { _ in
            NavigationStack { TrashStationView() }
        }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Pro, precision: 0.98))
    }

    func testTrashStation_empty_iPhone13Pro() throws {
        let vc = SnapshotHost.controller(empty: true) { _ in
            NavigationStack { TrashStationView() }
        }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Pro, precision: 0.98))
    }

    func testTrashStation_dark_iPhone13Pro() throws {
        let vc = SnapshotHost.controller { _ in
            NavigationStack { TrashStationView() }
        }
        try MekasaSnapshots.assertScreen(
            of: vc,
            as: .image(on: .iPhone13Pro, precision: 0.98, traits: .init(userInterfaceStyle: .dark))
        )
    }

    func testTrashStation_small_iPhone13Mini() throws {
        let vc = SnapshotHost.controller { _ in
            NavigationStack { TrashStationView() }
        }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Mini, precision: 0.98))
    }

    func testTrashStation_large_iPadPro11() throws {
        let vc = SnapshotHost.controller { _ in
            NavigationStack { TrashStationView() }
        }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPadPro11, precision: 0.98))
    }
}
