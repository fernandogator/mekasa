// Verifies: UI-004 (Home Dashboard)
// AC1, AC2, AC3
// Design: design/mockups/Dashboard.jsx, design/DESIGN_SYSTEM.md (hero)

import XCTest

/// XCUITest + snapshot stubs for Dashboard.
/// Layout + interaction + flow + semantic visual verification.
/// Visual verification is structural (not pixel-exact).
///
/// Implemented SwiftUI: `DashboardView` home photo hero → `HomePhotoView`
/// (camera / Photos). Structural: `Tests/UI/Structure/UI004StructureTests`.
final class DashboardUITest: XCTestCase {

    func testLayout_keyElementsExistAndVisible() throws {
        throw XCTSkip("Stub — covered by UI004StructureTests (incl. HomePhotoHero)")
        // Layout: home photo hero, Low Stock / Spend cards, Needs Approval, bottom nav + FAB
    }

    func testInteraction_tapsInputsAndNavigationTriggers() throws {
        throw XCTSkip("Stub — run on device/simulator after xcodegen + Firebase SPM")
        // Interaction: tap hero → HomePhotoView; approve/deny; FAB; tabs
    }

    func testFlow_homePhotoCameraOrLibrary() throws {
        throw XCTSkip("Stub — HomePhotoView camera / Photos → Save updates household.photo_url")
    }

    func testFlow_navigatesToNextScreen() throws {
        throw XCTSkip("Stub — run on device/simulator after xcodegen + Firebase SPM")
        // Flow: complete onboarding → lands on Dashboard home tab
    }

    func testVisual_semanticStructureMatchesBaseline() throws {
        throw XCTSkip("Stub — implement when baseline exists")
        // Visual verification: capture screenshot; compare semantic structure
        // to design/baselines/ios/Dashboard_baseline.png
        // Tolerance: 15% color/content; fail only on structural divergence
    }
}
