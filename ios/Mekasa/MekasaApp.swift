import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct MekasaApp: App {
    // Satisfies: REQ-001 (Household Account Creation)
    // Spec version: 1.0

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Belt-and-suspenders: configure before any SwiftUI view can touch Auth.
        AppDelegate.configureFirebaseIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(AppSession())
        }
    }
}
