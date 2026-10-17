import SwiftUI

/// State shared by the onboarding store step and the Family → Grocery stores sheet:
/// load nearby stores, ask for the home address when there are no coordinates,
/// and save the checked stores with their details.
/// Satisfies: REQ-003 AC3–AC7, AC10, AC11
/// Spec version: 1.0
@MainActor
final class StorePickerModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case address
        case list
        case failed
    }

    @Published var phase: Phase = .loading
    @Published var stores: [SavedStore] = []
    @Published var placesIDs: Set<String> = []
    @Published var selected: Set<String> = []
    @Published var query = ""
    @Published var address = ""
    @Published var message: String?
    @Published var isWorking = false
    private var didStart = false

    var selectedStores: [SavedStore] {
        ShoppingStores.selectedStores(stores, selected: selected)
    }

    /// Satisfies: REQ-003 AC11 (only stores saved with details start checked)
    /// Spec version: 1.0
    func start(session: AppSession) async {
        guard !didStart else { return }
        didStart = true
        selected = ShoppingStores.preselectedIDs(session.household)
        address = session.household?.address ?? ""
        await load(session: session)
    }

    /// Satisfies: REQ-003 AC4, AC10, AC11
    /// Spec version: 1.0
    func load(session: AppSession) async {
        phase = .loading
        message = nil
        switch await session.loadStorePicker() {
        case let .stores(rows, placesIDs: places):
            stores = rows
            placesIDs = places
            phase = .list
        case .needsLocation:
            phase = .address
        case .failed:
            message = session.lastError
            phase = .failed
        }
    }

    /// Satisfies: REQ-003 AC3, AC7, AC11
    /// Spec version: 1.0
    func findStores(session: AppSession) async {
        isWorking = true
        defer { isWorking = false }
        message = nil
        if let error = await session.saveHomeAddressForStoreSearch(address) {
            message = error
            return
        }
        await load(session: session)
    }

    /// Satisfies: REQ-003 AC3, AC11
    /// Spec version: 1.0
    func editAddress(session: AppSession) {
        if let current = session.household?.address, !current.isEmpty {
            address = current
        }
        message = nil
        phase = .address
    }

    /// Satisfies: REQ-003 AC5, AC6, AC11
    /// Spec version: 1.0
    func confirm(session: AppSession) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        message = nil
        let saved = await session.saveStores(selectedStores)
        if !saved { message = session.lastError }
        return saved
    }
}

/// Search field plus the checkable store rows (design 02-store-selection).
/// Satisfies: REQ-003 AC4, AC5, AC11
/// Spec version: 1.0
struct StorePickerList: View {
    let stores: [SavedStore]
    var placesIDs: Set<String> = []
    @Binding var selected: Set<String>
    @Binding var query: String

    private var filtered: [SavedStore] {
        ShoppingStores.filterStores(stores, query: query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(MekasaTheme.textMuted)
                    .accessibilityHidden(true)
                TextField("Search for a store...", text: $query)
                    .font(MekasaTheme.bodyFont)
                    .accessibilityLabel("Search stores by name or address")
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
                    if filtered.isEmpty {
                        Text(stores.isEmpty ? "No stores found within 15 miles." : "No stores match your search.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    ForEach(filtered) { store in
                        StorePickerRow(
                            store: store,
                            isPlaces: placesIDs.contains(store.id),
                            isSelected: selected.contains(store.id)
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if selected.contains(store.id) {
                                    selected.remove(store.id)
                                } else {
                                    selected.insert(store.id)
                                }
                            }
                        }
                    }
                }
                .padding(8)
                .background(MekasaTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .shadow(color: MekasaTheme.shadow.opacity(0.08), radius: 24, y: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .stroke(MekasaTheme.brandMuted.opacity(0.25), lineWidth: 1)
                )
            }
        }
    }
}

