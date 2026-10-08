import CryptoKit
import Foundation
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

/// Firebase Crashlytics for crashes, with the recent `AppLog` entries attached as
/// Crashlytics logs. Collection starts off (`FirebaseCrashlyticsCollectionEnabled`
/// in Info.plist) and is turned on only for release builds with a real Firebase project.
/// Satisfies: NFR-007 (App Error Reports and Diagnostics) AC6
/// Spec version: 1.0
enum CrashReporting {
    private static let attachedEntries = 64
    private(set) static var isActive = false

    /// Call after `FirebaseBootstrap.configure()`.
    static func start(enabled: Bool) {
        guard enabled, !isActive else { return }
        #if canImport(FirebaseCrashlytics)
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCrashlyticsCollectionEnabled(true)
        AppLog.shared.recent(attachedEntries).forEach { crashlytics.log(AppLog.line($0)) }
        AppLog.shared.addSink { entry in Crashlytics.crashlytics().log(AppLog.line(entry)) }
        isActive = true
        #endif
    }

    /// The user appears only as `userRef` (NFR-006 AC6).
    static func setUser(uid: String?) {
        guard isActive else { return }
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setUserID(uid.map(userRef) ?? "")
        #endif
    }

    /// First 12 hex characters of SHA-256(uid), the same `user_ref` the API logs.
    static func userRef(_ uid: String) -> String {
        String(SHA256.hash(data: Data(uid.utf8)).map { String(format: "%02x", $0) }.joined().prefix(12))
    }
}
