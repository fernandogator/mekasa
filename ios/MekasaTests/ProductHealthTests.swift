import XCTest
@testable import Mekasa

/// REQ-021: health grade decoding, Firestore mapping and per-member avoidance matching.
final class ProductHealthTests: XCTestCase {
    private let ramenJSON = """
    {
      "grade": "E",
      "score": 0,
      "nutriscore": "D",
      "nova_group": 4,
      "additives": [
        {"code": "E621", "name": "Monosodium glutamate (MSG)", "concern": "moderate"},
        {"code": "E330", "name": "Citric acid", "concern": "none"}
      ],
      "allergens": ["Gluten", "Soybeans"],
      "traces": ["Eggs"],
      "ingredients_text": "Wheat flour, palm oil, monosodium glutamate",
      "flags": ["Palm oil"]
    }
    """

    // MARK: - Decoding

    func testBarcodeLookupDecodesHealthAndWarnings() throws {
        let json = """
        {
          "barcode": "0000000012345",
          "found": true,
          "name": "Instant Ramen",
          "brand": "NoodleCo",
          "category": "Pantry",
          "quantity": 1,
          "image_url": null,
          "source": "openfoodfacts",
          "health": \(ramenJSON),
          "warnings": [
            {"member_uid": "mem-2", "member_name": "Leo", "matched": ["MSG"]}
          ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(BarcodeLookupDTO.self, from: json)
        XCTAssertEqual(dto.health?.grade, "E")
        XCTAssertEqual(dto.health?.novaGroup, 4)
        XCTAssertEqual(dto.health?.additives.first?.code, "E621")
        XCTAssertEqual(dto.health?.flaggedAdditives.map(\.code), ["E621"])
        XCTAssertEqual(dto.warnings.count, 1)
        XCTAssertEqual(dto.warnings.first?.sentence, "Leo avoids MSG")
    }

    func testBarcodeLookupWithoutHealthStillDecodes() throws {
        let json = """
        {"barcode": "123456", "found": false, "quantity": 1, "source": "none"}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(BarcodeLookupDTO.self, from: json)
        XCTAssertNil(dto.health)
        XCTAssertTrue(dto.warnings.isEmpty)
    }

