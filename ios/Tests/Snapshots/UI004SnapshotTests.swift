// =============================================================
// UI004SnapshotTests.swift
// Satisfies: UI-004 (Home Dashboard)
// Design artifact: design/mockups/Dashboard.jsx
// Baseline location: Tests/Snapshots/__Snapshots__/
// Layer: 2 — Visual Snapshot / swift-snapshot-testing
// =============================================================

import SnapshotTesting
import SwiftUI
import XCTest
@testable import Mekasa

@MainActor
final class UI004SnapshotTests: XCTestCase {
    func testDashboard_default_iPhone13Pro() throws {
        let vc = SnapshotHost.controller { _ in DashboardView() }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Pro, precision: 0.98))
    }

    func testDashboard_empty_iPhone13Pro() throws {
        let vc = SnapshotHost.controller(empty: true) { _ in DashboardView() }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Pro, precision: 0.98))
    }

    func testDashboard_dark_iPhone13Pro() throws {
        let vc = SnapshotHost.controller { _ in DashboardView() }
        try MekasaSnapshots.assertScreen(
            of: vc,
            as: .image(on: .iPhone13Pro, precision: 0.98, traits: .init(userInterfaceStyle: .dark))
        )
    }

    func testDashboard_small_iPhone13Mini() throws {
        let vc = SnapshotHost.controller { _ in DashboardView() }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Mini, precision: 0.98))
    }

    func testShoppingList_default_iPhone13Pro() throws {
        let vc = SnapshotHost.controller { _ in ShoppingListView() }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Pro, precision: 0.98))
    }

    func testShoppingList_empty_iPhone13Pro() throws {
        let vc = SnapshotHost.controller(empty: true) { _ in ShoppingListView() }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Pro, precision: 0.98))
    }

    func testAddItemsHub_default_iPhone13Pro() throws {
        let vc = SnapshotHost.controller { _ in
            NavigationStack { AddItemsView() }
        }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Pro, precision: 0.98))
    }

    func testManualEntry_default_iPhone13Pro() throws {
        let vc = SnapshotHost.controller { _ in
            NavigationStack { ManualEntryView() }
        }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Pro, precision: 0.98))
    }
}
