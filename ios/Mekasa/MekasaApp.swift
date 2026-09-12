import SwiftUI

@main
struct MekasaApp: App {
    // Satisfies: REQ-001 (Household Account Creation), REQ-022 (Session expiry)
    // Spec version: 1.0

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var session: AppSession

    init() {
        FirebaseBootstrap.configure()
        // Prefer ProcessInfo — CommandLine.arguments can miss XCUITest launch args
        // depending on how the runner injects them. Also honor MEKASA_UITESTING env.
        let args = ProcessInfo.processInfo.arguments
        let env = ProcessInfo.processInfo.environment
        let uiTesting = args.contains("--uitesting")
            || env["MEKASA_UITESTING"] == "1"
            || env["MEKASA_UITESTING"] == "true"
        if uiTesting {
            UIView.setAnimationsEnabled(false)
        }
        let session = AppSession()
        if uiTesting {
            session.startUITesting(
                emptyInventory: args.contains("--uitesting-empty")
                    || env["MEKASA_UITESTING_EMPTY"] == "1"
            )
        }
        _session = StateObject(wrappedValue: session)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .onAppear {
                    FirebaseBootstrap.configure()
                    session.startSessionMonitoring()
                }
        }
    }
}
