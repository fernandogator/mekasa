// =============================================================
// UI006SnapshotTests.swift
// Satisfies: UI-006 (Inventory list) · REQ-INV-014–018 (swipe / Undo toast)
// Design artifact: design/mockups/InventoryList.jsx
// Baseline location: Tests/Snapshots/__Snapshots__/
// Layer: 2 — Visual Snapshot / swift-snapshot-testing
// =============================================================

import SnapshotTesting
import SwiftUI
import XCTest
@testable import Mekasa

@MainActor
final class UI006SnapshotTests: XCTestCase {
    func testInventoryList_default_iPhone13Pro() throws {
        let vc = SnapshotHost.controller { _ in
            NavigationStack { InventoryListView() }
        }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Pro, precision: 0.98))
    }

    func testInventoryList_empty_iPhone13Pro() throws {
        let vc = SnapshotHost.controller(empty: true) { _ in
            NavigationStack { InventoryListView() }
        }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Pro, precision: 0.98))
    }

    func testInventoryList_undoToast_iPhone13Pro() throws {
        let vc = SnapshotHost.controller { session in
            session.showInventoryUndoToast = true
            return NavigationStack { InventoryListView() }
        }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Pro, precision: 0.98))
    }

    func testInventoryList_dark_iPhone13Pro() throws {
        let vc = SnapshotHost.controller { _ in
            NavigationStack { InventoryListView() }
        }
        try MekasaSnapshots.assertScreen(
            of: vc,
            as: .image(on: .iPhone13Pro, precision: 0.98, traits: .init(userInterfaceStyle: .dark))
        )
    }

    func testInventoryList_small_iPhone13Mini() throws {
        let vc = SnapshotHost.controller { _ in
            NavigationStack { InventoryListView() }
        }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Mini, precision: 0.98))
    }

    func testItemDetail_default_iPhone13Pro() throws {
        let vc = SnapshotHost.controller { session in
            let id = session.inventory.first?.id ?? "fixture"
            return NavigationStack { ItemDetailView(itemID: id) }
        }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Pro, precision: 0.98))
    }
}
