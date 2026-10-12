import LocalAuthentication
import SwiftUI

/// Optional Face ID / Touch ID gate for a signed-in session.
/// Sign-in stays on Firebase email/Google; this only unlocks the already-open house.
/// Spec version: 1.1
@MainActor
final class FaceIDLock: ObservableObject {
    static let shared = FaceIDLock()
    static let preferenceKey = "mekasa.faceIDLockEnabled"
    /// Brief app switches (Control Center, replies) do not re-lock.
    static let backgroundGraceSeconds: TimeInterval = 10

    @Published private(set) var isUnlocked = true
    @Published var statusMessage: String?

    private var backgroundedAt: Date?
    private var isAuthenticating = false
    /// Ensures cold-start lock runs once; later SwiftUI `onAppear` must not re-lock.
    private var hasPreparedHomeThisLaunch = false
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

    /// True when Face ID / Touch ID can run (not passcode-only).
    var biometryAvailable: Bool {
        if let biometryAvailableOverride { return biometryAvailableOverride }
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// "Face ID", "Touch ID", or "Passcode" for the Family toggle label.
    var biometryLabel: String {
        if let biometryLabelOverride { return biometryLabelOverride }
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
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

    /// Arm a future re-lock. Pass `arm: false` while Google Sign-In (or other auth UI)
    /// is presenting — that background is not "left the house".
    func sceneDidEnterBackground(arm: Bool = true) {
        guard isEnabled, arm else { return }
        backgroundedAt = Date()
    }

    /// Re-lock only after a real background past the grace window.
    /// LocalAuthentication sheets use `.inactive`, not `.background` — those must not re-lock
    /// or the passcode/Face ID prompt loops forever after enabling.
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
        // No background since last unlock / enable → stay as-is (covers LA + Control Center).
        guard let backgroundedAt else { return }

        if Date().timeIntervalSince(backgroundedAt) < Self.backgroundGraceSeconds {
            self.backgroundedAt = nil
            return
        }
        self.backgroundedAt = nil
        isUnlocked = false
        // FaceIDLockScreen auto-prompts via `.task` when the overlay appears.
    }

    /// Cold start into the house with the preference on starts locked (once per launch).
    func prepareForHome(isUITesting: Bool) {
        guard !isUITesting else {
            isUnlocked = true
            return
        }
        guard isEnabled else {
            isUnlocked = true
            return
        }
        guard !hasPreparedHomeThisLaunch else { return }
        hasPreparedHomeThisLaunch = true
        isUnlocked = false
    }

    func unlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        statusMessage = nil
        guard biometryAvailable else {
            statusMessage = "\(biometryLabel) isn’t available. Check Settings → Face ID & Passcode."
            return
        }
        let result = await authenticate("Unlock Mekasa")
        switch result {
        case .success:
            isUnlocked = true
            backgroundedAt = nil
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
        guard !isAuthenticating else { return false }
        isAuthenticating = true
        defer { isAuthenticating = false }

        statusMessage = nil
        guard biometryAvailable else {
            statusMessage = "\(biometryLabel) isn’t available. Check Settings → Face ID & Passcode."
            return false
        }
        let result = await authenticate("Turn on \(biometryLabel) for Mekasa")
        switch result {
        case .success:
            isEnabled = true
            isUnlocked = true
            backgroundedAt = nil
            hasPreparedHomeThisLaunch = true
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

    /// After email/Google sign-in succeeds, stay unlocked for this launch.
    /// Presenting Face ID while Google Sign-In is still dismissing crashes / loops.
    func allowThroughAfterSignIn() {
        isUnlocked = true
        backgroundedAt = nil
        hasPreparedHomeThisLaunch = true
        statusMessage = nil
    }

    /// Sign-out clears the one-shot home prepare so a later sign-in can lock on cold paths.
    func resetAfterSignOut() {
        isUnlocked = true
        backgroundedAt = nil
        hasPreparedHomeThisLaunch = false
        statusMessage = nil
    }

    func markUnlockedForTesting() {
        isUnlocked = true
    }

    func markLockedForTesting() {
        isUnlocked = false
    }

    /// Test helper: pretend the app backgrounded `secondsAgo` seconds ago.
    func markBackgroundedForTesting(secondsAgo: TimeInterval) {
        backgroundedAt = Date().addingTimeInterval(-secondsAgo)
    }

    private static func systemAuthenticate(reason: String) async -> Result<Void, Error> {
        // Avoid evaluating over another modal (Google Sign-In teardown).
        if hasPresentedViewController {
            return .failure(LAError(.systemCancel))
        }
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        // Prefer Face ID / Touch ID. Passcode remains available as the system fallback
        // after biometric failure — not as the first prompt.
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return ok ? .success(()) : .failure(LAError(.authenticationFailed))
        } catch {
            return .failure(error)
        }
    }

    /// True when a UIKit modal is still up (Google Sign-In, system sheets, …).
    static var hasPresentedViewController: Bool {
        let roots = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .compactMap(\.rootViewController)
        return roots.contains { $0.presentedViewController != nil }
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

/// Full-screen gate shown until Face ID (or Touch ID) succeeds.
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
            // Wait for Google Sign-In (or any modal) to finish dismissing before LA.
            for _ in 0..<25 {
                if Task.isCancelled { return }
                if !FaceIDLock.hasPresentedViewController { break }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled { return }
            await lock.unlock()
        }
    }
}
