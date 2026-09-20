import Foundation
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

/// Registers for remote notifications and posts FCM tokens to the API.
/// Satisfies: PRD §8 (push scaffold) + invite delivery hook
/// Spec version: 1.0
@MainActor
final class PushRegistrationService: NSObject, ObservableObject {
    static let shared = PushRegistrationService()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var fcmToken: String?
    @Published private(set) var lastError: String?

    private var pendingIDToken: String?

    func configureIfNeeded() {
        guard FirebaseBootstrap.isConfigured else { return }
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermissionAndRegister(idToken: String?) {
        pendingIDToken = idToken
        configureIfNeeded()
        guard FirebaseBootstrap.isConfigured else { return }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            Task { @MainActor in
                if let error {
                    self.lastError = error.localizedDescription
                }
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                self.authorizationStatus = settings.authorizationStatus
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                if let token = Messaging.messaging().fcmToken {
                    self.fcmToken = token
                    await self.uploadToken(token)
                }
            }
        }
    }

    func handleAPNsToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func clearRegistration(idToken: String?) async {
        guard let token = fcmToken, let idToken, idToken != "preview", idToken != "uitesting" else {
            fcmToken = nil
            return
        }
        try? await MekasaAPIClient.shared.deleteDeviceToken(token: token, idToken: idToken)
        fcmToken = nil
    }

    private func uploadToken(_ fcmToken: String) async {
        guard let idToken = pendingIDToken,
              idToken != "preview",
              idToken != "uitesting"
        else { return }
        do {
            _ = try await MekasaAPIClient.shared.registerDevice(
                fcmToken: fcmToken,
                platform: "ios",
                idToken: idToken
            )
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}

extension PushRegistrationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            self.fcmToken = fcmToken
            if let fcmToken {
                await self.uploadToken(fcmToken)
            }
        }
    }
}

extension PushRegistrationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let link = userInfo["deep_link"] as? String,
           let url = URL(string: link) {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .mekasaOpenDeepLink,
                    object: url
                )
            }
        }
    }
}

extension Notification.Name {
    static let mekasaOpenDeepLink = Notification.Name("mekasaOpenDeepLink")
}
