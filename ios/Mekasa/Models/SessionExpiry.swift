import Foundation

/// Helpers for detecting and messaging expired GCP / Firebase API sessions.
/// Satisfies: REQ-022
/// Spec version: 1.0
enum SessionExpiry {
    static let userMessage = "Your session expired. Please sign in again."

    static func isUnauthorized(_ error: Error) -> Bool {
        if let api = error as? APIError {
            return api.isUnauthorized
        }
        if let auth = error as? AuthServiceError, case .sessionExpired = auth {
            return true
        }
        return false
    }
}
