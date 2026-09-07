import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct MekasaApp: App {
    // Satisfies: REQ-001 (Household Account Creation)
    // Spec version: 1.0

    init() {
        #if canImport(FirebaseCore)
        // Always configure when Firebase SPM is linked. Requires
        // GoogleService-Info.plist in the Mekasa target (Copy Bundle Resources).
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(AppSession())
        }
    }
}
