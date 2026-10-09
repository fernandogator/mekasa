import SwiftUI
import UIKit

/// Signup / sign-in (Google + email). Sign in with Apple is deferred (REQ-001 AC1).
/// Satisfies: REQ-001 AC2–AC3, REQ-022 AC5, UI-003 AC1
/// Spec version: 1.0
struct WelcomeView: View {
    @EnvironmentObject private var session: AppSession
    @State private var email = ""
    @State private var password = ""
    /// Default to sign-in; users opt in to create an account.
    @State private var isSignUp = false
    @State private var showEmailForm = false
    @State private var resetNotice: String?
    @FocusState private var focusedField: EmailAuthField?

    private enum EmailAuthField: Hashable {
        case email
        case password
    }

    private var canSubmitEmail: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && password.count >= 6 && !session.isBusy
    }

    private var canRequestPasswordReset: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !session.isBusy
    }

    var body: some View {
        MekasaScreen {

            VStack(spacing: 0) {
                OnboardingHeader(step: .welcome)
                    .padding(.horizontal, 24)
                    .padding(.top, 48)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Your house,\norganized.")
                            .font(MekasaTheme.displayFont)
                            .foregroundStyle(MekasaTheme.text)
                            .padding(.top, 40)

                        Text("Sign in to create a household, pick your stores, and start scanning inventory.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)

                        if let message = session.lastError,
                           message.localizedCaseInsensitiveContains("session expired") {
                            Text(message)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.danger)
                                .accessibilityIdentifier("SessionExpiredBanner")
                        }

                        if showEmailForm {
                            MekasaTextField(
                                label: "Email",
                                placeholder: "you@example.com",
                                text: $email,
                                keyboard: .emailAddress,
                                autocapitalization: .never,
                                submitLabel: .next,
                                onSubmit: { focusedField = .password }
                            )
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .accessibilityIdentifier("WelcomeEmailField")

                            MekasaTextField(
                                label: "Password",
                                placeholder: "At least 6 characters",
                                text: $password,
                                isSecure: true,
                                submitLabel: .go,
                                onSubmit: { submitEmailFromKeyboard() }
                            )
                            .textContentType(isSignUp ? .newPassword : .password)
                            .focused($focusedField, equals: .password)
                            .accessibilityIdentifier("WelcomePasswordField")

                            Toggle("Create a new account", isOn: $isSignUp)
                                .font(MekasaTheme.bodyFont)
                                .tint(MekasaTheme.accent)
                                .accessibilityIdentifier("WelcomeCreateAccountToggle")

                            if !isSignUp {
                                Button("Forgot password?") {
                                    Task { await submitPasswordReset() }
                                }
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.accent)
                                .disabled(!canRequestPasswordReset)
                                .accessibilityIdentifier("WelcomeForgotPasswordButton")
                            }

                            if let resetNotice {
                                Text(resetNotice)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(MekasaTheme.textMuted)
                                    .accessibilityIdentifier("WelcomePasswordResetNotice")
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 140)
                }

                StickyBottomBar(progress: 1.0 / 6.0) {
                    VStack(spacing: 12) {
                        if showEmailForm {
                            PrimaryButton(
                                title: isSignUp ? "Create account" : "Sign in",
                                disabled: !canSubmitEmail,
                                isLoading: session.isBusy
                            ) {
                                Task { await submitEmail() }
                            }
                            .accessibilityIdentifier("WelcomeSignInButton")
                            SecondaryButton(title: "Back") {
                                withAnimation {
                                    showEmailForm = false
                                    resetNotice = nil
                                }
                            }
                        } else {
                            PrimaryButton(title: "Continue with Google", isLoading: session.isBusy) {
                                Task { await submitGoogle() }
                            }
                            SecondaryButton(title: "Continue with email") {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showEmailForm = true
                                    focusedField = session.lastSignedInEmail == nil ? .email : .password
                                }
                            }
                            #if DEBUG
                            Button("Browse UI offline") {
                                withAnimation { session.startUIPreview() }
                            }
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(MekasaTheme.textMuted)
                            .padding(.top, 4)
                            #endif
                        }

                        if !AuthService.shared.isFirebaseConfigured {
                            Text("Firebase plist not in the app bundle yet. Use Browse UI offline, or add GoogleService-Info.plist → Copy Bundle Resources → xcodegen generate → Clean + Run.")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.textMuted)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier(TestIdentifiers.welcomeView)
        .onAppear { prefillLastSignedInEmail() }
        .onChange(of: session.lastSignedInEmail) {
            prefillLastSignedInEmail()
        }
        .onChange(of: session.onboardingStep) { _, step in
            if step == .welcome {
                prefillLastSignedInEmail()
            }
        }
    }

    /// Prefill email and open the sign-in form when we know the last username.
    private func prefillLastSignedInEmail() {
        guard let remembered = session.lastSignedInEmail, !remembered.isEmpty else { return }
        email = remembered
        isSignUp = false
        showEmailForm = true
        password = ""
        focusedField = .password
    }

    private func submitEmailFromKeyboard() {
        guard canSubmitEmail else {
            if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                focusedField = .email
            }
            return
        }
        focusedField = nil
        Task { await submitEmail() }
    }

    private func applyAuth(token: String, email: String?, name: String?) async {
        session.idToken = token
        session.email = email
        session.displayName = name
        session.userUID = AuthService.shared.currentUserUID
        AppLog.shared.info("auth", "Signed in", fields: ["user_ref": session.userUID.map(CrashReporting.userRef)])
        session.rememberSignedInEmail(email ?? self.email)
        await session.acceptPendingInviteIfNeeded()
        if session.onboardingStep == .done, session.household != nil {
            return
        }
        do {
            let existing = try await MekasaAPIClient.shared.currentHousehold(token: token)
            session.household = existing
            // Invited teens and members land on the family's inventory, not a new empty house.
            let step: OnboardingStep = existing.ownerUID == session.userUID
                ? resumeStep(for: existing)
                : .done
            withAnimation { session.onboardingStep = step }
            session.updateRealtimeSync()
            await session.refreshInventory()
            PushRegistrationService.shared.requestPermissionAndRegister(idToken: token)
        } catch let error as APIError where error.isMissingHousehold {
            withAnimation { session.onboardingStep = .household }
        } catch {
            // A 500 used to look like "no household" and start "Name this house"
            // for an admin who already has one.
            session.showError(
                "Couldn't open your household. It is still saved. Sign in again in a moment.",
                error: error
            )
        }
    }

    private func resumeStep(for household: Household) -> OnboardingStep {
        if household.address == nil { return .address }
        if household.storeIDs.isEmpty { return .stores }
        return .done
    }

    private func submitEmail() async {
        session.isBusy = true
        defer { session.isBusy = false }
        print("[Mekasa] submitEmail start signUp=\(isSignUp) firebase=\(AuthService.shared.isFirebaseConfigured)")
        do {
            let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let result: (token: String, email: String?, name: String?)
            if isSignUp {
                print("[Mekasa] calling Firebase createUser…")
                result = try await AuthService.shared.signUp(email: trimmed, password: password)
            } else {
                print("[Mekasa] calling Firebase signIn…")
                result = try await AuthService.shared.signIn(email: trimmed, password: password)
            }
            print("[Mekasa] auth OK, applying session…")
            await applyAuth(token: result.token, email: result.email, name: result.name)
            print("[Mekasa] submitEmail done step=\(session.onboardingStep)")
        } catch {
            print("[Mekasa] submitEmail ERROR: \(error)")
            session.showError(error.localizedDescription, error: error)
        }
    }

    /// Firebase answers success even for unknown emails (enumeration protection), so the
    /// notice is deliberately neutral.
    private func submitPasswordReset() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        session.isBusy = true
        defer { session.isBusy = false }
        focusedField = nil
        resetNotice = nil
        do {
            try await AuthService.shared.sendPasswordReset(email: trimmed)
            resetNotice = "If an account exists for \(trimmed), a password reset email is on its way. "
                + "Setting a password there also works for accounts that signed up with Google."
        } catch {
            print("[Mekasa] submitPasswordReset ERROR: \(error)")
            session.showError(error.localizedDescription, error: error)
        }
    }

    private func submitGoogle() async {
        session.isBusy = true
        defer { session.isBusy = false }
        print("[Mekasa] submitGoogle start")
        do {
            guard FirebaseAppHelper.googleClientID != nil else {
                session.showError(AuthServiceError.missingGoogleClientID.localizedDescription)
                return
            }
            guard let presenter = TopViewController.shared else {
                session.showError("Could not find a window to present Google Sign-In.")
                return
            }
            let result = try await AuthService.shared.signInWithGoogle(presenting: presenter)
            await applyAuth(token: result.token, email: result.email, name: result.name)
        } catch {
            print("[Mekasa] submitGoogle ERROR: \(error)")
            session.showError(error.localizedDescription, error: error)
        }
    }
}

enum TopViewController {
    static var shared: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
            .flatMap(topMost)
    }

    private static func topMost(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController {
            return topMost(from: presented)
        }
        if let nav = root as? UINavigationController, let visible = nav.visibleViewController {
            return topMost(from: visible)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topMost(from: selected)
        }
        return root
    }
}

#Preview {
    WelcomeView().environmentObject(AppSession())
}
