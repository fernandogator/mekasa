import UIKit
import UserNotifications

/// Configures Firebase as early as possible in the UIKit lifecycle.
/// Satisfies: REQ-001, REQ-020, PRD §8
/// Spec version: 1.0
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseBootstrap.configure()
        PushRegistrationService.shared.configureIfNeeded()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushRegistrationService.shared.handleAPNsToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[Mekasa] APNs registration failed: \(error.localizedDescription)")
    }
}
