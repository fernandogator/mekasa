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
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
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
