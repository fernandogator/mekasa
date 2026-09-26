import XCTest
@testable import Mekasa

/// Scan beep + haptic helper stays quiet under UI testing.
final class ScanFeedbackTests: XCTestCase {

    func testDisabledUnderUITestingLaunchArgument() {
        // Structural UI tests launch with `--uitesting`; feedback must not fire there.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--uitesting") {
            XCTAssertFalse(ScanFeedback.isEnabled)
        } else {
            // Unit-test host has no `--uitesting` unless injected.
            XCTAssertTrue(ScanFeedback.isEnabled)
        }
    }

    func testAcceptedAndUnknownAreSafeToCall() {
        // Smoke: no crash when engines are cold (haptics/audio are best-effort).
        ScanFeedback.prepare()
        ScanFeedback.accepted()
        ScanFeedback.unknown()
    }
}
