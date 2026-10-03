import XCTest
@testable import Mekasa

/// Trash-station scan spacing (REQ-008): one accepted scan per 5 s window.
final class ScanCooldownTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testDefaultWindowIsFiveSeconds() {
        XCTAssertEqual(ScanCooldown().window, 5)
        XCTAssertEqual(ScanCooldown.defaultWindow, 5)
    }

    func testFirstScanIsAcceptedImmediately() {
        var cooldown = ScanCooldown()
        XCTAssertTrue(cooldown.isReady(at: t0))
        XCTAssertEqual(cooldown.remaining(at: t0), 0)
        XCTAssertTrue(cooldown.tryAccept(at: t0))
        XCTAssertEqual(cooldown.lastAcceptedAt, t0)
    }

    func testScansInsideWindowAreRejected() {
        var cooldown = ScanCooldown()
        XCTAssertTrue(cooldown.tryAccept(at: t0))

        for offset in [0.1, 1.0, 2.5, 4.99] {
            let now = t0.addingTimeInterval(offset)
            XCTAssertFalse(cooldown.tryAccept(at: now), "scan at +\(offset)s must be rejected")
            XCTAssertEqual(cooldown.remaining(at: now), 5 - offset, accuracy: 0.001)
        }
        // A rejected scan must not extend the window.
        XCTAssertEqual(cooldown.lastAcceptedAt, t0)
    }

    func testScanAtWindowEdgeIsAcceptedAndRestartsWindow() {
        var cooldown = ScanCooldown()
        XCTAssertTrue(cooldown.tryAccept(at: t0))

        let t5 = t0.addingTimeInterval(5)
        XCTAssertTrue(cooldown.isReady(at: t5))
        XCTAssertTrue(cooldown.tryAccept(at: t5))
        XCTAssertEqual(cooldown.lastAcceptedAt, t5)
        XCTAssertFalse(cooldown.tryAccept(at: t5.addingTimeInterval(3)))
        XCTAssertTrue(cooldown.tryAccept(at: t5.addingTimeInterval(5.5)))
    }

    func testResetAllowsImmediateScan() {
        var cooldown = ScanCooldown()
        XCTAssertTrue(cooldown.tryAccept(at: t0))
        cooldown.reset()
        XCTAssertTrue(cooldown.tryAccept(at: t0.addingTimeInterval(0.5)))
    }

    func testCustomWindow() {
        var cooldown = ScanCooldown(window: 1)
        XCTAssertTrue(cooldown.tryAccept(at: t0))
        XCTAssertFalse(cooldown.tryAccept(at: t0.addingTimeInterval(0.9)))
        XCTAssertTrue(cooldown.tryAccept(at: t0.addingTimeInterval(1.0)))
    }
}
