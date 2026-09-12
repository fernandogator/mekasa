import XCTest

/// Shared XCUITest bootstrap for Layer 1 structural tests.
enum UITestLaunch {
    /// Cold CI simulators need more than a few seconds to present the first frame.
    static let elementTimeout: TimeInterval = 15

    static func app(empty: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["--uitesting"]
        if empty { args.append("--uitesting-empty") }
        app.launchArguments = args
        app.launchEnvironment["MEKASA_UITESTING"] = "1"
        return app
    }

    /// Prefer descendants — SwiftUI accessibility IDs often are not `otherElements`.
    static func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    @discardableResult
    static func waitForShell(_ app: XCUIApplication) -> Bool {
        element(app, TestIdentifiers.mainShellView).waitForExistence(timeout: elementTimeout)
            || element(app, TestIdentifiers.dashboardView).waitForExistence(timeout: elementTimeout)
            || element(app, TestIdentifiers.rootView).waitForExistence(timeout: elementTimeout)
    }
}
