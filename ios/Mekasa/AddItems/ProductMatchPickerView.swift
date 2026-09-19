import SwiftUI

/// Pick a catalog product for an unmatched receipt / manual draft (REQ-005 / REQ-006).
/// Spec version: 1.0
struct ProductMatchPickerView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    let initialQuery: String
    let onSelect: (ProductSearchHitDTO) -> Void

    @State private var query: String
    @State private var results: [ProductSearchHitDTO] = []
    @State private var isSearching = false
    @State private var didSearch = false
    @State private var errorMessage: String?

    init(initialQuery: String, onSelect: @escaping (ProductSearchHitDTO) -> Void) {
        self.initialQuery = initialQuery
        self.onSelect = onSelect
        _query = State(initialValue: initialQuery)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSearch: Bool {
        trimmedQuery.count >= 2 && session.canSyncInventory && !isSearching
    }

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(title: "Match product", onBack: { dismiss() })

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Search the catalog and pick the right variant.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)

                        MekasaTextField(
                            label: "Search",
                            placeholder: "e.g. Oreos",
                            text: $query,
                            autocapitalization: .words
                        )
                        .accessibilityIdentifier(TestIdentifiers.nameField)

                        Button {
                            Task { await search() }
                        } label: {
                            HStack {
                                if isSearching { ProgressView() }
                                Text(isSearching ? "Searching…" : "Search catalog")
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

                        if let errorMessage {
                            Text(errorMessage)
                                .font(MekasaTheme.bodyFont)
                                .foregroundStyle(MekasaTheme.textMuted)
                        }

                        if didSearch && results.isEmpty && !isSearching {
                            Text("No catalog matches for “\(trimmedQuery)”. Try a shorter name.")
                                .font(MekasaTheme.bodyFont)
                                .foregroundStyle(MekasaTheme.textMuted)
                                .accessibilityIdentifier(TestIdentifiers.emptyStateView)
                        }

                        if !results.isEmpty {
                            Text("Pick a variant")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(MekasaTheme.textMuted)
                                .textCase(.uppercase)

                            ForEach(results) { hit in
                                Button {
                                    onSelect(hit)
                                    dismiss()
                                } label: {
                                    ProductSearchHitRow(hit: hit)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier(TestIdentifiers.itemCell)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            guard canSearch else { return }
            await search()
        }
    }

    private func search() async {
        guard canSearch, let token = session.idToken else { return }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            let response = try await MekasaAPIClient.shared.searchProducts(
                query: trimmedQuery,
                limit: 8,
                token: token
            )
            results = response.results
            didSearch = true
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                session.handleAPIFailure(error)
            } else {
                errorMessage = "Couldn’t search the product catalog."
            }
            results = []
            didSearch = true
        }
    }
}

struct ProductSearchHitRow: View {
    let hit: ProductSearchHitDTO

    var body: some View {
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
}
