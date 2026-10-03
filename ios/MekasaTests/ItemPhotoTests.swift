import XCTest
@testable import Mekasa

/// Household-private item photos: URL recognition, authenticated requests, DTO.
/// Satisfies: REQ-INV-019 (Replace an Item Picture With a Private Photo)
/// Acceptance criteria: AC1, AC3, AC8
final class ItemPhotoTests: XCTestCase {
    private let api = URL(string: "https://mekasa-api.example.run.app")!
    private let photoID = "0b5c7e4e-7f3e-4d0c-9c1e-6d2b8a9f1c22"

    func testRecognizesOnlyOurHouseholdScopedPhotoURLs() {
        let mine = "https://mekasa-api.example.run.app/v1/households/h-1/item-photos/\(photoID)"
        XCTAssertTrue(PrivateItemPhoto.isPrivate(mine, apiBaseURL: api))
        XCTAssertTrue(
            PrivateItemPhoto.isPrivate("https://MEKASA-API.example.run.app/v1/households/h-1/item-photos/\(photoID)", apiBaseURL: api),
            "host comparison is case-insensitive"
        )

        XCTAssertFalse(PrivateItemPhoto.isPrivate(nil, apiBaseURL: api))
        XCTAssertFalse(PrivateItemPhoto.isPrivate("", apiBaseURL: api))
        XCTAssertFalse(PrivateItemPhoto.isPrivate("https://images.openfoodfacts.org/x.jpg", apiBaseURL: api))
        XCTAssertFalse(PrivateItemPhoto.isPrivate("https://placehold.co/400x400/png?text=Dairy", apiBaseURL: api))
        XCTAssertFalse(
            PrivateItemPhoto.isPrivate("https://evil.example.com/v1/households/h-1/item-photos/\(photoID)", apiBaseURL: api),
            "same path on another host is not ours"
        )
        XCTAssertFalse(
            PrivateItemPhoto.isPrivate("https://mekasa-api.example.run.app/v1/photos/\(photoID)", apiBaseURL: api),
            "legacy public photo path is not private"
        )
        XCTAssertFalse(
            PrivateItemPhoto.isPrivate("https://mekasa-api.example.run.app/v1/households/h-1/item-photos/not-a-uuid", apiBaseURL: api)
        )
        XCTAssertFalse(PrivateItemPhoto.isPrivate("data:image/jpeg;base64,/9j/4AAQ", apiBaseURL: api))
    }

    func testAuthenticatedRequestCarriesBearerAndNothingWhenSignedOut() throws {
        let url = URL(string: "https://mekasa-api.example.run.app/v1/households/h-1/item-photos/\(photoID)")!
        let request = try XCTUnwrap(PrivateItemPhoto.request(for: url, token: "tok-123"))
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok-123")
        XCTAssertEqual(request.url, url)

        XCTAssertNil(PrivateItemPhoto.request(for: url, token: nil))
        XCTAssertNil(PrivateItemPhoto.request(for: url, token: ""))
    }

    func testUploadResponseDecodes() throws {
        let json = Data("""
        {"photo_id": "\(photoID)",
         "url": "https://mekasa-api.example.run.app/v1/households/h-1/item-photos/\(photoID)"}
        """.utf8)
        let dto = try JSONDecoder().decode(ItemPhotoUploadDTO.self, from: json)
        XCTAssertEqual(dto.photoId, photoID)
        XCTAssertTrue(PrivateItemPhoto.isPrivate(dto.url, apiBaseURL: api))
    }

    @MainActor
    func testSessionTokenIsMirroredForImageLoads() {
        let session = AppSession()
        session.idToken = "mirror-me"
        XCTAssertEqual(PrivateImageAuth.shared.token, "mirror-me")
        session.idToken = nil
        XCTAssertNil(PrivateImageAuth.shared.token)
    }
}
