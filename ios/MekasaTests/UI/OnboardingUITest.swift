// Verifies: UI-003 (onboarding flow), UI-002 (store selection)
// AC1, AC2, AC3
// Design: design/mockups/OnboardingHouseholdSetup.jsx, OnboardingStoreSelection.jsx

import XCTest

/// XCUITest + snapshot stubs for Onboarding.
/// Layout + interaction + flow + semantic visual verification.
/// Visual verification is structural (not pixel-exact).
///
/// Implemented screens (SwiftUI): Welcome → Household → Address → Stores →
/// InitialScan stub → Invite stub → Home stub. Wire XCUITest once the app
/// target builds in CI with Firebase SPM.
final class OnboardingUITest: XCTestCase {

    func testLayout_keyElementsExistAndVisible() throws {
        throw XCTSkip("Stub — run on device/simulator after xcodegen + Firebase SPM")
        // Layout: Mekasa brand header, step progress, primary CTA
    }

    func testInteraction_tapsInputsAndNavigationTriggers() throws {
        throw XCTSkip("Stub — run on device/simulator after xcodegen + Firebase SPM")
        // Interaction: email/Google auth, household name, address confirm, store multi-select
    }

    func testFlow_navigatesToNextScreen() throws {
        throw XCTSkip("Stub — run on device/simulator after xcodegen + Firebase SPM")
        // Flow: welcome → household → address → stores → scan → invite → home
    }

    func testVisual_semanticStructureMatchesBaseline() throws {
        throw XCTSkip("Stub — implement when baseline exists")
        // Visual verification: capture screenshot; compare semantic structure
        // to design/baselines/ios/OnboardingStoreSelection_baseline.png
        // Tolerance: 15% color/content; fail only on structural divergence
    }
}
