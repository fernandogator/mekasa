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
        if empty { app.launchEnvironment["MEKASA_UITESTING_EMPTY"] = "1" }
        return app
    }

    /// Prefer descendants — SwiftUI accessibility IDs often are not `otherElements`.
    static func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    /// Do **not** treat `RootView` alone as shell — it is always present, including
    /// on Welcome, and previously masked missing MainShell identifiers.
    @discardableResult
    static func waitForShell(_ app: XCUIApplication) -> Bool {
        if element(app, TestIdentifiers.mainShellView).waitForExistence(timeout: elementTimeout) {
            return true
        }
        if element(app, TestIdentifiers.dashboardView).waitForExistence(timeout: elementTimeout) {
            return true
        }
        // Fallback: FAB label survives even if an ancestor stole accessibility ids.
        if app.buttons["Add items"].waitForExistence(timeout: elementTimeout) {
            return true
        }
        return element(app, TestIdentifiers.addItemButton).waitForExistence(timeout: 5)
    }

    static func addItemButton(_ app: XCUIApplication) -> XCUIElement {
        let byId = element(app, TestIdentifiers.addItemButton)
        if byId.exists { return byId }
        return app.buttons["Add items"]
    }
}
