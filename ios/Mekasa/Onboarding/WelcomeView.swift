import SwiftUI
import UIKit

/// Signup / sign-in (Google + email). Apple deferred.
/// Satisfies: REQ-001 AC2–AC3, UI-003 AC1
/// Spec version: 1.0
struct WelcomeView: View {
    @EnvironmentObject private var session: AppSession
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = true
    @State private var showEmailForm = false

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
                            .foregroundStyle(MekasaTheme.brand)
                            .padding(.top, 40)

                        Text("Sign in to create a household, pick your stores, and start scanning inventory.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)

                        if let message = session.lastError,
                           message.localizedCaseInsensitiveContains("session expired") {
                            Text(message)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.accent)
                                .accessibilityIdentifier("SessionExpiredBanner")
                        }

                        if showEmailForm {
                            MekasaTextField(
                                label: "Email",
                                placeholder: "you@example.com",
                                text: $email,
                                keyboard: .emailAddress,
                                autocapitalization: .never
                            )
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()

                            MekasaTextField(
                                label: "Password",
                                placeholder: "At least 6 characters",
                                text: $password,
                                isSecure: true
                            )
                            .textContentType(isSignUp ? .newPassword : .password)

                            Toggle(isSignUp ? "Create a new account" : "I already have an account", isOn: $isSignUp)
                                .font(MekasaTheme.bodyFont)
                                .tint(MekasaTheme.accent)
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
                                disabled: email.isEmpty || password.count < 6,
                                isLoading: session.isBusy
                            ) {
                                Task { await submitEmail() }
                            }
                            SecondaryButton(title: "Back") {
                                withAnimation { showEmailForm = false }
                            }
                        } else {
                            PrimaryButton(title: "Continue with Google", isLoading: session.isBusy) {
                                Task { await submitGoogle() }
                            }
                            SecondaryButton(title: "Continue with email") {
                                withAnimation(.easeInOut(duration: 0.25)) { showEmailForm = true }
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
    }

    private func applyAuth(token: String, email: String?, name: String?) async {
        session.idToken = token
        session.email = email
        session.displayName = name
        if let existing = try? await MekasaAPIClient.shared.currentHousehold(token: token) {
            session.household = existing
            withAnimation { session.onboardingStep = resumeStep(for: existing) }
        } else {
            withAnimation { session.onboardingStep = .household }
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
            session.lastError = error.localizedDescription
        }
    }

    private func submitGoogle() async {
        session.isBusy = true
        defer { session.isBusy = false }
        print("[Mekasa] submitGoogle start")
        do {
            guard FirebaseAppHelper.googleClientID != nil else {
                session.lastError = AuthServiceError.missingGoogleClientID.localizedDescription
                return
            }
            guard let presenter = TopViewController.shared else {
                session.lastError = "Could not find a window to present Google Sign-In."
                return
            }
            let result = try await AuthService.shared.signInWithGoogle(presenting: presenter)
            await applyAuth(token: result.token, email: result.email, name: result.name)
        } catch {
            print("[Mekasa] submitGoogle ERROR: \(error)")
            session.lastError = error.localizedDescription
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
