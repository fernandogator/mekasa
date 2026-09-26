import AudioToolbox
import UIKit

/// Audible + haptic confirmation for barcode scans (add path + trash station).
/// System sounds (no audio asset) follow the ring/silent switch; haptics fire alongside.
enum ScanFeedback {
    /// Classic short scanner beep — a barcode was read and matched.
    private static let acceptedSound: SystemSoundID = 1052 // SIMToolkitGeneralBeep
    /// Lower double-tone — barcode read but not in inventory / lookup failed.
    private static let unknownSound: SystemSoundID = 1053 // SIMToolkitNegativeACK

    private static let successHaptic = UINotificationFeedbackGenerator()
    private static let warningHaptic = UINotificationFeedbackGenerator()

    static var isEnabled: Bool {
        !ProcessInfo.processInfo.arguments.contains("--uitesting")
            && ProcessInfo.processInfo.environment["MEKASA_UITESTING"] == nil
    }

    /// Warm the haptic engines so the first scan feels instant.
    static func prepare() {
        guard isEnabled else { return }
        successHaptic.prepare()
        warningHaptic.prepare()
    }

    static func accepted() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(acceptedSound)
        successHaptic.notificationOccurred(.success)
    }

    static func unknown() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(unknownSound)
        warningHaptic.notificationOccurred(.warning)
    }
}
