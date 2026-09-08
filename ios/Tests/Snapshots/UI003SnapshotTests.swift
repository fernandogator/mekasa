// =============================================================
// UI003SnapshotTests.swift
// Satisfies: UI-003 (Onboarding Flow)
// Design artifact: design/mockups/OnboardingHouseholdSetup.jsx
// Baseline location: Tests/Snapshots/__Snapshots__/
// Layer: 2 — Visual Snapshot / swift-snapshot-testing
// =============================================================

import SnapshotTesting
import SwiftUI
import XCTest
@testable import Mekasa

@MainActor
final class UI003SnapshotTests: XCTestCase {
    func testWelcome_default_iPhone13Pro() throws {
        let vc = SnapshotHost.controller { session in
            session.onboardingStep = .welcome
            return WelcomeView()
        }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Pro, precision: 0.98))
    }

    func testHouseholdSetup_default_iPhone13Pro() throws {
        let vc = SnapshotHost.controller { session in
            session.onboardingStep = .household
            return HouseholdSetupView()
        }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Pro, precision: 0.98))
    }

    func testWelcome_dark_iPhone13Pro() throws {
        let vc = SnapshotHost.controller { session in
            session.onboardingStep = .welcome
            return WelcomeView()
        }
        try MekasaSnapshots.assertScreen(
            of: vc,
            as: .image(on: .iPhone13Pro, precision: 0.98, traits: .init(userInterfaceStyle: .dark))
        )
    }

    func testWelcome_small_iPhone13Mini() throws {
        let vc = SnapshotHost.controller { session in
            session.onboardingStep = .welcome
            return WelcomeView()
        }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Mini, precision: 0.98))
    }

    func testStoreSelection_empty_iPhone13Pro() throws {
        let vc = SnapshotHost.controller(empty: true) { session in
            session.onboardingStep = .stores
            return StoreSelectionView()
        }
        try MekasaSnapshots.assertScreen(of: vc, as: .image(on: .iPhone13Pro, precision: 0.98))
    }
}
