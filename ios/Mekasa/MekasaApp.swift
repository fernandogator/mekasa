import SwiftUI
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct MekasaApp: App {
    // Satisfies: REQ-001 (Household Account Creation), REQ-022 (Session expiry)
    // Spec version: 1.0

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var session: AppSession
    @Environment(\.scenePhase) private var scenePhase

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
        Self.installDiagnostics(uiTesting: uiTesting)
        let session = AppSession()
        if uiTesting {
            session.startUITesting(
                emptyInventory: args.contains("--uitesting-empty")
                    || env["MEKASA_UITESTING_EMPTY"] == "1"
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
                    #if canImport(GoogleSignIn)
                    if GIDSignIn.sharedInstance.handle(url) {
                        return
                    }
                    #endif
                    session.handleDeepLink(url)
                    Task { await session.acceptPendingInviteIfNeeded() }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            // NFR-007 AC2: queued error reports go out when the app returns to the foreground.
            if phase == .active { ErrorReporter.shared.flushSoon(after: 0) }
        }
    }

    /// NFR-007: on-device log, error reports and Crashlytics. Reports and crash
    /// collection stay off in UI tests, unit tests and Xcode previews.
    private static func installDiagnostics(uiTesting: Bool) {
        let env = ProcessInfo.processInfo.environment
        let unitTesting = env["XCTestConfigurationFilePath"] != nil
        let xcodePreview = env["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let offline = uiTesting || unitTesting || xcodePreview
        AppLog.shared.install(fileURL: offline ? nil : AppLog.defaultFileURL)
        let info = Bundle.main.infoDictionary ?? [:]
        ErrorReporter.shared.install(
            fileURL: offline ? nil : ErrorReporter.defaultFileURL,
            app: ClientApp(
                appVersion: info["CFBundleShortVersionString"] as? String ?? "",
                build: info["CFBundleVersion"] as? String ?? "",
                osVersion: UIDevice.current.systemVersion,
                deviceModel: deviceModel()
            )
        )
        ErrorReporter.shared.isEnabled = !offline
        #if DEBUG
        let crashCollection = false
        #else
        let crashCollection = !offline && FirebaseBootstrap.isConfigured
        #endif
        CrashReporting.start(enabled: crashCollection)
        AppLog.shared.info(
            "app",
            "App started",
            fields: [
                "version": info["CFBundleShortVersionString"] as? String,
                "build": info["CFBundleVersion"] as? String,
                "firebase": FirebaseBootstrap.isConfigured,
            ]
        )
    }

    /// Hardware identifier such as `iPhone16,1` (simulators report their host model).
    private static func deviceModel() -> String {
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: &system.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
