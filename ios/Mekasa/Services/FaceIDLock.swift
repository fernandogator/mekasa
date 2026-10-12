import LocalAuthentication
import SwiftUI

/// Optional Face ID / Touch ID gate for a signed-in session.
/// Sign-in stays on Firebase email/Google; this only unlocks the already-open house.
/// Spec version: 1.0
@MainActor
final class FaceIDLock: ObservableObject {
    static let shared = FaceIDLock()
    static let preferenceKey = "mekasa.faceIDLockEnabled"
    /// Brief app switches (Control Center, replies) do not re-lock.
    static let backgroundGraceSeconds: TimeInterval = 10

    @Published private(set) var isUnlocked = true
    @Published var statusMessage: String?

    private var backgroundedAt: Date?
    private let defaults: UserDefaults
    private let authenticate: (String) async -> Result<Void, Error>
    private let biometryAvailableOverride: Bool?
    private let biometryLabelOverride: String?

    /// User preference (default off). Persisted in `UserDefaults`.
    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.preferenceKey) }
        set { defaults.set(newValue, forKey: Self.preferenceKey) }
    }

    init(
        defaults: UserDefaults = .standard,
        authenticate: ((String) async -> Result<Void, Error>)? = nil,
        biometryAvailable: Bool? = nil,
        biometryLabel: String? = nil
    ) {
        self.defaults = defaults
        self.authenticate = authenticate ?? Self.systemAuthenticate
        self.biometryAvailableOverride = biometryAvailable
        self.biometryLabelOverride = biometryLabel
    }

    /// True when the device can run Face ID, Touch ID, or the passcode fallback.
    var biometryAvailable: Bool {
        if let biometryAvailableOverride { return biometryAvailableOverride }
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// "Face ID", "Touch ID", or "Passcode" for the Family toggle label.
    var biometryLabel: String {
        if let biometryLabelOverride { return biometryLabelOverride }
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none: return "Passcode"
        @unknown default: return "Passcode"
        }
    }

    /// Lock when the house is open, the preference is on, and this is not a UI test.
    func shouldPresentLock(onboardingDone: Bool, isUITesting: Bool) -> Bool {
        FaceIDLockPolicy.shouldPresentLock(
            enabled: isEnabled,
            unlocked: isUnlocked,
            onboardingDone: onboardingDone,
            isUITesting: isUITesting
        )
    }

    func sceneDidEnterBackground() {
        guard isEnabled else { return }
        backgroundedAt = Date()
    }

    /// Re-lock after the grace window, then prompt Face ID.
    func sceneDidBecomeActive(onboardingDone: Bool, isUITesting: Bool) {
        guard !isUITesting else {
            isUnlocked = true
            return
        }
        guard isEnabled, onboardingDone else {
            isUnlocked = true
            backgroundedAt = nil
            return
        }
        if let backgroundedAt,
           Date().timeIntervalSince(backgroundedAt) < Self.backgroundGraceSeconds {
            self.backgroundedAt = nil
            return
        }
        backgroundedAt = nil
        isUnlocked = false
        // FaceIDLockScreen auto-prompts via `.task` when the overlay appears.
    }

    /// First launch into the house with the preference on starts locked.
    func prepareForHome(isUITesting: Bool) {
        guard !isUITesting, isEnabled else {
            isUnlocked = true
            return
        }
        isUnlocked = false
    }

    func unlock() async {
        statusMessage = nil
        guard biometryAvailable else {
            statusMessage = "Biometrics aren’t available on this device."
            return
        }
        let result = await authenticate("Unlock Mekasa")
        switch result {
        case .success:
            isUnlocked = true
            statusMessage = nil
        case let .failure(error):
            if Self.isCancel(error) {
                statusMessage = nil
            } else {
                statusMessage = error.localizedDescription
            }
        }
    }

    /// Run one Face ID prompt before turning the preference on.
    @discardableResult
    func enableWithPrompt() async -> Bool {
        statusMessage = nil
        guard biometryAvailable else {
            statusMessage = "Biometrics aren’t available on this device."
            return false
        }
        let result = await authenticate("Turn on \(biometryLabel) for Mekasa")
        switch result {
        case .success:
            isEnabled = true
            isUnlocked = true
            return true
        case let .failure(error):
            if !Self.isCancel(error) {
                statusMessage = error.localizedDescription
            }
            return false
        }
    }

    func disable() {
        isEnabled = false
        isUnlocked = true
        statusMessage = nil
        backgroundedAt = nil
    }

    func markUnlockedForTesting() {
        isUnlocked = true
    }

    func markLockedForTesting() {
        isUnlocked = false
    }

    private static func systemAuthenticate(reason: String) async -> Result<Void, Error> {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return ok ? .success(()) : .failure(LAError(.authenticationFailed))
        } catch {
            return .failure(error)
        }
    }

    private static func isCancel(_ error: Error) -> Bool {
        let code = (error as? LAError)?.code
        return code == .userCancel || code == .appCancel || code == .systemCancel
    }
}

/// Pure rules for when the lock screen covers the house.
enum FaceIDLockPolicy {
    static func shouldPresentLock(
        enabled: Bool,
        unlocked: Bool,
        onboardingDone: Bool,
        isUITesting: Bool
    ) -> Bool {
        guard !isUITesting, enabled, onboardingDone else { return false }
        return !unlocked
    }
}

/// Full-screen gate shown until Face ID (or passcode) succeeds.
struct FaceIDLockScreen: View {
    @ObservedObject var lock: FaceIDLock
    @State private var isUnlocking = false

    var body: some View {
        ZStack {
            MekasaTheme.brand.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Image(systemName: lock.biometryLabel == "Touch ID" ? "touchid" : "faceid")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(MekasaTheme.onBrand)
                    .accessibilityHidden(true)
                Text("Mekasa")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(MekasaTheme.onBrand)
                Text("Unlock with \(lock.biometryLabel) to open your house.")
                    .font(MekasaTheme.bodyFont)
                    .foregroundStyle(MekasaTheme.onBrand.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                if let statusMessage = lock.statusMessage, !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(MekasaTheme.onBrand.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .accessibilityIdentifier(TestIdentifiers.faceIDLockStatus)
                }
                Spacer()
                Button {
                    Task {
                        isUnlocking = true
                        await lock.unlock()
                        isUnlocking = false
                    }
                } label: {
                    HStack {
                        if isUnlocking { ProgressView().tint(MekasaTheme.brand) }
                        Text("Unlock with \(lock.biometryLabel)")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(MekasaTheme.brand)
                    .background(MekasaTheme.onBrand)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .disabled(isUnlocking)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
                .accessibilityIdentifier(TestIdentifiers.faceIDUnlockButton)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TestIdentifiers.faceIDLockScreen)
        .task {
            await lock.unlock()
        }
    }
}
