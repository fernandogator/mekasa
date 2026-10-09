import CryptoKit
import SwiftUI
import UIKit

/// Household-private item photos and shared product photos: recognise our own
/// `…/item-photos/{id}` and `/v1/product-photos/{id}` URLs and load them with the
/// member's bearer token, which plain `AsyncImage` cannot send.
/// Satisfies: REQ-INV-019 (Replace an Item Picture With a Private Photo) AC3, AC8;
/// REQ-RCP-021 (Product Photo Upload and Storage) AC3
/// Spec version: 1.0
enum PrivateItemPhoto {
    /// The API stores product photos as host-relative paths; anchor them on the API host.
    static func resolve(_ url: URL, apiBaseURL: URL = MekasaAPIClient.shared.baseURL) -> URL {
        guard url.scheme == nil, url.host == nil, url.relativeString.hasPrefix("/v1/") else { return url }
        return URL(string: url.relativeString, relativeTo: apiBaseURL)?.absoluteURL ?? url
    }

    /// `/v1/households/{hid}/item-photos/{photo_id}` on the API host.
    static func isPrivate(_ urlString: String?, apiBaseURL: URL = MekasaAPIClient.shared.baseURL) -> Bool {
        guard let urlString, let url = URL(string: urlString) else { return false }
        return isPrivate(url, apiBaseURL: apiBaseURL)
    }

    static func isPrivate(_ url: URL, apiBaseURL: URL = MekasaAPIClient.shared.baseURL) -> Bool {
        let resolved = resolve(url, apiBaseURL: apiBaseURL)
        guard let host = resolved.host?.lowercased(), host == apiBaseURL.host?.lowercased() else { return false }
        let parts = resolved.path.split(separator: "/").map(String.init)
        // v1 / households / {hid} / item-photos / {photo_id}
        let itemPhoto = parts.count == 5
            && parts[0] == "v1"
            && parts[1] == "households"
            && parts[3] == "item-photos"
            && UUID(uuidString: parts[4]) != nil
        // v1 / product-photos / {photo_id}
        let productPhoto = parts.count == 3
            && parts[0] == "v1"
            && parts[1] == "product-photos"
            && UUID(uuidString: parts[2]) != nil
        return itemPhoto || productPhoto
    }

    /// GET request carrying the bearer token; nil when the user is signed out.
    static func request(for url: URL, token: String?) -> URLRequest? {
        guard let token, !token.isEmpty else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Accept")
        RequestTracing.apply(to: &request)
        request.cachePolicy = .returnCacheDataElseLoad
        return request
    }
}

/// The current bearer token for image loads, mirrored from `AppSession.idToken`
/// so loaders off the main actor never have to touch the session.
final class PrivateImageAuth: @unchecked Sendable {
    static let shared = PrivateImageAuth()
    private let lock = NSLock()
    private var _token: String?

    var token: String? {
        get { lock.withLock { _token } }
        set { lock.withLock { _token = newValue } }
    }
}

/// Fetches private photos with the bearer token and keeps decoded images in memory.
actor PrivateImageLoader {
    static let shared = PrivateImageLoader()

    enum LoadError: Error { case signedOut, badResponse(Int), undecodable }

    private let cache = NSCache<NSString, UIImage>()
    private var inFlight: [URL: Task<UIImage, Error>] = [:]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        cache.countLimit = 200
    }

    func image(for url: URL) async throws -> UIImage {
        if let cached = cache.object(forKey: url.absoluteString as NSString) {
            return cached
        }
        if let running = inFlight[url] {
            return try await running.value
        }
        let task = Task<UIImage, Error> {
            guard let request = PrivateItemPhoto.request(for: url, token: PrivateImageAuth.shared.token) else {
                throw LoadError.signedOut
            }
            let (data, response) = try await session.data(for: request, delegate: DropAuthorizationOnRedirect())
            guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                throw LoadError.badResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
            }
            guard let image = UIImage(data: data) else { throw LoadError.undecodable }
            return image
        }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        let image = try await task.value
        cache.setObject(image, forKey: url.absoluteString as NSString)
        return image
    }

    func evict(_ url: URL) {
        cache.removeObject(forKey: url.absoluteString as NSString)
    }
}

