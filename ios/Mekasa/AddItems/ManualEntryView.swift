import SwiftUI

/// Manual inventory entry with optional Open Food Facts variant picker (REQ-006).
/// Spec version: 1.0
struct ManualEntryView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category = InventoryCategory.pantry
    @State private var quantity = 1
    @State private var priceText = ""
    @State private var didSave = false

    @State private var searchResults: [ProductSearchHitDTO] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var didSearch = false
    @State private var confirmDraft: InventoryItem?
    @State private var showConfirm = false

    private var pricePaid: Double? {
        let trimmed = priceText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && quantity > 0
    }

    private var canSearch: Bool {
        trimmedName.count >= 2 && session.canSyncInventory && !isSearching
    }

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(title: "Type it in", onBack: { dismiss() })
                    .accessibilityIdentifier(TestIdentifiers.cancelButton)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Search for a product variant, or add the name as typed.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)

                        MekasaTextField(
                            label: "Item name",
                            placeholder: "e.g. Oreos",
                            text: $name,
                            autocapitalization: .words
                        )
                        .accessibilityIdentifier(TestIdentifiers.nameField)
                        .onChange(of: name) { _, _ in
                            searchResults = []
                            didSearch = false
                            searchError = nil
                        }

                        if session.canSyncInventory {
                            Button {
                                Task { await findProducts() }
                            } label: {
                                HStack {
                                    if isSearching {
                                        ProgressView()
                                    }
                                    Text(isSearching ? "Searching…" : "Find matching products")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(canSearch ? MekasaTheme.brand : MekasaTheme.textMuted)
                                .background(MekasaTheme.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(!canSearch)
                            .accessibilityIdentifier(TestIdentifiers.scanButton)

                            if let searchError {
                                Text(searchError)
                                    .font(MekasaTheme.bodyFont)
                                    .foregroundStyle(MekasaTheme.textMuted)
                            }

                            if didSearch && searchResults.isEmpty && !isSearching {
                                Text("No catalog matches. You can still add “\(trimmedName)” as typed.")
                                    .font(MekasaTheme.bodyFont)
                                    .foregroundStyle(MekasaTheme.textMuted)
                            }

                            if !searchResults.isEmpty {
                                Text("Pick a variant")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(MekasaTheme.textMuted)
                                    .textCase(.uppercase)

                                ForEach(searchResults) { hit in
                                    Button {
                                        selectHit(hit)
                                    } label: {
                                        ProductSearchHitRow(hit: hit)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier(TestIdentifiers.itemCell)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .tracking(1)
                                .textCase(.uppercase)
                                .foregroundStyle(MekasaTheme.textMuted)
                                .padding(.leading, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(InventoryCategory.allCases) { cat in
                                        categoryChip(cat)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        .accessibilityIdentifier(TestIdentifiers.categoryPicker)

                        quantityStepper
                            .accessibilityIdentifier(TestIdentifiers.quantityField)

                        MekasaTextField(
                            label: "Price paid (optional)",
                            placeholder: "0.00",
                            text: $priceText,
                            keyboard: .decimalPad,
                            autocapitalization: .never
                        )
                        .accessibilityIdentifier(TestIdentifiers.locationField)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 140)
                    .accessibilityIdentifier(TestIdentifiers.addItemForm)
                }

                StickyBottomBar(progress: nil) {
                    PrimaryButton(title: "Add as typed", disabled: !canSave) {
                        saveTyped()
                    }
                    .accessibilityIdentifier(TestIdentifiers.saveButton)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showConfirm) {
            if let confirmDraft {
                ItemConfirmView(drafts: [confirmDraft], title: "Confirm item") {
                    dismiss()
                }
            }
        }
        .alert("Added", isPresented: $didSave) {
            Button("Add another") {
                name = ""
                quantity = 1
                priceText = ""
                searchResults = []
                didSearch = false
                didSave = false
            }
            Button("Done", role: .cancel) {
                dismiss()
            }
        } message: {
            Text(session.canSyncInventory
                  ? "Saved to your household inventory."
                  : "Saved on this device (sign in to sync).")
        }
    }

    private func productHitRow(_ hit: ProductSearchHitDTO) -> some View {
        HStack(spacing: 12) {
            ProductThumbnail(urlString: hit.imageUrl, size: 52, cornerRadius: 14)
            VStack(alignment: .leading, spacing: 4) {
                Text(hit.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.brand)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Text(hit.category)
                    if let brand = hit.brand, !brand.isEmpty {
                        Text("·")
                        Text(brand)
                    }
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(MekasaTheme.textMuted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MekasaTheme.brandMuted)
        }
        .padding(12)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var quantityStepper: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quantity")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(MekasaTheme.textMuted)
                .padding(.leading, 16)

            HStack {
                Button {
                    quantity = max(1, quantity - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(MekasaTheme.surfaceElevated)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(MekasaTheme.brandMuted.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Decrease quantity")

                Text("\(quantity)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(MekasaTheme.brand)
                    .frame(maxWidth: .infinity)

                Button {
                    quantity += 1
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(MekasaTheme.surfaceElevated)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(MekasaTheme.brandMuted.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Increase quantity")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(MekasaTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1)
            )
            .foregroundStyle(MekasaTheme.brand)
        }
    }

    private func categoryChip(_ cat: InventoryCategory) -> some View {
        let selected = category == cat
        return Button {
            category = cat
        } label: {
            Text(cat.rawValue)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(selected ? Color.white : MekasaTheme.brand)
                .background(selected ? MekasaTheme.brand : MekasaTheme.surfaceElevated)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(MekasaTheme.brandMuted.opacity(selected ? 0 : 0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func findProducts() async {
        guard canSearch, let token = session.idToken else { return }
        isSearching = true
        searchError = nil
        defer { isSearching = false }
        do {
            let response = try await MekasaAPIClient.shared.searchProducts(
                query: trimmedName,
                limit: 8,
                token: token
            )
            searchResults = response.results
            didSearch = true
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                session.handleAPIFailure(error)
            } else {
                searchError = "Couldn’t search the product catalog. Try again or add as typed."
            }
            searchResults = []
            didSearch = true
        }
    }

    private func selectHit(_ hit: ProductSearchHitDTO) {
        if let matched = InventoryCategory(rawValue: hit.category) {
            category = matched
        }
        name = hit.name
        confirmDraft = hit.toDraft(quantity: quantity, pricePaid: pricePaid)
        showConfirm = true
    }

    private func saveTyped() {
        let item = InventoryItem(
            name: trimmedName,
            category: category.rawValue,
            quantity: quantity,
            pricePaid: pricePaid,
            source: .manual
        )
        session.addInventoryItem(item)
        didSave = true
    }
}

#Preview {
    NavigationStack {
        ManualEntryView()
    }
    .environmentObject(AppSession())
}
