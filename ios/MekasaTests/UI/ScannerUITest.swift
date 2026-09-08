// Verifies: UI-004 Add path · REQ-004
// Design: design/mockups/AddItems.jsx

import XCTest

/// XCUITest stubs for live barcode scanner + UPC lookup.
/// Implemented SwiftUI: `BarcodeScanView` (VisionKit `BarcodeCameraView` + UPC lookup)
/// looking up via `GET /v1/barcode/{code}` (Open Food Facts).
final class ScannerUITest: XCTestCase {

    func testLayout_keyElementsExistAndVisible() throws {
        throw XCTSkip("Stub — run on device after xcodegen + camera permission")
        // Layout: camera pane or fallback, typed UPC field, Look up code, Enter manually
    }

    func testInteraction_tapsInputsAndNavigationTriggers() throws {
        throw XCTSkip("Stub — run on device after xcodegen + camera permission")
        // Interaction: type Nutella UPC 3017624010701 → Look up → Confirm item
    }

    func testFlow_navigatesToNextScreen() throws {
        throw XCTSkip("Stub — run on device after xcodegen + camera permission")
        // Flow: FAB → Scan barcode → lookup → confirm → inventory
    }

    func testVisual_semanticStructureMatchesBaseline() throws {
        throw XCTSkip("Stub — implement when baseline exists")
    }
}
