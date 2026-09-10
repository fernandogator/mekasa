import SwiftUI

/// Invite household members during onboarding (REQ-019).
/// Spec version: 1.0
struct InviteView: View {
    @EnvironmentObject private var session: AppSession
    @State private var name = ""
    @State private var inviteEmail = ""
    @State private var invitePhone = ""
    @State private var role: InviteRole = .member
    @State private var lastInviteLink: String?
    @State private var statusMessage: String?

    private enum InviteRole: String, CaseIterable, Identifiable {
        case member
        case owner
        var id: String { rawValue }
        var label: String { self == .owner ? "Owner" : "Member" }
    }

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

                        Text("Owners manage inventory and spending. Members can scan and request items. Send a name plus email or phone.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)

                        MekasaTextField(
                            label: "Name",
                            placeholder: "Alex",
                            text: $name
                        )

                        MekasaTextField(
                            label: "Invite email",
                            placeholder: "partner@example.com",
                            text: $inviteEmail,
                            keyboard: .emailAddress,
                            autocapitalization: .never
                        )
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()

                        MekasaTextField(
                            label: "Phone (optional)",
                            placeholder: "+1 555 0100",
                            text: $invitePhone,
                            keyboard: .phonePad
                        )

                        Picker("Role", selection: $role) {
                            ForEach(InviteRole.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)

                        if let statusMessage {
                            Text(statusMessage)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.brand)
                        }

                        if let lastInviteLink {
                            Text(lastInviteLink)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(MekasaTheme.textMuted)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 140)
                }

                StickyBottomBar(progress: 1.0) {
                    VStack(spacing: 12) {
                        PrimaryButton(title: "Send invite", isLoading: session.isBusy) {
                            Task { await sendInvite(thenFinish: false) }
                        }
                        PrimaryButton(title: "Send invite & finish") {
                            Task { await sendInvite(thenFinish: true) }
                        }
                        SecondaryButton(title: "Skip for now") {
                            withAnimation { session.onboardingStep = .done }
                        }
                    }
                }
            }
        }
    }

    private func sendInvite(thenFinish: Bool) async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = invitePhone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusMessage = "Name is required."
            return
        }
        guard !email.isEmpty || !phone.isEmpty else {
            statusMessage = "Add an email or phone number."
            return
        }

        if session.isUIPreview || session.idToken == nil || session.household?.id == nil {
            statusMessage = "Invite saved locally (preview)."
            lastInviteLink = "mekasa://invite/preview"
            if thenFinish { withAnimation { session.onboardingStep = .done } }
            return
        }

        guard let token = session.idToken, let householdID = session.household?.id else {
            statusMessage = "Not signed in."
            return
        }

        session.isBusy = true
        defer { session.isBusy = false }
        do {
            let invite = try await MekasaAPIClient.shared.createHouseholdInvite(
                householdID: householdID,
                name: trimmedName,
                email: email.isEmpty ? nil : email,
                phone: phone.isEmpty ? nil : phone,
                role: role.rawValue,
                token: token
            )
            lastInviteLink = invite.inviteLink
            statusMessage = "Invite created for \(invite.name)."
            name = ""
            inviteEmail = ""
            invitePhone = ""
            if thenFinish {
                withAnimation { session.onboardingStep = .done }
            }
        } catch {
            session.handleAPIFailure(error)
            statusMessage = error.localizedDescription
        }
    }
}

#Preview {
    InviteView().environmentObject(AppSession())
}
