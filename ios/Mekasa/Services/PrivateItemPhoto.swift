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
