import SwiftUI

/// Family tab: members, invites, roles (REQ-019).
/// Spec version: 1.0
struct FamilyMembersView: View {
    @EnvironmentObject private var session: AppSession

    @State private var members: [HouseholdMemberDTO] = []
    @State private var invites: [HouseholdInviteDTO] = []
    @State private var name = ""
    @State private var email = ""
    @State private var role = "member"
    @State private var statusMessage: String?
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Family")
                    .font(MekasaTheme.titleFont)
                    .foregroundStyle(MekasaTheme.brand)

                if let email = session.email {
                    Text(email)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(MekasaTheme.textMuted)
                }

                membersSection
                inviteSection

                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(MekasaTheme.brand)
                }

                SecondaryButton(title: "Sign out") {
                    try? AuthService.shared.signOut()
                    session.signOut()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 64)
            .padding(.bottom, 140)
        }
        .task { await refresh() }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Members")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.brand)

            if members.isEmpty {
                Text(isLoading ? "Loading…" : "You’re the only member so far.")
                    .font(MekasaTheme.bodyFont)
                    .foregroundStyle(MekasaTheme.textMuted)
            } else {
                ForEach(members) { member in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name ?? member.email ?? member.uid)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(MekasaTheme.brand)
                            Text(member.role.capitalized)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.textMuted)
                        }
                        Spacer()
                        if member.uid != session.household?.ownerUID, member.role == "member" {
                            Button("Make owner") {
                                Task { await promote(member) }
                            }
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                    }
                    .padding(14)
                    .background(MekasaTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invite someone")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.brand)

            MekasaTextField(label: "Name", placeholder: "Sam", text: $name)
            MekasaTextField(
                label: "Email",
                placeholder: "sam@example.com",
                text: $email,
                keyboard: .emailAddress,
                autocapitalization: .never
            )
            Picker("Role", selection: $role) {
                Text("Member").tag("member")
                Text("Owner").tag("owner")
            }
            .pickerStyle(.segmented)

            PrimaryButton(title: "Send invite", isLoading: session.isBusy) {
                Task { await sendInvite() }
            }

            if !invites.isEmpty {
                Text("Pending invites")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
                    .padding(.top, 8)
                ForEach(invites.filter { $0.status == "pending" }) { invite in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(invite.name) · \(invite.role)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(MekasaTheme.brand)
                        if let link = invite.inviteLink {
                            Text(link)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(MekasaTheme.textMuted)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MekasaTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private func refresh() async {
        guard let token = session.idToken, let householdID = session.household?.id, !session.isUIPreview else {
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            async let membersTask = MekasaAPIClient.shared.listHouseholdMembers(
                householdID: householdID,
                token: token
            )
            async let invitesTask = MekasaAPIClient.shared.listHouseholdInvites(
                householdID: householdID,
                token: token
            )
            members = try await membersTask.members
            invites = try await invitesTask.invites
        } catch {
            session.handleAPIFailure(error)
            statusMessage = error.localizedDescription
        }
    }

    private func sendInvite() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedEmail.isEmpty else {
            statusMessage = "Name and email are required."
            return
        }
        guard let token = session.idToken, let householdID = session.household?.id else {
            statusMessage = "Sign in to invite members."
            return
        }
        session.isBusy = true
        defer { session.isBusy = false }
        do {
            _ = try await MekasaAPIClient.shared.createHouseholdInvite(
                householdID: householdID,
                name: trimmedName,
                email: trimmedEmail,
                phone: nil,
                role: role,
                token: token
            )
            name = ""
            email = ""
            statusMessage = "Invite sent."
            await refresh()
        } catch {
            session.handleAPIFailure(error)
            statusMessage = error.localizedDescription
        }
    }

    private func promote(_ member: HouseholdMemberDTO) async {
        guard let token = session.idToken, let householdID = session.household?.id else { return }
        do {
            _ = try await MekasaAPIClient.shared.updateHouseholdMemberRole(
                householdID: householdID,
                memberUID: member.uid,
                role: "owner",
                token: token
            )
            statusMessage = "\(member.name ?? member.uid) is now an owner."
            await refresh()
        } catch {
            session.handleAPIFailure(error)
            statusMessage = error.localizedDescription
        }
    }
}
