import Foundation

/// Helpers for detecting expired GCP / Firebase API sessions.
/// Satisfies: REQ-022
/// Spec version: 1.0
enum SessionExpiry {
    /// Kept for docs / legacy references; expired sessions sign out silently (no alert).
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
