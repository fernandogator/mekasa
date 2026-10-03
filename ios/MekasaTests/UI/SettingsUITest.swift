// Verifies: UI-004 Family tab (settings) · REQ-019 (invites) · REQ-022 (sign out / session)
// Design: design/mockups/Settings.jsx, design/mockups/FamilyMembers.jsx
//
// 3-layer coverage:
//   Layer 1 — Tests/UI/Structure/UI004StructureTests.swift (shell tabs)
//   Layer 2 — Tests/Snapshots/UI004SnapshotTests.swift
//   Layer 3 — Scripts/ui_vision_cases.json + Scripts/verify_ui_vision.py

import XCTest
@testable import Mekasa

/// Layer 0: state behind `FamilyMembersView` (account row, pending invite banner,
/// owner-only actions, trash kiosk entry, sign out).
final class SettingsUITest: XCTestCase {

    @MainActor
    func testLayout_keyElementsExistAndVisible() {
        let session = AppSession()
        session.startUITesting()

        // Account row.
        XCTAssertEqual(session.email, "uitesting@mekasa.local")
        XCTAssertEqual(session.displayName, "UI Test")
        // Owner badge + owner-only sections (invites, role changes, unknown trash scans).
        XCTAssertTrue(session.isHouseholdOwner)
        XCTAssertEqual(session.myMemberRole, "owner")
        // No invite banner without a pending token.
        XCTAssertNil(session.pendingInviteToken)
        // Fixture members the design lists: one owner + members + a child.
        XCTAssertEqual(TestFixtures.standardMembers.filter { $0.role == .owner }.count, 1)
        XCTAssertTrue(TestFixtures.standardMembers.contains { $0.role == .child })
    }

    @MainActor
    func testInteraction_tapsInputsAndNavigationTriggers() {
        let session = AppSession()
        session.startUITesting()

        // "Open trash kiosk" flips the shell into kiosk mode; Exit flips it back.
        XCTAssertFalse(session.isTrashKioskMode)
        session.isTrashKioskMode = true
        XCTAssertTrue(session.isTrashKioskMode)
        XCTAssertEqual(session.onboardingStep, .done, "Kiosk renders under the .done route")
        session.isTrashKioskMode = false
        XCTAssertFalse(session.isTrashKioskMode)

        // Member (non-owner) sees the gate errors instead of owner actions.
        session.isUITesting = false
        session.isUIPreview = false
        session.idToken = "live-token"
        session.userUID = "member-uid"
        session.myMemberRole = "member"
        session.household = TestFixtures.previewHousehold
        XCTAssertFalse(session.isHouseholdOwner)
        session.approveShoppingRequest(id: "missing")
        XCTAssertEqual(session.lastError, "Only household owners can approve requests.")
        session.rejectShoppingRequest(id: "missing")
        XCTAssertEqual(session.lastError, "Only household owners can deny requests.")
    }

    @MainActor
    func testFlow_navigatesToNextScreen() {
        let session = AppSession()
        defer { UserDefaults.standard.removeObject(forKey: "mekasa.pendingInviteToken") }
        session.startUITesting()

        // Invite link arrives → banner state; accepting requires a live token, so under
        // UI testing it stays pending (no network).
        session.handleDeepLink(URL(string: "mekasa://invite?token=fam-42")!)
        XCTAssertEqual(session.pendingInviteToken, "fam-42")

        // Sign out from Family → Welcome, keeps email for prefill, clears household data.
        session.signOut()
        XCTAssertEqual(session.onboardingStep, .welcome)
        XCTAssertEqual(session.lastSignedInEmail, "uitesting@mekasa.local")
        XCTAssertNil(session.household)
        XCTAssertNil(session.idToken)
        XCTAssertEqual(session.myPermissions, [])
        XCTAssertFalse(session.isTrashKioskMode)
    }

    @MainActor
    func testFlow_sessionExpiryNoticeSurvivesSignOut() {
        let session = AppSession()
        session.startUITesting()
        session.signOut(expiredSessionMessage: "Your session expired. Please sign in again.")
        XCTAssertEqual(session.onboardingStep, .welcome)
        XCTAssertEqual(session.lastError, "Your session expired. Please sign in again.")
    }
}
