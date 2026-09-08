import XCTest

/// Shared XCUITest bootstrap for Layer 1 structural tests.
enum UITestLaunch {
    static func app(empty: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["--uitesting"]
        if empty { args.append("--uitesting-empty") }
        app.launchArguments = args
        return app
    }
}
