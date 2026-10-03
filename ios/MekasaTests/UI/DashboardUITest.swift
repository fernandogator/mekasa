// Verifies: UI-004 (Home Dashboard) · REQ-002 (home photo)
// AC1, AC2, AC3
// Design: design/mockups/Dashboard.jsx, design/DESIGN_SYSTEM.md (hero)
//
// 3-layer coverage:
//   Layer 1 — Tests/UI/Structure/UI004StructureTests.swift
//   Layer 2 — Tests/Snapshots/UI004SnapshotTests.swift
//   Layer 3 — Scripts/ui_vision_cases.json + Scripts/verify_ui_vision.py

import UIKit
import XCTest
@testable import Mekasa

/// Layer 0: dashboard state that `DashboardView` renders under `--uitesting`.
/// Layout = the numbers/cards have data; interaction = the actions the cards trigger;
/// flow = hero → HomePhotoView save path. Visual checks live in Layer 2/3.
final class DashboardUITest: XCTestCase {

    @MainActor
    func testLayout_keyElementsExistAndVisible() {
        let session = AppSession()
        session.startUITesting()

        XCTAssertEqual(session.onboardingStep, .done, "Dashboard is the root once onboarding is done")
        XCTAssertNotNil(session.household, "Hero card needs a household")
        XCTAssertFalse(session.inventory.isEmpty, "Low Stock card reads inventory fixtures")
        XCTAssertEqual(
            session.lowStockCount,
            TestFixtures.standardItemList.filter(\.isLowStock).count,
            "Low Stock stat mirrors live inventory when fixtures are present"
        )
        XCTAssertGreaterThan(session.openShoppingCount, 0, "Shopping summary shows open (unchecked, approved) rows")
        XCTAssertGreaterThan(session.localTrackedSpend, 0, "Spend card falls back to local price rollup offline")
        XCTAssertFalse(session.activity.isEmpty, "Activity feed shows fixture rows")
    }

    @MainActor
    func testInteraction_tapsInputsAndNavigationTriggers() {
        let session = AppSession()
        session.startUITesting()

        // Needs Approval → Approve / Deny act on the request rows.
        let request = ShoppingListItem(
            id: "req-dash",
            name: "Oreos",
            quantity: 2,
            needsApproval: true,
            requestedBy: "Mia",
            kind: .request
        )
        session.shoppingList.insert(request, at: 0)
        session.approveShoppingRequest(id: "req-dash")
        let approved = session.shoppingList.first { $0.id == "req-dash" }
        XCTAssertEqual(approved?.needsApproval, false)
        XCTAssertEqual(approved?.kind, .custom)

        session.shoppingList.insert(
            ShoppingListItem(id: "req-deny", name: "Candy", quantity: 1, needsApproval: true, requestedBy: "Leo", kind: .request),
            at: 0
        )
        session.rejectShoppingRequest(id: "req-deny")
        XCTAssertFalse(session.shoppingList.contains { $0.id == "req-deny" })

        // Low Stock stat → inventory list keeps the low rows it advertises.
        let lowRows = session.inventory.filter(\.isLowStock)
        XCTAssertEqual(lowRows.count, session.lowStockCount)
    }

    @MainActor
    func testFlow_homePhotoCameraOrLibrary() async {
        let session = AppSession()
        session.startUITesting()
        XCTAssertNil(session.household?.photoURL, "Fixture household starts without a photo")

        let saved = await session.saveHomePhotoEdits(
            name: "The Guerrero Home",
            image: Self.solidImage(),
            nameChanged: true,
            imageChanged: true
        )
        XCTAssertTrue(saved)
        XCTAssertEqual(session.household?.name, "The Guerrero Home")
        XCTAssertEqual(session.household?.photoURL?.hasPrefix("data:image/jpeg;base64,"), true)

        // Saving with nothing changed is a no-op success.
        let noop = await session.saveHomePhotoEdits(name: nil, image: nil, nameChanged: false, imageChanged: false)
        XCTAssertTrue(noop)
        XCTAssertEqual(session.household?.name, "The Guerrero Home")
    }

    @MainActor
    func testFlow_navigatesToNextScreen() async {
        let session = AppSession()
        session.startUITesting()

        // Rename only (REQ-002 AC1): blank name clears to nil, non-blank is trimmed.
        let cleared = await session.updateHouseholdName("   ")
        XCTAssertTrue(cleared)
        XCTAssertNil(session.household?.name)
        let renamed = await session.updateHouseholdName("  Casa Rivas  ")
        XCTAssertTrue(renamed)
        XCTAssertEqual(session.household?.name, "Casa Rivas")

        // Sign out from the shell returns to Welcome and clears dashboard data.
        session.signOut()
        XCTAssertEqual(session.onboardingStep, .welcome)
        XCTAssertNil(session.household)
        XCTAssertTrue(session.inventory.isEmpty)
        XCTAssertFalse(session.isUITesting)
    }

    private static func solidImage(size: CGSize = CGSize(width: 8, height: 8)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