    func testInventoryItemDTOCarriesHealthIntoLocalModel() throws {
        let json = """
        {
          "id": "item-1",
          "household_id": "hh-1",
          "name": "Instant Ramen",
          "category": "Pantry",
          "quantity": 3,
          "low_stock_threshold": 1,
          "barcode": "0000000012345",
          "source": "barcode",
          "created_by_uid": "u1",
          "updated_by_uid": "u1",
          "created_at": "2026-09-07T00:00:00Z",
          "updated_at": "2026-09-07T00:00:00Z",
          "health": \(ramenJSON),
          "warnings": []
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(InventoryItemDTO.self, from: json)
        let local = dto.toLocal()
        XCTAssertEqual(local.health?.grade, "E")
        XCTAssertEqual(local.health?.allergens, ["Gluten", "Soybeans"])
        XCTAssertEqual(local.health?.summaryLine, "Nutri-Score D · NOVA 4 · 2 additives")
    }

    func testCreateBodyEncodesHealthSnakeCase() throws {
        let item = InventoryItem(
            name: "Instant Ramen",
            category: "Pantry",
            barcode: "0000000012345",
            source: .barcode,
            health: TestFixtures.ramenHealth
        )
        let data = try JSONEncoder().encode(InventoryItemCreateBody(from: item))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let health = try XCTUnwrap(object["health"] as? [String: Any])
        XCTAssertEqual(health["grade"] as? String, "E")
        XCTAssertEqual(health["nova_group"] as? Int, 4)
        XCTAssertEqual((health["additives"] as? [[String: Any]])?.count, 3)
    }

    func testMemberDTODecodesAvoidListWithDefault() throws {
        let json = """
        {"uid": "u1", "household_id": "hh", "role": "member", "status": "active", "avoid": ["msg", "cilantro"]}
        """.data(using: .utf8)!
        let member = try JSONDecoder().decode(HouseholdMemberDTO.self, from: json)
        XCTAssertEqual(member.avoid, ["msg", "cilantro"])

        let legacy = """
        {"uid": "u2", "household_id": "hh", "role": "owner", "status": "active"}
        """.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(HouseholdMemberDTO.self, from: legacy).avoid, [])
    }

    // MARK: - Firestore mapping (REQ-021 AC4)

    func testFirestoreMapperReadsHealthMap() {
        let data: [String: Any] = [
            "name": "Instant Ramen",
            "category": "Pantry",
            "quantity": 2,
            "source": "barcode",
            "health": [
                "grade": "D",
                "score": 25,
                "nutriscore": "C",
                "nova_group": NSNumber(value: 4),
                "additives": [["code": "E621", "name": "MSG", "concern": "moderate"]],
                "allergens": ["Gluten"],
                "traces": [],
                "flags": [],
            ],
        ]
        let item = FirestoreDocumentMapper.inventoryItem(id: "doc-1", data: data)
        XCTAssertEqual(item?.health?.grade, "D")
        XCTAssertEqual(item?.health?.novaGroup, 4)
        XCTAssertEqual(item?.health?.additives.first?.code, "E621")
        XCTAssertEqual(item?.health?.allergens, ["Gluten"])
    }

    func testFirestoreMapperTreatsMissingHealthAsNil() {
        let item = FirestoreDocumentMapper.inventoryItem(
            id: "doc-2",
            data: ["name": "Bananas", "category": "Produce", "quantity": 6]
        )
        XCTAssertNotNil(item)
        XCTAssertNil(item?.health)
    }

    // MARK: - Matching (REQ-021 AC2)

    func testMatcherHitsCodesTagsAndIngredients() {
        let options = AvoidanceMatcher.fallbackOptions
        let hits = AvoidanceMatcher.matches(
            avoid: ["msg", "gluten", "eggs", "palm_oil", "shellfish", "monosodium"],
            health: TestFixtures.ramenHealth,
            options: options
        )
        // MSG via E621 code, gluten via allergen tag, eggs via traces, palm oil via flag,
        // free text "monosodium" via ingredients; shellfish absent.
        XCTAssertEqual(hits, ["msg", "gluten", "eggs", "palm_oil", "monosodium"])
    }

    func testMatcherRespectsWordBoundaries() {
        let veggie = ProductHealth(ingredientsText: "Veggie mix, water")
        XCTAssertTrue(AvoidanceMatcher.matches(avoid: ["eggs"], health: veggie, options: []).isEmpty)
        let eggs = ProductHealth(ingredientsText: "Sugar, eggs, flour")
        XCTAssertEqual(AvoidanceMatcher.matches(avoid: ["egg"], health: eggs, options: []), ["egg"])
        XCTAssertTrue(AvoidanceMatcher.matches(avoid: ["egg"], health: nil, options: []).isEmpty)
    }

    func testWarningsNameEachAffectedMember() {
        let warnings = AvoidanceMatcher.warnings(
            members: TestFixtures.standardMemberDTOs,
            health: TestFixtures.ramenHealth,
            options: AvoidanceMatcher.fallbackOptions
        )
        XCTAssertEqual(warnings.map(\.memberName), ["Leo", "Mia"])
        XCTAssertEqual(warnings.first?.matched, ["MSG"])
        XCTAssertEqual(warnings.last?.matched, ["Gluten"])
        XCTAssertEqual(warnings.first?.sentence, "Leo avoids MSG")
    }

    @MainActor
    func testSessionWarningsUseCachedMembers() {
        let session = AppSession()
        session.startUITesting()
        let warnings = session.memberWarnings(for: TestFixtures.ramenHealth)
        XCTAssertEqual(warnings.map(\.memberUid), ["mem-2", "mem-3"])
        XCTAssertEqual(session.myAvoidList, ["shellfish"])
        XCTAssertTrue(session.memberWarnings(for: nil).isEmpty)
    }

    @MainActor
    func testUpdateMemberAvoidInPreviewUpdatesCache() async throws {
        let session = AppSession()
        session.startUITesting()
        try await session.updateMemberAvoid(memberUID: "mem-3", avoid: ["gluten", "msg"])
        let mia = session.householdMembers.first(where: { $0.uid == "mem-3" })
        XCTAssertEqual(mia?.avoid, ["gluten", "msg"])
        XCTAssertEqual(
            session.memberWarnings(for: TestFixtures.ramenHealth).last?.matched,
            ["Gluten", "MSG"]
        )
    }

    // MARK: - Grade display

    func testGradeLabelsAndColors() {
        XCTAssertEqual(HealthGrade.label(for: "a"), "Excellent")
        XCTAssertEqual(HealthGrade.label(for: "E"), "Bad")
        XCTAssertEqual(HealthGrade.label(for: nil), "No grade")
        XCTAssertNotEqual(HealthGrade.color(for: "A"), HealthGrade.color(for: "E"))
        XCTAssertEqual(HealthGrade.color(for: nil), MekasaTheme.brandMuted)
    }
}