/// One store row: logo circle, name, distance and address, check toggle.
/// Satisfies: REQ-003 AC5, AC11
/// Spec version: 1.0
struct StorePickerRow: View {
    let store: SavedStore
    var isPlaces = false
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                StoreLogoCircle(name: store.name, highlighted: isSelected)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(store.name)
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                        if isPlaces {
                            Text("Places")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(isSelected ? MekasaTheme.onBrandMuted : MekasaTheme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .overlay(
                                    Capsule().stroke(
                                        isSelected ? MekasaTheme.onBrandMuted : MekasaTheme.accent,
                                        lineWidth: 1
                                    )
                                )
                        }
                    }
                    let distance = ShoppingStores.miles(store.distanceMiles)
                    if !distance.isEmpty {
                        Text(distance)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(isSelected ? MekasaTheme.onBrandMuted : MekasaTheme.textMuted)
                    }
                    if !store.address.isEmpty {
                        Text(store.address)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .foregroundStyle(isSelected ? MekasaTheme.onBrandMuted : MekasaTheme.textMuted)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(isSelected ? MekasaTheme.accent : Color.clear)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? MekasaTheme.accent : MekasaTheme.border, lineWidth: 2)
                        )
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(MekasaTheme.onAccent)
                    }
                }
                .accessibilityHidden(true)
            }
            .padding(16)
            .frame(minHeight: 44)
            .foregroundStyle(isSelected ? MekasaTheme.onBrand : MekasaTheme.text)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(isSelected ? MekasaTheme.brand : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityText: String {
        let distance = ShoppingStores.miles(store.distanceMiles)
        return [store.name, distance, store.address].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

/// Logo circle with the store's initials.
/// Satisfies: REQ-003 AC11
/// Spec version: 1.0
struct StoreLogoCircle: View {
    let name: String
    var highlighted = false

    var body: some View {
        ZStack {
            Circle()
                .fill(highlighted ? MekasaTheme.surfaceElevated : MekasaTheme.surfaceMuted)
                .frame(width: 48, height: 48)
            Text(ShoppingStores.initials(name))
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(MekasaTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 4)
        }
        .frame(width: 48, height: 48)
        .accessibilityHidden(true)
    }
}

/// Asks for the home address when the household has no coordinates, then searches.
/// Satisfies: REQ-003 AC3, AC7, AC11
/// Spec version: 1.0
struct StoreAddressPrompt: View {
    @Binding var address: String
    let isLoading: Bool
    let message: String?
    let onFind: () -> Void

    private var trimmed: String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("First, tell us where home is so we can find stores near you.")
                .font(MekasaTheme.bodyFont)
                .foregroundStyle(MekasaTheme.textMuted)
            MekasaTextField(
                label: "Home address",
                placeholder: "Street, city, state",
                text: $address,
                autocapitalization: .words,
                submitLabel: .search,
                onSubmit: {
                    if !trimmed.isEmpty { onFind() }
                },
                fieldIdentifier: TestIdentifiers.storeAddressField
            )
            if let message {
                Text(message)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(MekasaTheme.danger)
                    .accessibilityIdentifier(TestIdentifiers.storePickerMessage)
            }
            PrimaryButton(title: "Find stores", disabled: trimmed.isEmpty, isLoading: isLoading) {
                onFind()
            }
            .accessibilityIdentifier(TestIdentifiers.storeFindButton)
        }
    }
}

/// Family → Grocery stores picker, shown as a sheet. Cancel closes it; Confirm saves
/// the checked stores with their details and closes it.
/// Satisfies: REQ-003 AC11
/// Spec version: 1.0
struct StorePickerSheet: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = StorePickerModel()

    var body: some View {
        NavigationStack {
            MekasaScreen {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Where do you shop?")
                        .font(MekasaTheme.displayFont)
                        .foregroundStyle(MekasaTheme.text)

                    content
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
            .navigationTitle("Grocery stores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier(TestIdentifiers.storePickerCancelButton)
                }
            }
        }
        .accessibilityIdentifier(TestIdentifiers.storePickerSheet)
        .task { await model.start(session: session) }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView()
                .tint(MekasaTheme.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .address:
            StoreAddressPrompt(
                address: $model.address,
                isLoading: model.isWorking,
                message: model.message
            ) {
                Task { await model.findStores(session: session) }
            }
            Spacer()
        case .failed:
            Text(model.message ?? "Couldn’t load stores. Try again.")
                .font(MekasaTheme.bodyFont)
                .foregroundStyle(MekasaTheme.textMuted)
            SecondaryButton(title: "Try again") {
                Task { await model.load(session: session) }
            }
            Spacer()
        case .list:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(StoreSelectionCopy.subtitle(address: session.household?.address))
                    .font(MekasaTheme.bodyFont)
                    .foregroundStyle(MekasaTheme.textMuted)
                Spacer(minLength: 0)
                Button("Edit address") { model.editAddress(session: session) }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.text)
                    .frame(minWidth: 44, minHeight: 44)
            }
            StorePickerList(
                stores: model.stores,
                placesIDs: model.placesIDs,
                selected: $model.selected,
                query: $model.query
            )
            if let message = model.message {
                Text(message)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(MekasaTheme.danger)
                    .accessibilityIdentifier(TestIdentifiers.storePickerMessage)
            }
            PrimaryButton(title: "Confirm stores", isLoading: model.isWorking) {
                Task {
                    if await model.confirm(session: session) {
                        dismiss()
                    }
                }
            }
            .accessibilityIdentifier(TestIdentifiers.storeConfirmButton)
        }
    }
}

/// Copy shared by both pickers.
/// Satisfies: REQ-003 AC4, AC11
/// Spec version: 1.0
enum StoreSelectionCopy {
    static func subtitle(address: String?) -> String {
        if let address, !address.isEmpty {
            return "We'll look within 15 miles of \(address)."
        }
        return "We'll look within 15 miles of your home."
    }
}
