import Foundation
import FirebaseCore

/// Single place to initialize Firebase before Auth / Google Sign-In.
enum FirebaseBootstrap {
    private(set) static var isConfigured = false
    private static var didRun = false

    /// Call as early as possible (AppDelegate + App.init). Safe if plist is absent
    /// so DEBUG "Browse UI offline" still launches.
    static func configure() {
        guard !didRun else { return }
        didRun = true

        let plistInBundle = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        print("[Mekasa] GoogleService-Info.plist in bundle: \(plistInBundle)")

        guard plistInBundle else {
            print(
                """
                [Mekasa] Firebase not configured — GoogleService-Info.plist is missing from the app bundle.
                Add it to the Mekasa target (Target Membership + Copy Bundle Resources), then:
                  cd ios && xcodegen generate
                  Product → Clean Build Folder → Run
                Offline UI preview still works without it.
                """
            )
            return
        }

        FirebaseApp.configure()
        isConfigured = true
        print("[Mekasa] Firebase configured OK")
    }
}
