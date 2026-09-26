import AudioToolbox
import UIKit

/// Audible + haptic confirmation for barcode scans (add path + trash station).
/// Plays the bundled `scanner-beep.mp3` (from `design/scanner-beep.mp3`) plus a
/// notification haptic. Honours the Family → Scan sounds toggle and stays quiet
/// under `--uitesting`.
enum ScanFeedback {
    static let preferenceKey = "mekasa.scanSoundsEnabled"

    /// Lower double-tone fallback / unknown lookup.
    private static let unknownSystemSound: SystemSoundID = 1053 // SIMToolkitNegativeACK

    private static let successHaptic = UINotificationFeedbackGenerator()
    private static let warningHaptic = UINotificationFeedbackGenerator()

    private static var customSoundID: SystemSoundID = {
        guard let url = Bundle.main.url(forResource: "scanner-beep", withExtension: "mp3", subdirectory: "Sounds")
            ?? Bundle.main.url(forResource: "scanner-beep", withExtension: "mp3")
        else { return 0 }
        var soundID: SystemSoundID = 0
        let status = AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        return status == kAudioServicesNoError ? soundID : 0
    }()

    /// User preference (default on). Persisted in `UserDefaults`.
    static var soundsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: preferenceKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: preferenceKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: preferenceKey) }
    }

    static var isEnabled: Bool {
        soundsEnabled
            && !ProcessInfo.processInfo.arguments.contains("--uitesting")
            && ProcessInfo.processInfo.environment["MEKASA_UITESTING"] == nil
    }

    /// Warm the haptic engines so the first scan feels instant.
    static func prepare() {
        guard isEnabled else { return }
        successHaptic.prepare()
        warningHaptic.prepare()
        _ = customSoundID
    }

    static func accepted() {
        guard isEnabled else { return }
        if customSoundID != 0 {
            AudioServicesPlaySystemSound(customSoundID)
        } else {
            // Fallback if the mp3 was left out of the bundle.
            AudioServicesPlaySystemSound(1052)
        }
        successHaptic.notificationOccurred(.success)
    }

    static func unknown() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(unknownSystemSound)
        warningHaptic.notificationOccurred(.warning)
    }
}
