import UIKit

/// Configures Firebase as early as possible in the UIKit lifecycle.
/// Satisfies: REQ-001
/// Spec version: 1.0
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseBootstrap.configure()
        return true
    }
}
