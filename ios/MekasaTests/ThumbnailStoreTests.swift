import UIKit
import XCTest
@testable import Mekasa

/// Local database of small list thumbnails (UI-006 AC8).
final class ThumbnailStoreTests: XCTestCase {
    private func temporaryStore(capacity: Int = ThumbnailStore.defaultCapacity) -> ThumbnailStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("thumb-\(UUID().uuidString).sqlite")
        return ThumbnailStore(databaseURL: url, capacity: capacity)
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
