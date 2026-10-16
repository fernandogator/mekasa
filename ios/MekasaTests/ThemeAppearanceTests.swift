import SwiftUI
import UIKit
import XCTest
@testable import Mekasa

/// UI-002 AC3: every theme role resolves to the Rich & Grounded light and dark values
/// in design/design-system.md, and dark labels on accent fills stay charcoal (NFR-005 AC2).
final class ThemeAppearanceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.set(MekasaPaletteStyle.grounded.rawValue, forKey: ThemePreferences.styleKey)
    }

    override func tearDown() {
        UserDefaults.standard.set(MekasaPaletteStyle.grounded.rawValue, forKey: ThemePreferences.styleKey)
        super.tearDown()
    }

    private let roles: [(String, Color, UInt32, UInt32)] = [
        ("brand", MekasaTheme.brand, 0x5d5652, 0x3a3531),
        ("brandMuted", MekasaTheme.brandMuted, 0x8fa085, 0x5a6f4f),
        ("surface", MekasaTheme.surface, 0xede8e0, 0x1c1a18),
        ("surfaceElevated", MekasaTheme.surfaceElevated, 0xfaf7f3, 0x272421),
        ("text", MekasaTheme.text, 0x5d5652, 0xede8e0),
        ("textMuted", MekasaTheme.textMuted, 0x5c6b54, 0xa9b79f),
        ("accent", MekasaTheme.accent, 0x5a6f4f, 0x8fa085),
        ("danger", MekasaTheme.danger, 0xa44a3f, 0xe39286),
        ("success", MekasaTheme.success, 0x5a6f4f, 0xa3b598),
        ("warning", MekasaTheme.warning, 0x8b5c32, 0xe2b07e),
        ("accentTint", MekasaTheme.accentTint, 0xdce8d3, 0x2c3628),
        ("dangerTint", MekasaTheme.dangerTint, 0xf6e3e0, 0x3a2220),
        ("successTint", MekasaTheme.successTint, 0xdce8d3, 0x2c3628),
        ("warningTint", MekasaTheme.warningTint, 0xf3e6d8, 0x3a2e22),
        ("border", MekasaTheme.border, 0x76896b, 0x7f8e76),
        ("surfaceMuted", MekasaTheme.surfaceMuted, 0xece7df, 0x312d29),
        ("progressTrack", MekasaTheme.progressTrack, 0xd9d3c9, 0x3a3531),
        ("onBrand", MekasaTheme.onBrand, 0xffffff, 0xede8e0),
        ("onAccent", MekasaTheme.onAccent, 0xffffff, 0x1c1a18),
        ("onBrandMuted", MekasaTheme.onBrandMuted, 0xc9d6c0, 0xb5c2ab),
        ("cameraSurface", MekasaTheme.cameraSurface, 0x1a1918, 0x0f0e0d),
        ("onCamera", MekasaTheme.onCamera, 0xfaf7f3, 0xfaf7f3),
        ("scrim", MekasaTheme.scrim, 0x1a1918, 0x0f0e0d),
    ]

    private let halloweenRoles: [(String, Color, UInt32, UInt32)] = [
        ("brand", MekasaTheme.brand, 0x8b4a0c, 0xd4a01b),
        ("brandMuted", MekasaTheme.brandMuted, 0xd4a574, 0xb8860b),
        ("surface", MekasaTheme.surface, 0xfff8f0, 0x1a1513),
        ("surfaceElevated", MekasaTheme.surfaceElevated, 0xfffbf7, 0x2d2620),
        ("text", MekasaTheme.text, 0x3d2817, 0xf5e8dc),
        ("textMuted", MekasaTheme.textMuted, 0x5c4336, 0xc4b5a0),
        ("accent", MekasaTheme.accent, 0x6b247a, 0x9fd356),
        ("danger", MekasaTheme.danger, 0xa03224, 0xe8745c),
        ("success", MekasaTheme.success, 0x4a5e2c, 0xa8b86f),
        ("warning", MekasaTheme.warning, 0x7a5210, 0xe8c74f),
        ("border", MekasaTheme.border, 0x6f5638, 0xa8894a),
        ("onBrand", MekasaTheme.onBrand, 0xfffbf7, 0x1a1513),
        ("onAccent", MekasaTheme.onAccent, 0xfffbf7, 0x1a1513),
        ("onBrandMuted", MekasaTheme.onBrandMuted, 0xe8d7c3, 0x5c4a2e),
    ]

    func testRolesResolvePerAppearance() {
        for (name, color, light, dark) in roles {
            XCTAssertEqual(rgb(color, .light), light, "\(name) light")
            XCTAssertEqual(rgb(color, .dark), dark, "\(name) dark")
        }
    }

    func testHalloweenRolesResolvePerAppearance() {
        UserDefaults.standard.set(MekasaPaletteStyle.halloween.rawValue, forKey: ThemePreferences.styleKey)
        for (name, color, light, dark) in halloweenRoles {
            XCTAssertEqual(rgb(color, .light), light, "halloween \(name) light")
            XCTAssertEqual(rgb(color, .dark), dark, "halloween \(name) dark")
        }
    }

    private func rgb(_ color: Color, _ style: UIUserInterfaceStyle) -> UInt32 {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func byte(_ value: CGFloat) -> UInt32 { UInt32((value * 255).rounded()) }
        return byte(red) << 16 | byte(green) << 8 | byte(blue)
    }
}
