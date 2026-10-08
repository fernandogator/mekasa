import UIKit
import XCTest
@testable import Mekasa

/// On-device log, error reports, Send diagnostics and crash identity (NFR-007).
/// Satisfies: NFR-007 (App Error Reports and Diagnostics)
/// Acceptance criteria: AC1, AC2, AC5, AC6, AC7
final class AppDiagnosticsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AppLog.shared.reset()
        AppLog.shared.systemLog = false
        ErrorReporter.shared.reset()
        StubAPIProtocol.reset()
        URLProtocol.registerClass(StubAPIProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(StubAPIProtocol.self)
        AppLog.shared.reset()
        AppLog.shared.systemLog = true
        ErrorReporter.shared.reset()
        super.tearDown()
    }

    private func report(_ id: String) -> ErrorReport {
        ErrorReport(id: id, time: "t", whereName: "test", errorType: "Error", message: "m")
    }

    // MARK: - AC1 / AC7

    func testEntriesMaskEmailsAndTokensRedactSecretFieldsAndCapLength() {
        let entry = AppLog.shared.info(
            "auth",
            "Signed in as ana@example.com with Bearer abc.def-123",
            fields: ["email": "ana@example.com", "token": "abc", "item": "Diet Coke", "skip": nil as String?]
        )
        XCTAssertFalse(entry.message.contains("ana@example.com"))
        XCTAssertFalse(entry.message.contains("abc.def-123"))
        XCTAssertEqual(entry.fields["email"], LogPrivacy.redacted)
        XCTAssertEqual(entry.fields["token"], LogPrivacy.redacted)
        XCTAssertEqual(entry.fields["item"], "Diet Coke")
        XCTAssertNil(entry.fields["skip"])

        let long = AppLog.shared.info("app", String(repeating: "x", count: 2_000))
        XCTAssertLessThanOrEqual(long.message.count, LogPrivacy.maxText + 1)
    }

    func testTheLogKeepsOnlyTheLast500Entries() {
        for index in 0 ..< AppLog.capacity + 25 {
            AppLog.shared.debug("app", "entry \(index)")
        }
        let entries = AppLog.shared.snapshot()
        XCTAssertEqual(entries.count, AppLog.capacity)
        XCTAssertEqual(entries.first?.message, "entry 25")
        XCTAssertEqual(entries.last?.message, "entry \(AppLog.capacity + 24)")
    }

    func testTheLogSurvivesARelaunchThroughItsFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("log.jsonl")
        AppLog.shared.install(fileURL: url)
        AppLog.shared.info("app", "before relaunch")

        let written = expectation(description: "file written")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { written.fulfill() }
        wait(for: [written], timeout: 2)

        AppLog.shared.reset()
        AppLog.shared.install(fileURL: url)
        XCTAssertEqual(AppLog.shared.snapshot().map(\.message), ["before relaunch"])
    }

    // MARK: - AC2

    func testAnErrorQueuesAReportWithTheFailedCallAndThe20EntriesBeforeIt() {
        ErrorReporter.shared.isEnabled = true
        for index in 0 ..< 30 {
            AppLog.shared.info("app", "step \(index)")
        }
        let body = #"{"detail":"boom"}"#
        AppLog.shared.recordFailedCall(
            FailedCall(status: 500, detail: body, path: "/v1/households/hh-1/inventory", requestID: "r1", correlationID: "c1")
        )

        let entry = AppLog.shared.error(at: "session.consume", error: APIError.server(status: 500, detail: body), message: "Couldn’t sync consume")

        XCTAssertEqual(entry.level, .error)
        XCTAssertEqual(entry.message, "session.consume failed: Couldn’t sync consume")
        let report = try? XCTUnwrap(ErrorReporter.shared.queued().first)
        XCTAssertEqual(ErrorReporter.shared.queued().count, 1)
        XCTAssertEqual(report?.whereName, "session.consume")
        XCTAssertEqual(report?.errorType, "APIError")
        XCTAssertEqual(report?.status, 500)
        XCTAssertEqual(report?.message, "Couldn’t sync consume [boom]")
        XCTAssertEqual(report?.path, "/v1/households/hh-1/inventory")
        XCTAssertEqual(report?.requestID, "r1")
        XCTAssertEqual(report?.correlationID, "c1")
        XCTAssertEqual(report?.breadcrumbs.count, AppLog.breadcrumbs)
        XCTAssertEqual(report?.breadcrumbs.first?.message, "step 10")
        XCTAssertEqual(report?.breadcrumbs.last?.message, "step 29")
    }

    func testNothingIsQueuedWhileReportingIsOff() {
        AppLog.shared.error(at: "session.consume", message: "boom")
        XCTAssertTrue(ErrorReporter.shared.queued().isEmpty)
    }

    func testTheQueueKeepsTheNewest50Reports() {
        ErrorReporter.shared.isEnabled = true
        for index in 0 ..< ErrorReporter.maxQueued + 5 {
            ErrorReporter.shared.enqueue(report("r\(index)"))
        }
        let queued = ErrorReporter.shared.queued()
        XCTAssertEqual(queued.count, ErrorReporter.maxQueued)
        XCTAssertEqual(queued.first?.id, "r5")
    }

    func testFlushSendsBatchesOf20AndEmptiesTheQueue() async {
        ErrorReporter.shared.isEnabled = true
        for index in 0 ..< 45 {
            ErrorReporter.shared.enqueue(report("r\(index)"))
        }
        let batches = BatchRecorder()
        ErrorReporter.shared.setUploader { await batches.add($0) }

        let sent = await ErrorReporter.shared.flush()
        let sizes = await batches.sizes

        XCTAssertEqual(sent, 45)
        XCTAssertEqual(sizes, [20, 20, 5])
        XCTAssertTrue(ErrorReporter.shared.queued().isEmpty)
    }

    func testAFailedUploadKeepsTheReportsAndNeverCreatesAReport() async {
        ErrorReporter.shared.isEnabled = true
        for index in 0 ..< 3 {
            ErrorReporter.shared.enqueue(report("r\(index)"))
        }
        ErrorReporter.shared.setUploader { _ in throw APIError.server(status: 503, detail: "unavailable") }

        let sent = await ErrorReporter.shared.flush()

        XCTAssertEqual(sent, 0)
        XCTAssertEqual(ErrorReporter.shared.queued().count, 3)
        let last = AppLog.shared.snapshot().last
        XCTAssertEqual(last?.level, .warning)
        XCTAssertEqual(last?.message, "Error report upload failed")
    }

    func testNothingIsSentWithoutAnUploader() async {
        ErrorReporter.shared.isEnabled = true
        ErrorReporter.shared.enqueue(report("r1"))
        let sent = await ErrorReporter.shared.flush()
        XCTAssertEqual(sent, 0)
        XCTAssertEqual(ErrorReporter.shared.queued().count, 1)
    }

    func testReportsEncodeInTheShapeTheAPIAccepts() throws {
        let batch = ClientErrorBatch(app: ClientApp(appVersion: "1.0.0"), reports: [report("r1")])
        let json = try XCTUnwrap(String(data: JSONEncoder().encode(batch), encoding: .utf8))
        XCTAssertTrue(json.contains(#""platform":"ios""#), json)
        XCTAssertTrue(json.contains(#""app_version":"1.0.0""#), json)
        XCTAssertTrue(json.contains(#""where":"test""#), json)
        XCTAssertTrue(json.contains(#""error_type":"Error""#), json)
    }

    // MARK: - Where errors are named

    func testWhereNamesComeFromTheCallingTypeAndFunction() {
        XCTAssertEqual(AppSession.whereName(function: "scanReceipt(imageData:)", file: "Mekasa/AppSession.swift"), "session.scanReceipt")
        XCTAssertEqual(AppSession.whereName(function: "uploadItemPhoto(_:)", file: "Mekasa/AppSession+ItemPhotos.swift"), "session.uploadItemPhoto")
        XCTAssertEqual(AppSession.whereName(function: "runScan(imageBase64:rawText:)", file: "Mekasa/ReceiptScanView.swift"), "receiptScan.runScan")
        XCTAssertEqual(AppSession.category(for: "receiptScan.runScan"), "receipt")
        XCTAssertEqual(AppSession.category(for: "session.uploadItemPhoto"), "photos")
    }

    @MainActor
    func testAnErrorShownBySessionIsLoggedWhereItHappened() async {
        ErrorReporter.shared.isEnabled = true
        let session = AppSession()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }

        let saved = await session.uploadHouseholdHomePhoto(image)

        XCTAssertFalse(saved)
        XCTAssertEqual(session.lastError, "Only household owners can change the home photo.")
        XCTAssertEqual(ErrorReporter.shared.queued().last?.whereName, "session.uploadHouseholdHomePhoto")
    }

    // MARK: - AC5

    @MainActor
    func testSendDiagnosticsIsUnavailableInTheOfflinePreview() async {
        let session = AppSession()
        session.startUIPreview()
        XCTAssertFalse(session.canSendDiagnostics)
        let result = await session.sendDiagnostics()
        XCTAssertEqual(result, AppSession.diagnosticsFailed)
        XCTAssertTrue(StubAPIProtocol.requests.isEmpty)
    }

    @MainActor
    func testSendDiagnosticsUploadsTheLogAndShowsTheReference() async throws {
        StubAPIProtocol.respond(status: 201, body: #"{"diagnostics_id":"3f9a12c7deadbeef","reference":"3F9A12C7","entries":2}"#)
        let session = AppSession()
        session.idToken = "token-1"
        AppLog.shared.info("app", "before upload")

        let result = await session.sendDiagnostics()

        XCTAssertEqual(result, "Sent. Reference 3F9A12C7")
        let request = try XCTUnwrap(StubAPIProtocol.requests.last)
        XCTAssertEqual(request.url?.path, "/v1/client-diagnostics")
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(StubAPIProtocol.bodies.last.flatMap { String(data: $0, encoding: .utf8) })
        XCTAssertTrue(body.contains("before upload"), body)
        XCTAssertTrue(body.contains(#""platform":"ios""#), body)
        session.idToken = nil
    }

    @MainActor
    func testSendDiagnosticsFailureShowsTheRetryLine() async {
        StubAPIProtocol.respond(status: 429, body: #"{"detail":"diagnostics_rate_limited"}"#)
        let session = AppSession()
        session.idToken = "token-1"

        let result = await session.sendDiagnostics()

        XCTAssertEqual(result, AppSession.diagnosticsFailed)
        session.idToken = nil
    }

    // MARK: - AC1 API entries

    func testEachAPICallLeavesOneEntryWithMethodPathStatusAndRequestID() async throws {
        StubAPIProtocol.respond(status: 200, body: #"{"status":"ok"}"#)
        _ = try await MekasaAPIClient.shared.health()

        let entry = try XCTUnwrap(AppLog.shared.snapshot().last { $0.category == "api" })
        XCTAssertEqual(entry.level, .info)
        XCTAssertEqual(entry.fields["method"], "GET")
        XCTAssertEqual(entry.fields["path"], "/health")
        XCTAssertEqual(entry.fields["status"], "200")
        XCTAssertNotNil(entry.fields["duration_ms"])
        XCTAssertEqual(entry.requestID, StubAPIProtocol.requests.last?.value(forHTTPHeaderField: RequestTracing.requestIDHeader))
    }

    func testAFailedCallIsAWarningAndItsErrorFindsTheCall() async throws {
        StubAPIProtocol.respond(status: 500, body: #"{"detail":"boom"}"#)
        do {
            _ = try await MekasaAPIClient.shared.health()
            XCTFail("expected a failure")
        } catch {
            let call = try XCTUnwrap(AppLog.shared.failedCall(for: error))
            XCTAssertEqual(call.status, 500)
            XCTAssertEqual(call.path, "/health")
            let entry = try XCTUnwrap(AppLog.shared.snapshot().last { $0.category == "api" })
            XCTAssertEqual(entry.level, .warning)
            XCTAssertEqual(entry.fields["detail"], "boom")
            XCTAssertEqual(call.requestID, entry.requestID)
        }
    }

    // MARK: - AC6

    func testCrashReportsIdentifyTheUserOnlyByTheAPIsUserRef() {
        XCTAssertEqual(CrashReporting.userRef("uid-1"), "4a49acf8a6bd")
        XCTAssertFalse(CrashReporting.isActive)
    }
}

private actor BatchRecorder {
    private(set) var sizes: [Int] = []

    func add(_ batch: ClientErrorBatch) {
        sizes.append(batch.reports.count)
    }
}

/// Answers every request with the configured status and body, and records requests.
private final class StubAPIProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var status = 200
    private static var body = Data("{}".utf8)
    private static var recorded: [URLRequest] = []
    private static var recordedBodies: [Data] = []

    static var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    static var bodies: [Data] {
        lock.lock()
        defer { lock.unlock() }
        return recordedBodies
    }

    static func respond(status: Int, body: String) {
        lock.lock()
        self.status = status
        self.body = Data(body.utf8)
        lock.unlock()
    }

    static func reset() {
        lock.lock()
        status = 200
        body = Data("{}".utf8)
        recorded = []
        recordedBodies = []
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.recorded.append(request)
        Self.recordedBodies.append(request.httpBody ?? Self.readStream(request.httpBodyStream))
        let status = Self.status
        let body = Self.body
        Self.lock.unlock()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// URLSession hands bodies to protocols as streams.
    private static func readStream(_ stream: InputStream?) -> Data {
        guard let stream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