/// Product photos 302 to a signed Cloud Storage URL, which must not also carry
/// the API bearer token.
final class DropAuthorizationOnRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        var next = request
        if next.url?.host?.lowercased() != task.originalRequest?.url?.host?.lowercased() {
            next.setValue(nil, forHTTPHeaderField: "Authorization")
        }
        return next
    }
}

/// Drop-in for `AsyncImage` that routes household-private and product photo URLs
/// through `PrivateImageLoader`; everything else still uses `AsyncImage`.
struct MekasaRemoteImage<Content: View>: View {
    let url: URL
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    var body: some View {
        let resolved = PrivateItemPhoto.resolve(url)
        if PrivateItemPhoto.isPrivate(resolved) {
            content(phase)
                .task(id: resolved) {
                    phase = .empty
                    do {
                        let image = try await PrivateImageLoader.shared.image(for: resolved)
                        phase = .success(Image(uiImage: image))
                    } catch {
                        phase = .failure(error)
                    }
                }
        } else {
            AsyncImage(url: resolved, content: content)
        }
    }
}

/// Small JPEG kept for one `image_url`, so list thumbnails do not re-download
/// the full picture (UI-006 AC8).
enum ThumbnailImage {
    /// 56 pt at 3x, with a little room for the 48 pt duplicate row.
    static let maxPixel: CGFloat = 192
    static let quality: CGFloat = 0.7

    /// Longest edge at most `maxPixel`. Images that are already smaller are not enlarged.
    static func jpegData(from image: UIImage) -> Data? {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longest = max(pixelWidth, pixelHeight)
        guard longest > 0 else { return nil }
        let fitted: CGSize
        if longest <= maxPixel {
            fitted = CGSize(width: pixelWidth, height: pixelHeight)
        } else {
            let scale = maxPixel / longest
            fitted = CGSize(width: floor(pixelWidth * scale), height: floor(pixelHeight * scale))
        }
        guard fitted.width >= 1, fitted.height >= 1 else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: fitted, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: fitted))
        }
        return rendered.jpegData(compressionQuality: quality)
    }
}

/// On-device database of thumbnail JPEGs keyed by the resolved image URL.
/// The index and the picture files live together under Application Support,
/// in a source file the app target already compiles.
final class ThumbnailStore: @unchecked Sendable {
    struct Entry: Codable, Equatable {
        var url: String
        var storedAt: TimeInterval
    }

