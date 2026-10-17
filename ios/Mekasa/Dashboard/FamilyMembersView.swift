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
    @State private var isRefreshingAll = false
    /// REQ-021: member whose avoid list is being edited.
    @State private var avoidEditing: HouseholdMemberDTO?
    @State private var scanSoundsEnabled = ScanFeedback.soundsEnabled
    @ObservedObject private var faceIDLock = FaceIDLock.shared
    @State private var faceIDEnabled = FaceIDLock.shared.isEnabled
    @ObservedObject private var themePreferences = ThemePreferences.shared
    @State private var isSendingDiagnostics = false
    @State private var diagnosticsStatus: String?
    /// REQ-003 AC11: owner opened the store picker.
    @State private var showStorePicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Family")
                    .font(MekasaTheme.titleFont)
                    .foregroundStyle(MekasaTheme.text)

                accountCard
                householdCard

                membersSection
                inviteSection
                scanSoundsSection
                appearanceSection
                faceIDLockSection
                groceryStoresSection
                trashKioskSection
                helpSection

                if let pending = session.pendingInviteToken, !pending.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("You have a pending invite.")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(MekasaTheme.text)
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
                        .foregroundStyle(MekasaTheme.text)
                }

                SecondaryButton(title: isRefreshingAll ? "Refreshing…" : "Refresh data", disabled: isRefreshingAll) {
                    Task { await refreshAll() }
                }
                .accessibilityIdentifier(TestIdentifiers.familyRefreshButton)

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
        .sheet(isPresented: $showStorePicker) {
            StorePickerSheet()
                .environmentObject(session)
        }
    }

    /// Saved stores with name, address and distance; owners can choose or change them.
    /// Satisfies: REQ-003 AC11
    /// Spec version: 1.0
    private var groceryStoresSection: some View {
        let stores = session.household?.stores ?? []
        return VStack(alignment: .leading, spacing: 12) {
            Text("Grocery stores")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.text)
                .accessibilityAddTraits(.isHeader)

            if stores.isEmpty {
                Text(ShoppingStores.emptySettingsMessage)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(TestIdentifiers.groceryStoresEmpty)
            } else {
                ForEach(stores) { store in
                    groceryStoreRow(store)
                }
            }

            if session.isHouseholdOwner {
                SecondaryButton(title: stores.isEmpty ? "Choose stores" : "Change stores") {
                    showStorePicker = true
                }
                .accessibilityIdentifier(TestIdentifiers.chooseStoresButton)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TestIdentifiers.groceryStoresSection)
    }

    /// Satisfies: REQ-003 AC11
    /// Spec version: 1.0
    private func groceryStoreRow(_ store: SavedStore) -> some View {
        let distance = ShoppingStores.miles(store.distanceMiles)
        return HStack(spacing: 12) {
            StoreLogoCircle(name: store.name)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.text)
                if !store.address.isEmpty {
                    Text(store.address)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(MekasaTheme.textMuted)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            if !distance.isEmpty {
                Text(distance)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel([store.name, store.address, distance].filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityIdentifier(TestIdentifiers.groceryStoreRow)
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

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(FamilySummary.accountTitle(displayName: session.displayName, email: session.email))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(MekasaTheme.text)
                .accessibilityIdentifier(TestIdentifiers.familyAccountTitle)
            if let subtitle = FamilySummary.accountSubtitle(displayName: session.displayName, email: session.email) {
                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
            }
            if session.isUIPreview {
                Text(FamilySummary.offlinePreviewNotice)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.warning)
                    .padding(.top, 4)
                    .accessibilityIdentifier(TestIdentifiers.familyOfflineNotice)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var householdCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "house.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(MekasaTheme.text)
                .frame(width: 40, height: 40)
                .background(MekasaTheme.successTint)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(FamilySummary.householdTitle(session.household))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.text)
                    .accessibilityIdentifier(TestIdentifiers.familyHouseholdTitle)
                Text(FamilySummary.householdAddress(session.household))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
                    .lineLimit(2)
                    .accessibilityIdentifier(TestIdentifiers.familyHouseholdAddress)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Members")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.text)

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
                                    .foregroundStyle(MekasaTheme.text)
                                Text(FamilySummary.memberSubtitle(role: member.role, status: member.status))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(MekasaTheme.textMuted)
                                    .accessibilityIdentifier(TestIdentifiers.familyMemberSubtitle)
                            }
                            Spacer()
                            if canChangeRole(of: member) {
                                HStack(spacing: 12) {
                                    if member.role != "member" {
                                        Button("Make member") {
                                            Task { await setRole(member, role: "member") }
                                        }
                                    }
                                    if member.role != "teen" {
                                        Button("Make teen") {
                                            Task { await setRole(member, role: "teen") }
                                        }
                                    }
                                    if member.role != "owner" {
                                        Button("Make owner") {
                                            Task { await setRole(member, role: "owner") }
                                        }
                                    }
                                }
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                        }

                        // REQ-021 AC1: allergies / avoid list — self-editable, owners edit anyone.
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: member.avoid.isEmpty ? "leaf" : "exclamationmark.shield.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(member.avoid.isEmpty ? MekasaTheme.border : MekasaTheme.danger)
                                .padding(.top, 2)
                            Text(avoidSummary(for: member))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(member.avoid.isEmpty ? MekasaTheme.textMuted : MekasaTheme.text)
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
                .foregroundStyle(MekasaTheme.text)

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
                Text("Teen").tag("teen")
                Text("Owner").tag("owner")
            }
            .pickerStyle(.segmented)
            Text("Teens and members share the home photo. Only owners can change it. Mekasa does not email the invite — share the link, or have them sign in with this address.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(MekasaTheme.textMuted)

            PrimaryButton(title: "Create invite", isLoading: session.isBusy) {
                Task { await sendInvite() }
            }

            if !invites.isEmpty {
                Text("Pending invites")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
                    .padding(.top, 8)
                ForEach(invites.filter { $0.status == "pending" }) { invite in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(invite.name) · \(FamilySummary.roleLabel(invite.role))")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(MekasaTheme.text)
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

    private var scanSoundsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scanner")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.text)
            Toggle(isOn: $scanSoundsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan sounds")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(MekasaTheme.text)
                    Text("Beep and haptic when a barcode is read.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(MekasaTheme.textMuted)
                }
            }
            .tint(MekasaTheme.accent)
            .onChange(of: scanSoundsEnabled) { _, enabled in
                ScanFeedback.soundsEnabled = enabled
                if enabled { ScanFeedback.prepare() }
            }
            .accessibilityIdentifier(TestIdentifiers.scanSoundsToggle)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.text)
            Text("Theme")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(MekasaTheme.textMuted)
            ForEach(MekasaPaletteStyle.allCases) { option in
                Button {
                    themePreferences.select(option)
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        palettePreviewStrip(for: option)
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.title)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(MekasaTheme.text)
                                Text(option.subtitle)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(MekasaTheme.textMuted)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            if themePreferences.style == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(MekasaTheme.accent)
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        themePreferences.style == option
                            ? MekasaTheme.surfaceElevated
                            : MekasaTheme.surfaceMuted
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                themePreferences.style == option ? MekasaTheme.accent : MekasaTheme.line,
                                lineWidth: themePreferences.style == option ? 2 : 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(
                    option == .halloween
                        ? TestIdentifiers.halloweenThemeCard
                        : TestIdentifiers.groundedThemeCard
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TestIdentifiers.appearanceSection)
    }

    /// Static light swatches so both cards preview correctly regardless of the active palette.
    private func palettePreviewStrip(for option: MekasaPaletteStyle) -> some View {
        let light = PaletteTokens.tokens(for: option).light
        return HStack(spacing: 0) {
            rgbColor(light.brand)
            rgbColor(light.accent)
            rgbColor(light.surface)
        }
        .frame(height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func rgbColor(_ rgb: UInt32) -> Color {
        Color(
            red: Double((rgb >> 16) & 0xff) / 255,
            green: Double((rgb >> 8) & 0xff) / 255,
            blue: Double(rgb & 0xff) / 255
        )
    }

    private var faceIDLockSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Security")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.text)
            Toggle(isOn: $faceIDEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock with \(faceIDLock.biometryLabel)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(MekasaTheme.text)
                    Text("Require \(faceIDLock.biometryLabel) when you open Mekasa again.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(MekasaTheme.textMuted)
                }
            }
            .tint(MekasaTheme.accent)
            .onChange(of: faceIDEnabled) { _, enabled in
                if enabled {
                    if session.isUITesting {
                        faceIDLock.isEnabled = true
                        faceIDLock.markUnlockedForTesting()
                        return
                    }
                    Task {
                        let ok = await faceIDLock.enableWithPrompt()
                        if !ok { faceIDEnabled = false }
                    }
                } else {
                    faceIDLock.disable()
                }
            }
            .accessibilityIdentifier(TestIdentifiers.faceIDLockToggle)
            if let statusMessage = faceIDLock.statusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(MekasaTheme.danger)
                    .accessibilityIdentifier(TestIdentifiers.faceIDLockStatus)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear { faceIDEnabled = faceIDLock.isEnabled }
    }

    private var trashKioskSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trash station")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.text)
            Text("Open full-screen dispose mode for a kitchen iPad or secondary phone.")
                .font(MekasaTheme.bodyFont)
                .foregroundStyle(MekasaTheme.textMuted)
            SecondaryButton(title: "Open trash kiosk") {
                session.isTrashKioskMode = true
            }
        }
    }

    /// NFR-007 AC5 (design/pages/family-members.html, Help card).
    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Help")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.text)
            HStack(spacing: 14) {
                Image(systemName: "lifepreserver")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(MekasaTheme.brand)
                    .frame(width: 44, height: 44)
                    .background(MekasaTheme.surface)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Send diagnostics")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(MekasaTheme.text)
                    Text("Sends this phone's recent app log to Mekasa support.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(MekasaTheme.textMuted)
                }
            }
            SecondaryButton(
                title: "Send diagnostics",
                disabled: isSendingDiagnostics || !session.canSendDiagnostics,
                isLoading: isSendingDiagnostics
            ) {
                Task {
                    isSendingDiagnostics = true
                    diagnosticsStatus = nil
                    diagnosticsStatus = await session.sendDiagnostics()
                    isSendingDiagnostics = false
                }
            }
            .accessibilityIdentifier(TestIdentifiers.sendDiagnosticsButton)
            if let diagnosticsStatus {
                Text(diagnosticsStatus)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        diagnosticsStatus == AppSession.diagnosticsFailed ? MekasaTheme.danger : MekasaTheme.brand
                    )
                    .accessibilityIdentifier(TestIdentifiers.diagnosticsStatus)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    /// Android "Refresh data": pull inventory, list, spending and membership again.
    private func refreshAll() async {
        isRefreshingAll = true
        defer { isRefreshingAll = false }
        guard !session.isUIPreview else {
            statusMessage = "Up to date."
            return
        }
        await session.refreshInventory()
        await session.refreshShoppingList(syncLowStock: true)
        await session.refreshSpending()
        await session.refreshMyMembership()
        await refresh()
        statusMessage = session.lastError == nil ? "Up to date." : statusMessage
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
            statusMessage = "Invite saved for \(trimmedName). No email was sent. Share the link below, or have them sign in with \(trimmedEmail)."
            await refresh()
        } catch {
            session.handleAPIFailure(error)
            statusMessage = error.localizedDescription
        }
    }

    /// Owners assign roles. The household's original owner stays an owner.
    private func canChangeRole(of member: HouseholdMemberDTO) -> Bool {
        session.isHouseholdOwner
            && member.uid != session.userUID
            && member.uid != session.household?.ownerUID
    }

    private func setRole(_ member: HouseholdMemberDTO, role: String) async {
        guard let token = session.idToken, let householdID = session.household?.id else { return }
        do {
            _ = try await MekasaAPIClient.shared.updateHouseholdMemberRole(
                householdID: householdID,
                memberUID: member.uid,
                role: role,
                token: token
            )
            let name = member.name ?? member.uid
            statusMessage = "\(name) is now \(FamilySummary.roleLabel(role))."
            await refresh()
        } catch {
            session.handleAPIFailure(error)
            statusMessage = error.localizedDescription
        }
    }
}
