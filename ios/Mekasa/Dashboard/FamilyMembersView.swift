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
    /// REQ-021: member whose avoid list is being edited.
    @State private var avoidEditing: HouseholdMemberDTO?

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
                trashKioskSection

                if let pending = session.pendingInviteToken, !pending.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("You have a pending invite.")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(MekasaTheme.brand)
                        PrimaryButton(title: "Accept invite", isLoading: session.isBusy) {
                            Task {
                                await session.acceptPendingInviteIfNeeded()
                                await refresh()
                            }
                        }
                    }
                    .padding(16)
                    .background(MekasaTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

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
        .sheet(item: $avoidEditing) { member in
            NavigationStack {
                AvoidEditorView(member: member) {
                    Task { await refresh() }
                }
            }
            .environmentObject(session)
        }
    }

    private func avoidSummary(for member: HouseholdMemberDTO) -> String {
        if member.avoid.isEmpty {
            return member.uid == session.userUID ? "No allergies or avoided ingredients yet" : "Nothing avoided"
        }
        let labels = member.avoid.map { AvoidanceMatcher.label(for: $0, options: session.avoidanceOptions) }
        return "Avoids " + labels.joined(separator: ", ")
    }

    private func canEditAvoid(_ member: HouseholdMemberDTO) -> Bool {
        member.uid == session.userUID || session.isHouseholdOwner
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
                    VStack(alignment: .leading, spacing: 10) {
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

                        // REQ-021 AC1: allergies / avoid list — self-editable, owners edit anyone.
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: member.avoid.isEmpty ? "leaf" : "exclamationmark.shield.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(member.avoid.isEmpty ? MekasaTheme.brandMuted : MekasaTheme.accent)
                                .padding(.top, 2)
                            Text(avoidSummary(for: member))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(member.avoid.isEmpty ? MekasaTheme.textMuted : MekasaTheme.brand)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier(TestIdentifiers.memberAvoidLabel)
                            Spacer(minLength: 0)
                            if canEditAvoid(member) {
                                Button(member.avoid.isEmpty ? "Add" : "Edit") {
                                    avoidEditing = member
                                }
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .accessibilityIdentifier(TestIdentifiers.memberAvoidEditButton)
                            }
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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(invite.name) · \(invite.role)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(MekasaTheme.brand)
                        if let link = invite.inviteLink {
                            Text(link)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(MekasaTheme.textMuted)
                                .textSelection(.enabled)
                        }
                        if let shareURL = invite.shareURL {
                            ShareLink(item: shareURL) {
                                Label("Share invite", systemImage: "square.and.arrow.up")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
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

    private var trashKioskSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trash station")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.brand)
            Text("Open full-screen dispose mode for a kitchen iPad or secondary phone.")
                .font(MekasaTheme.bodyFont)
                .foregroundStyle(MekasaTheme.textMuted)
            SecondaryButton(title: "Open trash kiosk") {
                session.isTrashKioskMode = true
            }
        }
    }

    private func refresh() async {
        guard let token = session.idToken, let householdID = session.household?.id, !session.isUIPreview else {
            members = session.householdMembers
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
            session.householdMembers = members
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
