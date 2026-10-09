import SQLite3
import UIKit

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

/// SQLite database of thumbnail JPEGs keyed by the resolved image URL.
final class ThumbnailStore: @unchecked Sendable {
    static let shared: ThumbnailStore = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return ThumbnailStore(databaseURL: directory.appendingPathComponent("thumbnails.sqlite"))
    }()

    static let defaultCapacity = 400

    private let lock = NSLock()
    private var db: OpaquePointer?
    private let capacity: Int
    private let memory = NSCache<NSString, UIImage>()
    private var epoch = 0
    private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    /// Bumps on `removeAll` so a download that started before sign-out is not written back.
    var generation: Int {
        lock.lock()
        defer { lock.unlock() }
        return epoch
    }

    init(databaseURL: URL, capacity: Int = ThumbnailStore.defaultCapacity) {
        self.capacity = capacity
        memory.countLimit = capacity
        var opened: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &opened) == SQLITE_OK, let opened else {
            sqlite3_close(opened)
            return
        }
        db = opened
        sqlite3_exec(
            opened,
            """
            CREATE TABLE IF NOT EXISTS thumbnails (
                url TEXT PRIMARY KEY NOT NULL,
                jpeg BLOB NOT NULL,
                stored_at REAL NOT NULL
            );
            """,
            nil,
            nil,
            nil
        )
    }

    deinit {
        sqlite3_close(db)
    }

    func jpeg(for url: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        guard let db else { return nil }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT jpeg FROM thumbnails WHERE url = ?", -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }
        bind(url, to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_ROW, let bytes = sqlite3_column_blob(statement, 0) else {
            return nil
        }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
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
        guard let db else { return }
        var statement: OpaquePointer?
        let sql = """
        INSERT INTO thumbnails (url, jpeg, stored_at) VALUES (?, ?, ?)
        ON CONFLICT(url) DO UPDATE SET jpeg = excluded.jpeg, stored_at = excluded.stored_at
        """
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        bind(url, to: statement, at: 1)
        jpeg.withUnsafeBytes { raw in
            _ = sqlite3_bind_blob(statement, 2, raw.baseAddress, Int32(jpeg.count), sqliteTransient)
        }
        sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)
        guard sqlite3_step(statement) == SQLITE_DONE else { return }
        memory.removeObject(forKey: url as NSString)
        pruneLocked()
    }

    func remember(_ image: UIImage, for url: String) {
        memory.setObject(image, forKey: url as NSString)
    }

    func count() -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard let db else { return 0 }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM thumbnails", -1, &statement, nil) == SQLITE_OK else {
            return 0
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(statement, 0))
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        epoch += 1
        memory.removeAllObjects()
        guard let db else { return }
        sqlite3_exec(db, "DELETE FROM thumbnails", nil, nil, nil)
    }

    private func pruneLocked() {
        guard let db, capacity > 0 else { return }
        var statement: OpaquePointer?
        let sql = "DELETE FROM thumbnails WHERE url IN (SELECT url FROM thumbnails ORDER BY stored_at DESC LIMIT -1 OFFSET ?)"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(capacity))
        sqlite3_step(statement)
    }

    private func bind(_ text: String, to statement: OpaquePointer?, at index: Int32) {
        text.withCString { cString in
            sqlite3_bind_text(statement, index, cString, -1, sqliteTransient)
        }
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
