import AudioToolbox
import UIKit

/// Audible + haptic confirmation for barcode scans (REQ-008 trash station).
/// Uses built-in system sounds so no audio asset ships with the app; they follow the
/// ring/silent switch like every other UI sound.
enum ScanFeedback {
    /// Classic short scanner beep — a barcode was read and matched.
    private static let acceptedSound: SystemSoundID = 1052 // SIMToolkitGeneralBeep
    /// Lower double-tone — barcode read but not in inventory.
    private static let unknownSound: SystemSoundID = 1053 // SIMToolkitNegativeACK

    static var isEnabled: Bool {
        !ProcessInfo.processInfo.arguments.contains("--uitesting")
            && ProcessInfo.processInfo.environment["MEKASA_UITESTING"] == nil
    }

    static func accepted() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(acceptedSound)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func unknown() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(unknownSound)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
