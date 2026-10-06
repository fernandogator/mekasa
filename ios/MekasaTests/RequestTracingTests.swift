import XCTest
@testable import Mekasa

/// Request ids on every call and the receipt flow's correlation id (NFR-006).
/// Satisfies: NFR-006 (Request Tracing and Diagnostic Logs)
/// Acceptance criteria: AC1, AC7
final class RequestTracingTests: XCTestCase {
    override func setUp() {
        super.setUp()
        HeaderCapturingProtocol.reset()
        URLProtocol.registerClass(HeaderCapturingProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(HeaderCapturingProtocol.self)
        super.tearDown()
    }

    func testNewIDsAreUniqueHexThatTheBackendAccepts() {
        let first = RequestTracing.newID()
        let second = RequestTracing.newID()
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(first.count, 32)
        XCTAssertNil(first.range(of: "[^0-9a-f]", options: .regularExpression))
    }

    func testApplyAddsRequestIDAndOnlyAddsCorrelationInsideAFlow() {
        var outside = URLRequest(url: URL(string: "https://example.com/v1/me")!)
        RequestTracing.apply(to: &outside)
        XCTAssertNotNil(outside.value(forHTTPHeaderField: "X-Request-ID"))
        XCTAssertNil(outside.value(forHTTPHeaderField: "X-Correlation-ID"))

        let inside = RequestTracing.$correlationID.withValue("receipt-flow-0001") { () -> URLRequest in
            var request = URLRequest(url: URL(string: "https://example.com/v1/me")!)
            RequestTracing.apply(to: &request)
            return request
        }
        XCTAssertEqual(inside.value(forHTTPHeaderField: "X-Correlation-ID"), "receipt-flow-0001")
        XCTAssertNotEqual(
            inside.value(forHTTPHeaderField: "X-Request-ID"),
            outside.value(forHTTPHeaderField: "X-Request-ID")
        )
    }

    func testAPIClientSendsANewRequestIDPerCallAndTheFlowCorrelation() async throws {
        _ = try? await MekasaAPIClient.shared.health()
        _ = try? await RequestTracing.$correlationID.withValue("receipt-flow-0002") {
            try await MekasaAPIClient.shared.health()
        }

        let headers = HeaderCapturingProtocol.captured
        XCTAssertEqual(headers.count, 2)
        let ids = headers.compactMap { $0["X-Request-ID"] }
        XCTAssertEqual(Set(ids).count, 2)
        XCTAssertNil(headers.first?["X-Correlation-ID"])
        XCTAssertEqual(headers.last?["X-Correlation-ID"], "receipt-flow-0002")
    }

    func testPrivatePhotoRequestsCarryARequestID() throws {
        let url = URL(string: "https://mekasa-api.example.run.app/v1/product-photos/0b5c7e4e-7f3e-4d0c-9c1e-6d2b8a9f1c22")!
        let request = try XCTUnwrap(PrivateItemPhoto.request(for: url, token: "tok-123"))
        XCTAssertNotNil(request.value(forHTTPHeaderField: "X-Request-ID"))
    }

    @MainActor
    func testBeginReceiptFlowStartsANewCorrelationEachScan() {
        let session = AppSession()
        XCTAssertNil(session.receiptFlowID)
        let first = session.beginReceiptFlow()
        XCTAssertEqual(session.receiptFlowID, first)
        let second = session.beginReceiptFlow()
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(session.receiptFlowID, second)
    }
}

/// Records request headers and answers every request with an empty JSON object.
private final class HeaderCapturingProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var headers: [[String: String]] = []

    static var captured: [[String: String]] {
        lock.lock()
        defer { lock.unlock() }
        return headers
    }

    static func reset() {
        lock.lock()
        headers = []
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.headers.append(request.allHTTPHeaderFields ?? [:])
        Self.lock.unlock()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
