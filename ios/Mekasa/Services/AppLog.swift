import Foundation
import os

/// One on-device log entry, in the shape the API's diagnostics and error-report
/// endpoints accept.
/// Satisfies: NFR-007 (App Error Reports and Diagnostics) AC1
/// Spec version: 1.0
struct LogEntry: Codable, Equatable, Sendable {
    enum Level: String, Codable, Sendable {
        case debug, info, warning, error
    }

    var time: String
    var level: Level
    var category: String
    var message: String
    var requestID: String?
    var correlationID: String?
    var fields: [String: String] = [:]

    enum CodingKeys: String, CodingKey {
        case time, level, category, message, fields
        case requestID = "request_id"
        case correlationID = "correlation_id"
    }
}

/// NFR-007 AC2: an error plus the entries that led up to it.
struct ErrorReport: Codable, Equatable, Sendable {
    var id: String
    var time: String
    var whereName: String
    var errorType: String
    var message: String
    var status: Int?
    var path: String?
    var requestID: String?
    var correlationID: String?
    var breadcrumbs: [LogEntry] = []

    enum CodingKeys: String, CodingKey {
        case id, time, message, status, path, breadcrumbs
        case whereName = "where"
        case errorType = "error_type"
        case requestID = "request_id"
        case correlationID = "correlation_id"
    }
}

/// Which build sent a report (NFR-007 AC3).
struct ClientApp: Codable, Equatable, Sendable {
    var platform = "ios"
    var appVersion = ""
    var build = ""
    var osVersion = ""
    var deviceModel = ""

    enum CodingKeys: String, CodingKey {
        case platform, build
        case appVersion = "app_version"
        case osVersion = "os_version"
        case deviceModel = "device_model"
    }
}

struct ClientErrorBatch: Codable, Sendable {
    let app: ClientApp
    let reports: [ErrorReport]
}

struct ClientErrorBatchResponse: Decodable, Sendable {
    let accepted: Int
    let dropped: Int
}

struct ClientDiagnosticsUpload: Codable, Sendable {
    let app: ClientApp
    var note: String?
    let entries: [LogEntry]
}

struct ClientDiagnosticsResponse: Decodable, Sendable {
    let diagnosticsID: String
    let reference: String
    let entries: Int

    enum CodingKeys: String, CodingKey {
        case reference, entries
        case diagnosticsID = "diagnostics_id"
    }
}

/// What may be written to the on-device log (NFR-007 AC7, NFR-006 AC6): no tokens,
/// passwords, emails, street addresses, phone numbers, household or person names.
/// Item names, receipt line text and barcodes are fine.
/// Satisfies: NFR-007 AC7; NFR-002 AC3
/// Spec version: 1.0
enum LogPrivacy {
    static let redacted = "[redacted]"
    static let maxText = 500

    private static let secretKeys: Set<String> = [
        "authorization", "token", "id_token", "fcm_token", "invite_token", "password",
        "email", "address", "street", "phone", "display_name", "household_name", "member_name",
    ]

    static func text(_ value: String) -> String {
        var masked = value.replacingOccurrences(
            of: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
            with: redacted,
            options: .regularExpression
        )
        masked = masked.replacingOccurrences(
            of: "(?i)bearer\\s+[A-Za-z0-9._:\\-]+",
            with: "Bearer \(redacted)",
            options: .regularExpression
        )
        return masked.count <= maxText ? masked : String(masked.prefix(maxText)) + "…"
    }

    static func fields(_ values: [String: Any?]) -> [String: String] {
        var out: [String: String] = [:]
        for (key, value) in values {
            guard let value, let plain = unwrap(value) else { continue }
            out[key] = secretKeys.contains(key.lowercased()) ? redacted : text(String(describing: plain))
        }
        return out
    }

    /// `Any` can still hold an optional (e.g. `Int??`); nil at any depth is dropped.
    private static func unwrap(_ value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else { return value }
        guard let child = mirror.children.first else { return nil }
        return unwrap(child.value)
    }
}