    static let shared: ThumbnailStore = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return ThumbnailStore(directory: base.appendingPathComponent("thumbnails", isDirectory: true))
    }()

    static let defaultCapacity = 400

    private let lock = NSLock()
    private let directory: URL
    private let indexURL: URL
    private let capacity: Int
    private let memory = NSCache<NSString, UIImage>()
    private var entries: [Entry] = []
    private var epoch = 0

    /// Bumps on `removeAll` so a download that started before sign-out is not written back.
    var generation: Int {
        lock.lock()
        defer { lock.unlock() }
        return epoch
    }

    init(directory: URL, capacity: Int = ThumbnailStore.defaultCapacity) {
        self.directory = directory
        self.indexURL = directory.appendingPathComponent("index.json")
        self.capacity = capacity
        memory.countLimit = capacity
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: indexURL),
           let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = decoded
        }
    }

    func jpeg(for url: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        guard entries.contains(where: { $0.url == url }) else { return nil }
        return try? Data(contentsOf: fileURL(for: url))
    }

    /// Decoded thumbnail, from memory when this process has already read the row.
    func image(for url: String) -> UIImage? {
        let key = url as NSString
        if let cached = memory.object(forKey: key) { return cached }
        guard let jpeg = jpeg(for: url), let image = UIImage(data: jpeg) else { return nil }
        memory.setObject(image, forKey: key)
        return image
    }

    func save(_ jpeg: Data, for url: String) {
        guard !jpeg.isEmpty, jpeg.count < 1_000_000 else { return }
        lock.lock()
        defer { lock.unlock() }
        let file = fileURL(for: url)
        do {
            try jpeg.write(to: file, options: .atomic)
        } catch {
            return
        }
        entries.removeAll { $0.url == url }
        entries.append(Entry(url: url, storedAt: Date().timeIntervalSince1970))
        memory.removeObject(forKey: url as NSString)
        pruneLocked()
        persistLocked()
    }

    func remember(_ image: UIImage, for url: String) {
        memory.setObject(image, forKey: url as NSString)
    }

    func count() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        epoch += 1
        memory.removeAllObjects()
        entries = []
        if let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
        persistLocked()
    }

    private func fileURL(for url: String) -> URL {
        let digest = SHA256.hash(data: Data(url.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined() + ".jpg"
        return directory.appendingPathComponent(name)
    }

    private func pruneLocked() {
        guard capacity > 0, entries.count > capacity else { return }
        let keep = entries.sorted { $0.storedAt > $1.storedAt }.prefix(capacity)
        let kept = Set(keep.map(\.url))
        for entry in entries where !kept.contains(entry.url) {
            try? FileManager.default.removeItem(at: fileURL(for: entry.url))
        }
        entries = Array(keep)
    }

    private func persistLocked() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}

/// Authenticated GET for a thumbnail source. Public catalog images need no token.
enum ThumbnailRequest {
    enum Failure: Error { case badResponse(Int), empty }

    static func make(for url: URL, token: String?) -> URLRequest {
        let resolved = PrivateItemPhoto.resolve(url)
        if PrivateItemPhoto.isPrivate(resolved), let authed = PrivateItemPhoto.request(for: resolved, token: token) {
            return authed
        }
        var request = URLRequest(url: resolved)
        request.httpMethod = "GET"
        request.cachePolicy = .returnCacheDataElseLoad
        RequestTracing.apply(to: &request)
        return request
    }

    static func data(for url: URL, session: URLSession, token: String?) async throws -> Data {
        let request = make(for: url, token: token)
        let (data, response) = try await session.data(for: request, delegate: DropAuthorizationOnRedirect())
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw Failure.badResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard !data.isEmpty else { throw Failure.empty }
        return data
    }
}

/// Downloads a picture once, stores a small JPEG, and serves that from then on.
actor ThumbnailLoader {
    static let shared = ThumbnailLoader(store: .shared)

    private let store: ThumbnailStore
    private let session: URLSession
    private let token: @Sendable () -> String?
    private let fetchOverride: (@Sendable (URL) async throws -> Data)?
    private var inFlight: [String: Task<UIImage, Error>] = [:]

    init(
        store: ThumbnailStore,
        session: URLSession = .shared,
        token: @escaping @Sendable () -> String? = { PrivateImageAuth.shared.token },
        fetch: (@Sendable (URL) async throws -> Data)? = nil
    ) {
        self.store = store
        self.session = session
        self.token = token
        self.fetchOverride = fetch
    }

    /// Start filling the local database. Visible rows share the same in-flight download.
    static func prefetch(_ urlStrings: [String]) {
        let urls = urlStrings
        Task { await shared.prefetch(urls) }
    }

    static func cancelPrefetch() {
        Task { await shared.cancelAll() }
    }

    func image(for url: URL) async throws -> UIImage {
        let key = PrivateItemPhoto.resolve(url).absoluteString
        if let cached = store.image(for: key) { return cached }
        if let running = inFlight[key] { return try await running.value }
        let store = self.store
        let started = store.generation
        let session = self.session
        let token = self.token
        let fetchOverride = self.fetchOverride
        let task = Task<UIImage, Error> {
            let data: Data
            if let fetchOverride {
                data = try await fetchOverride(url)
            } else {
                data = try await ThumbnailRequest.data(for: url, session: session, token: token())
            }
            try Task.checkCancellation()
            guard store.generation == started else { throw CancellationError() }
            guard let decoded = UIImage(data: data),
                  let jpeg = ThumbnailImage.jpegData(from: decoded),
                  let small = UIImage(data: jpeg)
            else { throw ThumbnailRequest.Failure.empty }
            try Task.checkCancellation()
            guard store.generation == started else { throw CancellationError() }
            store.save(jpeg, for: key)
            store.remember(small, for: key)
            return small
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        return try await task.value
    }

    func prefetch(_ urlStrings: [String]) async {
        let urls = urlStrings.compactMap(URL.init(string:))
        var index = 0
        while index < urls.count {
            let end = min(index + 4, urls.count)
            let batch = urls[index ..< end]
            index = end
            await withTaskGroup(of: Void.self) { group in
                for url in batch {
                    group.addTask { _ = try? await self.image(for: url) }
                }
            }
        }
    }

    func cancelAll() {
        for task in inFlight.values { task.cancel() }
        inFlight.removeAll()
    }
}
