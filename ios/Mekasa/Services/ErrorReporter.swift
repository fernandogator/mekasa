import Foundation

/// Queues error reports in Application Support and sends them to
/// `POST /v1/client-errors` while signed in: shortly after an error and when the
/// app comes back to the foreground. Off unless `isEnabled` (the app turns it on
/// outside previews, UI tests and unit tests).
/// Satisfies: NFR-007 (App Error Reports and Diagnostics) AC2
/// Spec version: 1.0
final class ErrorReporter: @unchecked Sendable {
    typealias Uploader = @Sendable (ClientErrorBatch) async throws -> Void

    static let shared = ErrorReporter()
    static let maxQueued = 50
    static let batchSize = 20
    static let flushDelay: TimeInterval = 3

    private let lock = NSLock()
    private var queue: [ErrorReport] = []
    private var fileURL: URL?
    private var uploader: Uploader?
    private var scheduled: Task<Void, Never>?
    private var isFlushing = false
    private var enabled = false
    private var clientApp = ClientApp()
    private let io = DispatchQueue(label: "app.mekasa.errorreporter", qos: .utility)

    var isEnabled: Bool {
        get { locked { enabled } }
        set { locked { enabled = newValue } }
    }

    var app: ClientApp {
        get { locked { clientApp } }
        set { locked { clientApp = newValue } }
    }

    static var defaultFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("diagnostics", isDirectory: true)
            .appendingPathComponent("reports.json")
    }

    func install(fileURL url: URL?, app: ClientApp) {
        var loaded: [ErrorReport] = []
        if let url, let data = try? Data(contentsOf: url) {
            loaded = (try? JSONDecoder().decode([ErrorReport].self, from: data)) ?? []
        }
        locked {
            queue = Array(loaded.suffix(Self.maxQueued))
            fileURL = url
            clientApp = app
        }
    }

    /// Set while signed in to a real household; nil when signed out or in the preview.
    func setUploader(_ upload: Uploader?) {
        locked { uploader = upload }
        if upload != nil { flushSoon(after: 0) }
    }

    func enqueue(_ report: ErrorReport) {
        let saved: [ErrorReport]? = locked {
            guard enabled else { return nil }
            queue.append(report)
            if queue.count > Self.maxQueued { queue.removeFirst(queue.count - Self.maxQueued) }
            return queue
        }
        guard let saved else { return }
        save(saved)
        flushSoon()
    }

    func queued() -> [ErrorReport] {
        locked { queue }
    }

    func flushSoon(after delay: TimeInterval = ErrorReporter.flushDelay) {
        locked {
            guard enabled, uploader != nil, scheduled == nil else { return }
            scheduled = Task.detached(priority: .utility) { [weak self] in
                if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
                guard let self else { return }
                self.locked { self.scheduled = nil }
                _ = await self.flush()
            }
        }
    }

    /// Sends queued reports in batches; stops at the first failure and keeps the
    /// rest for later. A failed upload is only a warning, so it never queues a report.
    @discardableResult
    func flush() async -> Int {
        let start: Bool = locked {
            guard !isFlushing else { return false }
            isFlushing = true
            return true
        }
        guard start else { return 0 }
        defer { locked { isFlushing = false } }

        var sent = 0
        while true {
            let next: (Uploader, [ErrorReport], ClientApp)? = locked {
                guard let uploader, !queue.isEmpty else { return nil }
                return (uploader, Array(queue.prefix(Self.batchSize)), clientApp)
            }
            guard let next else { break }
            let (upload, batch, app) = next
            do {
                try await upload(ClientErrorBatch(app: app, reports: batch))
            } catch {
                AppLog.shared.warning(
                    "app",
                    "Error report upload failed",
                    fields: ["queued": queued().count, "error_type": String(describing: type(of: error))]
                )
                break
            }
            let ids = Set(batch.map(\.id))
            let remaining = locked {
                queue.removeAll { ids.contains($0.id) }
                return queue
            }
            save(remaining)
            sent += batch.count
        }
        return sent
    }

    /// Unit tests: empty queue, no disk, no uploader.
    func reset() {
        locked {
            queue = []
            scheduled?.cancel()
            scheduled = nil
            fileURL = nil
            uploader = nil
            enabled = false
            isFlushing = false
            clientApp = ClientApp()
        }
    }

    private func save(_ reports: [ErrorReport]) {
        guard let url = locked({ fileURL }) else { return }
        io.async {
            guard let data = try? JSONEncoder().encode(reports) else { return }
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? data.write(to: url, options: .atomic)
        }
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