/// The call an `APIError` came from: the API client records each failed response
/// so the error log can name its path and ids.
struct FailedCall: Equatable, Sendable {
    let status: Int
    let detail: String
    let path: String
    let requestID: String?
    let correlationID: String?
}

/// The app's log: the last `capacity` entries in memory and in Application Support,
/// mirrored to `os.Logger` (subsystem `app.mekasa`) and any extra sinks such as
/// Crashlytics. Every `error` also becomes an `ErrorReport` for `ErrorReporter`.
/// Satisfies: NFR-007 (App Error Reports and Diagnostics) AC1, AC2, AC7
/// Spec version: 1.0
final class AppLog: @unchecked Sendable {
    static let shared = AppLog()
    static let capacity = 500
    static let breadcrumbs = 20
    static let subsystem = "app.mekasa"

    private let lock = NSLock()
    private var entries: [LogEntry] = []
    private var failedCalls: [FailedCall] = []
    private var sinks: [@Sendable (LogEntry) -> Void] = []
    private var fileURL: URL?
    private var appendsSinceRewrite = 0
    private let io = DispatchQueue(label: "app.mekasa.applog", qos: .utility)
    var systemLog = true
    var now: @Sendable () -> Date = { Date() }

    private static let timeFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static var defaultFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("diagnostics", isDirectory: true)
            .appendingPathComponent("log.jsonl")
    }

    /// Loads the entries kept from earlier launches and keeps writing to [url].
    func install(fileURL url: URL?) {
        var loaded: [LogEntry] = []
        if let url, let text = try? String(contentsOf: url, encoding: .utf8) {
            let decoder = JSONDecoder()
            loaded = text.split(separator: "\n").compactMap { line in
                try? decoder.decode(LogEntry.self, from: Data(line.utf8))
            }
        }
        lock.lock()
        entries = Array(loaded.suffix(Self.capacity))
        fileURL = url
        lock.unlock()
    }

    func addSink(_ sink: @escaping @Sendable (LogEntry) -> Void) {
        lock.lock()
        sinks.append(sink)
        lock.unlock()
    }

    func snapshot() -> [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    func recent(_ count: Int) -> [LogEntry] {
        Array(snapshot().suffix(count))
    }

    /// Unit tests: forget everything and stop writing to disk.
    func reset() {
        lock.lock()
        entries = []
        failedCalls = []
        sinks = []
        fileURL = nil
        appendsSinceRewrite = 0
        lock.unlock()
        now = { Date() }
    }

    // MARK: - Writing

    @discardableResult
    func debug(_ category: String, _ message: String, fields: [String: Any?] = [:]) -> LogEntry {
        write(.debug, category, message, fields: fields)
    }

    @discardableResult
    func info(
        _ category: String,
        _ message: String,
        fields: [String: Any?] = [:],
        requestID: String? = nil,
        correlationID: String? = nil
    ) -> LogEntry {
        write(.info, category, message, fields: fields, requestID: requestID, correlationID: correlationID)
    }

    @discardableResult
    func warning(
        _ category: String,
        _ message: String,
        fields: [String: Any?] = [:],
        requestID: String? = nil,
        correlationID: String? = nil
    ) -> LogEntry {
        write(.warning, category, message, fields: fields, requestID: requestID, correlationID: correlationID)
    }

    /// An error the user saw or the app gave up on (AC1). `whereName` names the
    /// place, e.g. `session.scanReceipt`. Queues a report with the entries before it (AC2).
    @discardableResult
    func error(
        at whereName: String,
        error: Error? = nil,
        message: String? = nil,
        category: String = "app",
        correlationID: String? = nil,
        fields: [String: Any?] = [:]
    ) -> LogEntry {
        let call = error.flatMap(failedCall(for:))
        let callDetail = call.map { Self.apiDetail($0.detail) }
        let type = error.map { String(describing: Swift.type(of: $0)) } ?? "Error"
        let detail = message ?? callDetail ?? error?.localizedDescription ?? type
        let before = recent(Self.breadcrumbs)
        let extra = callDetail.flatMap { $0 == detail ? nil : $0 }
        var all: [String: Any?] = [
            "where": whereName,
            "error_type": type,
            "status": call?.status,
            "path": call?.path,
            "detail": extra,
        ]
        all.merge(fields) { _, new in new }
        let entry = write(
            .error,
            category,
            "\(whereName) failed: \(detail)",
            fields: all,
            requestID: call?.requestID,
            correlationID: call?.correlationID ?? correlationID
        )
        let reportMessage = extra.map { "\(detail) [\($0)]" } ?? detail
        ErrorReporter.shared.enqueue(
            ErrorReport(
                id: RequestTracing.newID(),
                time: entry.time,
                whereName: whereName,
                errorType: type,
                message: LogPrivacy.text(reportMessage),
                status: call?.status,
                path: call?.path,
                requestID: entry.requestID,
                correlationID: entry.correlationID,
                breadcrumbs: before
            )
        )
        return entry
    }

    // MARK: - Failed calls

    func recordFailedCall(_ call: FailedCall) {
        lock.lock()
        failedCalls.append(call)
        if failedCalls.count > 20 { failedCalls.removeFirst(failedCalls.count - 20) }
        lock.unlock()
    }

    /// The most recent failed response matching an `APIError`'s status and body.
    func failedCall(for error: Error) -> FailedCall? {
        guard let api = error as? APIError else { return nil }
        let status: Int
        let detail: String
        switch api {
        case let .unauthorized(d): status = 401; detail = d
        case let .server(s, d): status = s; detail = d
        case .invalidResponse: return nil
        }
        lock.lock()
        defer { lock.unlock() }
        return failedCalls.last { $0.status == status && $0.detail == detail }
    }

    /// The API's `{"detail": "..."}` code when the body is FastAPI JSON, else the body.
    static func apiDetail(_ body: String) -> String {
        guard let data = body.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let detail = object["detail"]
        else { return body }
        return (detail as? String) ?? String(describing: detail)
    }

    // MARK: - Plumbing

    @discardableResult
    private func write(
        _ level: LogEntry.Level,
        _ category: String,
        _ message: String,
        fields: [String: Any?],
        requestID: String? = nil,
        correlationID: String? = nil
    ) -> LogEntry {
        let entry = LogEntry(
            time: Self.timeFormatter.string(from: now()),
            level: level,
            category: category,
            message: LogPrivacy.text(message),
            requestID: requestID,
            correlationID: correlationID,
            fields: LogPrivacy.fields(fields)
        )
        lock.lock()
        entries.append(entry)
        if entries.count > Self.capacity { entries.removeFirst(entries.count - Self.capacity) }
        let listeners = sinks
        if let fileURL {
            appendsSinceRewrite += 1
            if appendsSinceRewrite >= Self.capacity {
                appendsSinceRewrite = 0
                let all = entries
                io.async { Self.rewrite(all, to: fileURL) }
            } else {
                io.async { Self.append(entry, to: fileURL) }
            }
        }
        lock.unlock()
        if systemLog {
            Logger(subsystem: Self.subsystem, category: category)
                .log(level: Self.osLevel(level), "\(Self.line(entry), privacy: .public)")
        }
        listeners.forEach { $0(entry) }
        return entry
    }

    /// One readable line, used for the system log and Crashlytics.
    static func line(_ entry: LogEntry) -> String {
        var text = "[\(entry.category)] \(entry.message)"
        if !entry.fields.isEmpty {
            text += " " + entry.fields.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        }
        if let cid = entry.correlationID { text += " cid=\(cid)" }
        if let rid = entry.requestID { text += " rid=\(rid)" }
        return text
    }

    private static func osLevel(_ level: LogEntry.Level) -> OSLogType {
        switch level {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }

    private static func append(_ entry: LogEntry, to url: URL) {
        guard var data = try? JSONEncoder().encode(entry) else { return }
        data.append(0x0A)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func rewrite(_ entries: [LogEntry], to url: URL) {
        let encoder = JSONEncoder()
        var data = Data()
        for entry in entries {
            guard let line = try? encoder.encode(entry) else { continue }
            data.append(line)
            data.append(0x0A)
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
