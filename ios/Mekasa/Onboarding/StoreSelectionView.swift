import SwiftUI

/// Multi-select nearby stores (stub list from API until Places is wired).
/// Satisfies: REQ-003 AC4–AC5, UI-002 / UI-003
/// Spec version: 1.0
struct StoreSelectionView: View {
    @EnvironmentObject private var session: AppSession
    @State private var stores: [Store] = []
    @State private var selected: Set<String> = []
    @State private var query = ""
    @State private var loaded = false

    private var filtered: [Store] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return stores }
        return stores.filter {
            $0.name.lowercased().contains(q) || $0.address.lowercased().contains(q)
        }
    }

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                OnboardingHeader(step: .stores)
                    .padding(.top, 48)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Where do you shop?")
                        .font(MekasaTheme.displayFont)
                        .foregroundStyle(MekasaTheme.brand)

                    Text(subtitle)
                        .font(MekasaTheme.bodyFont)
                        .foregroundStyle(MekasaTheme.textMuted)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(MekasaTheme.textMuted)
                        TextField("Search for a store...", text: $query)
                            .font(MekasaTheme.bodyFont)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(MekasaTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1)
                    )

                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(filtered) { store in
                                StoreRow(
                                    store: store,
                                    isSelected: selected.contains(store.id)
                                ) {
                                    toggle(store.id)
                                }
                            }
                        }
                        .padding(8)
                        .background(MekasaTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 24, y: 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 40, style: .continuous)
                                .stroke(MekasaTheme.brandMuted.opacity(0.25), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 8)

                StickyBottomBar(progress: 4.0 / 6.0) {
                    PrimaryButton(
                        title: "Confirm stores",
                        disabled: selected.isEmpty,
                        isLoading: session.isBusy
                    ) {
                        Task { await confirm() }
                    }
                }
            }
        }
        .task { await load() }
    }

    private var subtitle: String {
        if let address = session.household?.address, !address.isEmpty {
            return "We'll look within 15 miles of \(address)."
        }
        return "We'll look within 15 miles of your home."
    }

    private func toggle(_ id: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if selected.contains(id) {
                selected.remove(id)
            } else {
                selected.insert(id)
            }
        }
    }

    private func load() async {
        guard !loaded, let token = session.idToken, let household = session.household else { return }
        session.isBusy = true
        defer { session.isBusy = false }
        do {
            let response = try await MekasaAPIClient.shared.nearbyStores(householdID: household.id, token: token)
            stores = response.stores
            selected = Set(household.storeIDs)
            loaded = true
        } catch {
            session.lastError = error.localizedDescription
        }
    }

    private func confirm() async {
        guard let token = session.idToken, let household = session.household else { return }
        session.isBusy = true
        defer { session.isBusy = false }
        do {
            let updated = try await MekasaAPIClient.shared.selectStores(
                householdID: household.id,
                storeIDs: Array(selected),
                token: token
            )
            session.household = updated
            withAnimation { session.onboardingStep = .initialScan }
        } catch {
            session.lastError = error.localizedDescription
        }
    }
}

private struct StoreRow: View {
    let store: Store
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white : Color(red: 0xf1 / 255, green: 0xf4 / 255, blue: 0xf3 / 255))
                        .frame(width: 48, height: 48)
                    Text(store.initials)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(MekasaTheme.brand)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.name)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                    Text(String(format: "%.1f mi", store.distanceMiles))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(isSelected ? MekasaTheme.brandMuted : MekasaTheme.textMuted)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(isSelected ? MekasaTheme.accent : Color.clear)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? MekasaTheme.accent : MekasaTheme.brandMuted, lineWidth: 2)
                        )
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(16)
            .foregroundStyle(isSelected ? Color.white : MekasaTheme.brand)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(isSelected ? MekasaTheme.brand : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private extension Store {
    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(4))
    }
}

#Preview {
    StoreSelectionView().environmentObject(AppSession())
}
