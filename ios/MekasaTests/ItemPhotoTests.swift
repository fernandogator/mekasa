import UIKit
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

/// Local database of small list thumbnails (UI-006 AC8).
final class ThumbnailStoreTests: XCTestCase {
    private func temporaryStore(capacity: Int = ThumbnailStore.defaultCapacity) -> ThumbnailStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("thumb-\(UUID().uuidString)", isDirectory: true)
        return ThumbnailStore(directory: directory, capacity: capacity)
    }

    private func image(width: CGFloat, height: CGFloat, color: UIColor = .systemOrange) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private func pixelLongest(_ image: UIImage) -> CGFloat {
        max(image.size.width, image.size.height) * image.scale
    }

    func testJpegKeepsTheLongEdgeAt192Pixels() throws {
        let data = try XCTUnwrap(ThumbnailImage.jpegData(from: image(width: 800, height: 400)))
        let decoded = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(pixelLongest(decoded), ThumbnailImage.maxPixel, accuracy: 0.5)
        XCTAssertEqual(decoded.size.width, 192, accuracy: 0.5)
        XCTAssertEqual(decoded.size.height, 96, accuracy: 0.5)
    }

    func testJpegDoesNotEnlargeASmallImage() throws {
        let data = try XCTUnwrap(ThumbnailImage.jpegData(from: image(width: 40, height: 20)))
        let decoded = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(decoded.size.width, 40)
        XCTAssertEqual(decoded.size.height, 20)
    }

    func testStoreRoundTripsAndOverwritesTheSameURL() throws {
        let store = temporaryStore()
        let url = "https://images.example/milk.jpg"
        let first = try XCTUnwrap(ThumbnailImage.jpegData(from: image(width: 300, height: 300)))
        store.save(first, for: url)
        XCTAssertEqual(store.jpeg(for: url), first)
        XCTAssertEqual(store.count(), 1)

        let replacement = try XCTUnwrap(ThumbnailImage.jpegData(from: image(width: 120, height: 80, color: .systemBlue)))
        store.save(replacement, for: url)
        XCTAssertEqual(store.jpeg(for: url), replacement)
        XCTAssertEqual(store.count(), 1)
        XCTAssertNil(store.jpeg(for: "https://images.example/missing.jpg"))
    }

    func testStoreDropsTheOldestRowPastCapacity() throws {
        let store = temporaryStore(capacity: 2)
        let jpeg = try XCTUnwrap(ThumbnailImage.jpegData(from: image(width: 32, height: 32)))
        store.save(jpeg, for: "a")
        Thread.sleep(forTimeInterval: 0.01)
        store.save(jpeg, for: "b")
        Thread.sleep(forTimeInterval: 0.01)
        store.save(jpeg, for: "c")
        XCTAssertEqual(store.count(), 2)
        XCTAssertNil(store.jpeg(for: "a"))
        XCTAssertNotNil(store.jpeg(for: "b"))
        XCTAssertNotNil(store.jpeg(for: "c"))
    }

    func testRemoveAllForgetsEveryThumbnail() throws {
        let store = temporaryStore()
        let jpeg = try XCTUnwrap(ThumbnailImage.jpegData(from: image(width: 32, height: 32)))
        store.save(jpeg, for: "a")
        store.remember(try XCTUnwrap(UIImage(data: jpeg)), for: "a")
        XCTAssertNotNil(store.image(for: "a"))
        let generation = store.generation
        store.removeAll()
        XCTAssertEqual(store.count(), 0)
        XCTAssertNil(store.image(for: "a"))
        XCTAssertGreaterThan(store.generation, generation)
    }

    func testLoaderStoresASmallImageAndDoesNotDownloadTwice() async throws {
        let store = temporaryStore()
        let url = URL(string: "https://images.example/oat.jpg")!
        let source = image(width: 640, height: 480)
        let payload = try XCTUnwrap(source.jpegData(compressionQuality: 0.9))
        let counter = FetchCounter()
        let loader = ThumbnailLoader(store: store) { _ in
            await counter.increment()
            return payload
        }

        let first = try await loader.image(for: url)
        let second = try await loader.image(for: url)

        XCTAssertEqual(await counter.value, 1)
        XCTAssertLessThanOrEqual(pixelLongest(first), ThumbnailImage.maxPixel)
        XCTAssertEqual(pixelLongest(first), pixelLongest(second))
        XCTAssertEqual(store.count(), 1)
        let stored = try XCTUnwrap(store.jpeg(for: url.absoluteString))
        XCTAssertLessThan(stored.count, payload.count)
    }

    func testLoaderDoesNotKeepAFailedDownload() async {
        let store = temporaryStore()
        let url = URL(string: "https://images.example/gone.jpg")!
        let loader = ThumbnailLoader(store: store) { _ in
            throw URLError(.badServerResponse)
        }
        do {
            _ = try await loader.image(for: url)
            XCTFail("expected the download to fail")
        } catch {
            XCTAssertEqual(store.count(), 0)
        }
    }

    func testLoaderIgnoresADownloadThatFinishesAfterSignOut() async throws {
        let store = temporaryStore()
        let url = URL(string: "https://images.example/private.jpg")!
        let payload = try XCTUnwrap(image(width: 400, height: 400).jpegData(compressionQuality: 0.8))
        let gate = FetchGate()
        let loader = ThumbnailLoader(store: store) { _ in
            await gate.wait()
            return payload
        }

        let task = Task { try await loader.image(for: url) }
        await gate.started()
        store.removeAll()
        await gate.open()

        do {
            _ = try await task.value
            XCTFail("a download that outlives sign-out must not be stored")
        } catch is CancellationError {
            XCTAssertEqual(store.count(), 0)
        }
    }

    func testPrivateThumbnailRequestCarriesTheBearerToken() throws {
        let photoID = "0b5c7e4e-7f3e-4d0c-9c1e-6d2b8a9f1c22"
        let url = try XCTUnwrap(URL(string: MekasaAPIClient.shared.baseURL.absoluteString + "/v1/product-photos/\(photoID)"))
        let request = ThumbnailRequest.make(for: url, token: "tok-123")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok-123")

        let relative = try XCTUnwrap(URL(string: "/v1/product-photos/\(photoID)"))
        let anchored = ThumbnailRequest.make(for: relative, token: "tok-123")
        XCTAssertEqual(anchored.value(forHTTPHeaderField: "Authorization"), "Bearer tok-123")
        XCTAssertEqual(anchored.url?.host, MekasaAPIClient.shared.baseURL.host)

        let catalog = URL(string: "https://images.openfoodfacts.org/front.jpg")!
        let plain = ThumbnailRequest.make(for: catalog, token: "tok-123")
        XCTAssertNil(plain.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(plain.url, catalog)
    }
}

private actor FetchCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}

private actor FetchGate {
    private var opened = false
    private var didStart = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        didStart = true
        if opened { return }
        await withCheckedContinuation { continuation in
            if opened {
                continuation.resume()
            } else {
                waiters.append(continuation)
            }
        }
    }

    func started() async {
        while !didStart { await Task.yield() }
    }

    func open() {
        opened = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}
