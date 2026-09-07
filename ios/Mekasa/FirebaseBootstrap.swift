import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif

/// Single place to initialize Firebase before Auth / Google Sign-In.
enum FirebaseBootstrap {
    static func configure() {
        #if canImport(FirebaseCore)
        if FirebaseApp.app() != nil { return }

        let plistInBundle = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        print("[Mekasa] GoogleService-Info.plist in bundle: \(plistInBundle)")

        guard plistInBundle else {
            fatalError(
                """
                GoogleService-Info.plist is NOT in the app bundle.
                In Xcode: select the plist → Target Membership → Mekasa,
                and Build Phases → Copy Bundle Resources → add the plist.
                Then Product → Clean Build Folder and Run.
                """
            )
        }

        FirebaseApp.configure()
        print("[Mekasa] Firebase configured: \(FirebaseApp.app()?.name ?? "nil")")
        #endif
    }
}
