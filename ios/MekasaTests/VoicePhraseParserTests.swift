import XCTest
@testable import Mekasa

/// Unit coverage for spoken phrase → quantity + product query (REQ-007).
final class VoicePhraseParserTests: XCTestCase {

    func testParse_numberWordAndProduct() {
        let result = VoicePhraseParser.parse("two avocados")
        XCTAssertEqual(result?.quantity, 2)
        XCTAssertEqual(result?.productQuery, "avocados")
        XCTAssertEqual(result?.displayName, "Avocados")
    }

    func testParse_bareProductName() {
        let result = VoicePhraseParser.parse("Oreos")
        XCTAssertEqual(result?.quantity, 1)
        XCTAssertEqual(result?.productQuery, "Oreos")
    }

    func testParse_packsOfFiller() {
        let result = VoicePhraseParser.parse("three packs of oat milk")
        XCTAssertEqual(result?.quantity, 3)
        XCTAssertEqual(result?.productQuery, "oat milk")
    }

    func testParse_digitQuantity() {
        let result = VoicePhraseParser.parse("4 bananas!")
        XCTAssertEqual(result?.quantity, 4)
        XCTAssertEqual(result?.productQuery, "bananas")
    }

    func testParse_emptyReturnsNil() {
        XCTAssertNil(VoicePhraseParser.parse("   "))
        XCTAssertNil(VoicePhraseParser.parse("two"))
    }

    func testProductSearchHit_toDraftPreservesVoiceSource() {
        let hit = ProductSearchHitDTO(
            barcode: "123",
            name: "Oreo Double Stuf",
            brand: "Oreo",
            category: "Pantry",
            imageUrl: nil,
            source: "openfoodfacts"
        )
        let draft = hit.toDraft(quantity: 2, source: .voice)
        XCTAssertEqual(draft.source, .voice)
        XCTAssertEqual(draft.quantity, 2)
        XCTAssertEqual(draft.name, "Oreo Double Stuf")
    }
}
