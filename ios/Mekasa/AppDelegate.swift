import UIKit
#if canImport(FirebaseCore)
import FirebaseCore
#endif

/// Configures Firebase as early as possible in the UIKit lifecycle.
/// Satisfies: REQ-001
/// Spec version: 1.0
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Self.configureFirebaseIfNeeded()
        return true
    }

    static func configureFirebaseIfNeeded() {
        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif
    }
}
