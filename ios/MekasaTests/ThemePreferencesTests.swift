import XCTest
@testable import Mekasa

/// Seasonal palette preference and October Halloween promo rules.
@MainActor
final class ThemePreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ThemePreferencesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        UserDefaults.standard.removeObject(forKey: ThemePreferences.styleKey)
        UserDefaults.standard.removeObject(forKey: ThemePreferences.promptDismissedKey)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        UserDefaults.standard.removeObject(forKey: ThemePreferences.styleKey)
        UserDefaults.standard.removeObject(forKey: ThemePreferences.promptDismissedKey)
        ThemePreferences.shared.select(.grounded)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsToGrounded() {
        let prefs = ThemePreferences(defaults: defaults)
        XCTAssertEqual(prefs.style, .grounded)
        XCTAssertFalse(prefs.isHalloween)
    }

    func testSelectPersistsHalloween() {
        let prefs = ThemePreferences(defaults: defaults)
        prefs.select(.halloween)
        XCTAssertEqual(prefs.style, .halloween)
        XCTAssertEqual(defaults.string(forKey: ThemePreferences.styleKey), "halloween")
        XCTAssertTrue(defaults.bool(forKey: ThemePreferences.promptDismissedKey))
    }

    func testUndoRestoresGrounded() {
        let prefs = ThemePreferences(defaults: defaults)
        prefs.select(.halloween, showUndo: true)
        XCTAssertTrue(prefs.halloweenUndoVisible)
        prefs.undoHalloween()
        XCTAssertEqual(prefs.style, .grounded)
        XCTAssertEqual(defaults.string(forKey: ThemePreferences.styleKey), "grounded")
        XCTAssertFalse(prefs.halloweenUndoVisible)
    }

    func testDismissPromptHidesCard() {
        let prefs = ThemePreferences(defaults: defaults)
        prefs.dismissHalloweenPrompt()
        XCTAssertNotNil(defaults.object(forKey: ThemePreferences.promptDismissedKey))
        XCTAssertFalse(prefs.shouldShowHalloweenPrompt)
    }

    func testHalloweenPaletteTokensMatchDesignSystem() {
        let tokens = PaletteTokens.tokens(for: .halloween)
        XCTAssertEqual(tokens.light.brand, 0x8b4a0c)
        XCTAssertEqual(tokens.light.accent, 0x6b247a)
        XCTAssertEqual(tokens.light.text, 0x3d2817)
        XCTAssertEqual(tokens.dark.brand, 0xd4a01b)
        XCTAssertEqual(tokens.dark.accent, 0x9fd356)
        XCTAssertEqual(tokens.dark.onBrand, 0x1a1513)
    }
}
