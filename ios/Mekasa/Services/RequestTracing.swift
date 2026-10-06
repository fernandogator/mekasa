import Foundation

/// Request and correlation ids for backend logs: every call carries a new
/// `X-Request-ID`; calls made inside a receipt flow also carry that flow's
/// `X-Correlation-ID`, bound with `RequestTracing.$correlationID.withValue(_:)`.
/// Satisfies: NFR-006 (Request Tracing and Diagnostic Logs) AC1, AC7
/// Spec version: 1.0
enum RequestTracing {
    static let requestIDHeader = "X-Request-ID"
    static let correlationIDHeader = "X-Correlation-ID"

    @TaskLocal static var correlationID: String?

    /// 32 lowercase hex characters, matching the backend's generated ids.
    static func newID() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    static func apply(to request: inout URLRequest) {
        request.setValue(newID(), forHTTPHeaderField: requestIDHeader)
        if let correlationID, !correlationID.isEmpty {
            request.setValue(correlationID, forHTTPHeaderField: correlationIDHeader)
        }
    }
}
