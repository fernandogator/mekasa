import SwiftUI

@main
struct MekasaApp: App {
    // Satisfies: REQ-001 (Household Account Creation)
    // Spec version: 1.0

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        FirebaseBootstrap.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(AppSession())
                .onAppear { FirebaseBootstrap.configure() }
        }
    }
}
