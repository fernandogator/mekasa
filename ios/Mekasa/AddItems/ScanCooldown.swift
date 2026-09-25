import Foundation

/// Minimum spacing between accepted trash-station scans (REQ-008).
/// A scan that lands inside the window is rejected so one item tossed in front of the
/// camera cannot be decremented twice by the same beep.
struct ScanCooldown: Equatable {
    static let defaultWindow: TimeInterval = 5

    let window: TimeInterval
    private(set) var lastAcceptedAt: Date?

    init(window: TimeInterval = ScanCooldown.defaultWindow) {
        self.window = window
    }

    /// Seconds until the next scan is allowed; 0 when ready.
    func remaining(at now: Date = Date()) -> TimeInterval {
        guard let lastAcceptedAt else { return 0 }
        return max(0, window - now.timeIntervalSince(lastAcceptedAt))
    }

    func isReady(at now: Date = Date()) -> Bool {
        remaining(at: now) <= 0
    }

    /// Accepts the scan and starts the window, or returns false if still cooling down.
    @discardableResult
    mutating func tryAccept(at now: Date = Date()) -> Bool {
        guard isReady(at: now) else { return false }
        lastAcceptedAt = now
        return true
    }

    mutating func reset() {
        lastAcceptedAt = nil
    }
}
