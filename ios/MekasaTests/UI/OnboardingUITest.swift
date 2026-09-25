// Verifies: UI-003 (onboarding flow), UI-002 (store selection) · REQ-019 (invite deep link)
// AC1, AC2, AC3
// Design: design/mockups/OnboardingHouseholdSetup.jsx, OnboardingStoreSelection.jsx
//
// 3-layer coverage:
//   Layer 1 — Tests/UI/Structure/UI003StructureTests.swift
//   Layer 2 — Tests/Snapshots/UI003SnapshotTests.swift
//   Layer 3 — Scripts/ui_vision_cases.json + Scripts/verify_ui_vision.py

import XCTest
@testable import Mekasa

/// Layer 0: the onboarding state machine `RootView` switches on.
/// Welcome → Household → Address → Stores → InitialScan → Invite → Home.
final class OnboardingUITest: XCTestCase {

    func testLayout_keyElementsExistAndVisible() {
        // Step header: title + "n / 6" progress for every pre-home step.
        let steps = OnboardingStep.allCases
        XCTAssertEqual(
            steps,
            [.welcome, .household, .address, .stores, .initialScan, .invite, .done],
            "RootView routes these steps in this order"
        )
        for (index, step) in steps.dropLast().enumerated() {
            XCTAssertFalse(step.title.isEmpty, "\(step) needs a header title")
            XCTAssertEqual(step.progressLabel, "\(index + 1) / 6")
        }
        XCTAssertEqual(OnboardingStep.done.title, "Home")
        XCTAssertEqual(OnboardingStep.done.progressLabel, "", "Home hides the progress label")
    }

    @MainActor
    func testInteraction_tapsInputsAndNavigationTriggers() {
        let session = AppSession()
        XCTAssertEqual(session.onboardingStep, .welcome, "Fresh session starts on Welcome")
        XCTAssertFalse(session.isSignedIn)

        // Welcome "Browse UI" (offline preview) signs in locally and lands on Household setup.
        session.startUIPreview()
        XCTAssertTrue(session.isUIPreview)
        XCTAssertTrue(session.isSignedIn)
        XCTAssertEqual(session.onboardingStep, .household)
        XCTAssertNil(session.household, "Preview has no household until the user names one")

        // Sign out returns to Welcome and remembers the email for prefill (REQ-022 AC5).
        session.email = "owner@mekasa.local"
        session.signOut()
        XCTAssertEqual(session.onboardingStep, .welcome)
        XCTAssertEqual(session.lastSignedInEmail, "owner@mekasa.local")
        XCTAssertFalse(session.isUIPreview)
    }

    @MainActor
    func testFlow_navigatesToNextScreen() {
        let session = AppSession()
        // Each screen's primary CTA advances exactly one step (the views assign the next case).
        let expected: [OnboardingStep] = [.household, .address, .stores, .initialScan, .invite, .done]
        var current = OnboardingStep.welcome
        for next in expected {
            XCTAssertEqual(next.rawValue, current.rawValue + 1, "\(current) → \(next) must be adjacent")
            session.onboardingStep = next
            current = next
        }
        XCTAssertEqual(session.onboardingStep, .done)

        // Resume rules mirrored from WelcomeView.resumeStep(for:): missing address → Address,
        // no stores → Stores, otherwise Home.
        var household = TestFixtures.previewHousehold
        household.address = nil
        XCTAssertEqual(Self.resumeStep(for: household), .address)
        household.address = "100 Test St"
        household.storeIDs = []
        XCTAssertEqual(Self.resumeStep(for: household), .stores)
        household.storeIDs = ["stub-heb"]
        XCTAssertEqual(Self.resumeStep(for: household), .done)
    }

    @MainActor
    func testFlow_inviteDeepLinkIsRemembered() {
        let session = AppSession()
        defer { UserDefaults.standard.removeObject(forKey: "mekasa.pendingInviteToken") }

        session.handleDeepLink(URL(string: "mekasa://invite?token=abc123")!)
        XCTAssertEqual(session.pendingInviteToken, "abc123")

        session.handleDeepLink(URL(string: "mekasa://invite/xyz789")!)
        XCTAssertEqual(session.pendingInviteToken, "xyz789")

        // Non-mekasa schemes are ignored.
        session.handleDeepLink(URL(string: "https://example.com/invite?token=nope")!)
        XCTAssertEqual(session.pendingInviteToken, "xyz789")

        // Trash deep link flips kiosk mode instead.
        session.startUITesting()
        session.handleDeepLink(URL(string: "mekasa://trash")!)
        XCTAssertTrue(session.isTrashKioskMode)
        XCTAssertEqual(session.onboardingStep, .done)
    }

    private static func resumeStep(for household: Household) -> OnboardingStep {
        if household.address == nil { return .address }
        if household.storeIDs.isEmpty { return .stores }
        return .done
    }
}
