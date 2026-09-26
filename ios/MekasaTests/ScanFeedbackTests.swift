import XCTest
@testable import Mekasa

/// Scan beep + haptic helper stays quiet under UI testing and respects the toggle.
final class ScanFeedbackTests: XCTestCase {

    override func tearDown() {
        ScanFeedback.soundsEnabled = true
        super.tearDown()
    }

    func testPreferenceKeyIsStable() {
        XCTAssertEqual(ScanFeedback.preferenceKey, "mekasa.scanSoundsEnabled")
    }

    func testSoundsEnabledDefaultsOn() {
        UserDefaults.standard.removeObject(forKey: ScanFeedback.preferenceKey)
        XCTAssertTrue(ScanFeedback.soundsEnabled)
    }

    func testSoundsEnabledTogglePersists() {
        ScanFeedback.soundsEnabled = false
        XCTAssertFalse(ScanFeedback.soundsEnabled)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: ScanFeedback.preferenceKey))
        ScanFeedback.soundsEnabled = true
        XCTAssertTrue(ScanFeedback.soundsEnabled)
    }

    func testDisabledWhenSoundsOff() {
        ScanFeedback.soundsEnabled = false
        let args = ProcessInfo.processInfo.arguments
        if !args.contains("--uitesting") {
            XCTAssertFalse(ScanFeedback.isEnabled)
        }
    }

    func testDisabledUnderUITestingLaunchArgument() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--uitesting") {
            XCTAssertFalse(ScanFeedback.isEnabled)
        } else {
            ScanFeedback.soundsEnabled = true
            XCTAssertTrue(ScanFeedback.isEnabled)
        }
    }

    func testAcceptedAndUnknownAreSafeToCall() {
        ScanFeedback.soundsEnabled = true
        ScanFeedback.prepare()
        ScanFeedback.accepted()
        ScanFeedback.unknown()
        ScanFeedback.soundsEnabled = false
        ScanFeedback.accepted()
        ScanFeedback.unknown()
    }
}
