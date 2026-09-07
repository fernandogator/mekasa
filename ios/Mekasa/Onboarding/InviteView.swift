import SwiftUI

/// Invite spouse / members prompt (download invite later).
/// Satisfies: REQ-019 (prompt only), UI-003 AC1
/// Spec version: 1.0
struct InviteView: View {
    @EnvironmentObject private var session: AppSession
    @State private var inviteEmail = ""

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                OnboardingHeader(step: .invite)
                    .padding(.top, 48)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Invite your household.")
                            .font(MekasaTheme.displayFont)
                            .foregroundStyle(MekasaTheme.brand)
                            .padding(.top, 36)

                        Text("Owners can manage inventory and spending. Members can help scan. Invite APIs come later — save the email for now or skip.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)

                        MekasaTextField(
                            label: "Invite email",
                            placeholder: "partner@example.com",
                            text: $inviteEmail,
                            keyboard: .emailAddress,
                            autocapitalization: .never
                        )
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 140)
                }

                StickyBottomBar(progress: 1.0) {
                    VStack(spacing: 12) {
                        PrimaryButton(title: "Finish setup") {
                            withAnimation { session.onboardingStep = .done }
                        }
                        SecondaryButton(title: "Skip for now") {
                            withAnimation { session.onboardingStep = .done }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    InviteView().environmentObject(AppSession())
}
