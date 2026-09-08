import SwiftUI

@main
struct MekasaApp: App {
    // Satisfies: REQ-001 (Household Account Creation)
    // Spec version: 1.0

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var session: AppSession

    init() {
        FirebaseBootstrap.configure()
        if CommandLine.arguments.contains("--uitesting") {
            UIView.setAnimationsEnabled(false)
        }
        let session = AppSession()
        if CommandLine.arguments.contains("--uitesting") {
            session.startUITesting(
                emptyInventory: CommandLine.arguments.contains("--uitesting-empty")
            )
        }
        _session = StateObject(wrappedValue: session)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .onAppear { FirebaseBootstrap.configure() }
        }
    }
}
