import SwiftUI

@main
struct MekasaApp: App {
    // Satisfies: REQ-001 (Household Account Creation), REQ-022 (Session expiry)
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
        if CommandLine.arguments.contains("--trash-station") {
            session.isTrashKioskMode = true
            if session.onboardingStep != .welcome || session.isUITesting {
                session.onboardingStep = .done
            }
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
                    Task { await session.acceptPendingInviteIfNeeded() }
                }
                .onOpenURL { url in
                    session.handleDeepLink(url)
                    Task { await session.acceptPendingInviteIfNeeded() }
                }
        }
    }
}
