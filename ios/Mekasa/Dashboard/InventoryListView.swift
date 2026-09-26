import SwiftUI

/// Full household inventory: searchable, grouped by category, with an Add entry point
/// (UI-006 AC6–AC7) and swipe Use 1 / Remove (REQ-INV-014–018).
/// Spec version: 1.0
struct InventoryListView: View {
    @EnvironmentObject private var session: AppSession
    @State private var query = ""
    @State private var showAddItems = false

    private var sections: [InventoryListModel.Section] {
        InventoryListModel.sections(session.inventory, query: query)
    }

    private var hasQuery: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        MekasaScreen {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    header

                    if session.inventory.isEmpty {
                        emptyState
                    } else {
                        List {
                            searchRow

                            if sections.isEmpty {
                                Text(InventoryListModel.noMatchesMessage(query: query))
                                    .font(MekasaTheme.bodyFont)
                                    .foregroundStyle(MekasaTheme.textMuted)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .accessibilityIdentifier(TestIdentifiers.inventoryNoMatches)
                            }

                            ForEach(sections) { section in
                                Section {
                                    ForEach(section.items) { item in
                                        row(item)
                                    }
                                } header: {
                                    Text(section.category)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .tracking(1)
                                        .textCase(.uppercase)
                                        .foregroundStyle(MekasaTheme.textMuted)
                                        .accessibilityIdentifier(TestIdentifiers.inventorySectionHeader)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                        .accessibilityIdentifier(TestIdentifiers.itemList)
                    }
                }

                if session.showInventoryUndoToast {
                    undoToast
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: session.showInventoryUndoToast)
        }
        // `.contain` keeps descendants' own identifiers (ItemCell, InventoryUndoButton…);
        // without it every child is reported as "InventoryListView".
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TestIdentifiers.inventoryListView)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: String.self) { itemID in
            ItemDetailView(itemID: itemID)
        }
        .sheet(isPresented: $showAddItems) {
            NavigationStack {
                AddItemsView()
            }
            .environmentObject(session)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task {
            guard !session.isUITesting else { return }
            await session.refreshInventory()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Inventory")
                    .font(MekasaTheme.titleFont)
                    .foregroundStyle(MekasaTheme.brand)
                Text(InventoryListModel.summary(session.inventory))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(MekasaTheme.textMuted)
                    .accessibilityIdentifier(TestIdentifiers.inventorySummary)
            }
            Spacer()
            Button {
                showAddItems = true
            } label: {
                Label("Add", systemImage: "plus")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add items")
            .accessibilityIdentifier(TestIdentifiers.inventoryAddButton)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Search

    private var searchRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(MekasaTheme.textMuted)
            TextField("Search milk, snacks…", text: $query)
                .font(MekasaTheme.bodyFont)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier(TestIdentifiers.inventorySearchField)
            if hasQuery {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(MekasaTheme.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .accessibilityIdentifier(TestIdentifiers.inventorySearchClear)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1)
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 8, trailing: 20))
    }

    // MARK: - Rows

    private func row(_ item: InventoryItem) -> some View {
        NavigationLink(value: item.id) {
            HStack(spacing: 14) {
                ProductThumbnail(urlString: item.imageURL, size: 56, cornerRadius: 16)
                    .accessibilityIdentifier(TestIdentifiers.itemThumbnail)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(MekasaTheme.brand)
                        .accessibilityIdentifier(TestIdentifiers.itemTitle)
                    Text("Qty \(item.quantity) · \(item.category)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(MekasaTheme.textMuted)
                        .accessibilityIdentifier(TestIdentifiers.itemSubtitle)
                    // REQ-021 AC2: say what it contains and who it affects.
                    AffectedMembersCaption(warnings: session.memberWarnings(for: item.health))
                }
                Spacer()
                // REQ-021: affected-member chip + grade badge.
                AffectedMembersChip(warnings: session.memberWarnings(for: item.health))
                if let health = item.health, health.hasGrade {
                    HealthGradeBadge(grade: health.grade, size: 24)
                }
                if item.quantity == 0 {
                    stockChip("Out")
                } else if item.isLowStock {
                    stockChip("Low")
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(MekasaTheme.surface)
        .accessibilityIdentifier(TestIdentifiers.itemCell)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if item.quantity > 1 {
                Button {
                    session.consumeInventoryItem(id: item.id)
                } label: {
                    Label("Use 1", systemImage: "minus.circle.fill")
                }
                .tint(MekasaTheme.accent)
                .accessibilityIdentifier(TestIdentifiers.inventoryUseOneAction)
            } else {
                Button(role: .destructive) {
                    session.softRemoveInventoryItem(id: item.id)
                } label: {
                    Label("Remove", systemImage: "trash.fill")
                }
                .tint(MekasaTheme.accent)
                .accessibilityIdentifier(TestIdentifiers.inventoryRemoveAction)
            }
        }
    }

    private func stockChip(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(MekasaTheme.accent)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Nothing in inventory yet. Scan a barcode or add your first item.")
                .font(MekasaTheme.bodyFont)
                .foregroundStyle(MekasaTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(TestIdentifiers.emptyStateView)
            PrimaryButton(title: "Add items") {
                showAddItems = true
            }
            .accessibilityIdentifier(TestIdentifiers.inventoryEmptyAddButton)
            Spacer()
        }
        .padding(24)
    }

    // MARK: - Undo toast

    private var undoToast: some View {
        HStack {
            Text("Item removed")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(MekasaTheme.surface)
            Spacer()
            Button("Undo") {
                session.undoInventoryRemove()
            }
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(MekasaTheme.accent)
            .accessibilityIdentifier(TestIdentifiers.inventoryUndoButton)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(MekasaTheme.brand)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        // Clear the floating BottomNavBar (64 pt + 24 pt inset + FAB overhang)
        // so the Undo button is actually tappable within the 5 s window.
        .padding(.bottom, 120)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TestIdentifiers.inventoryUndoToast)
    }
}

#Preview("Grouped") {
    NavigationStack {
        InventoryListView()
            .environmentObject({
                let s = AppSession()
                s.isUIPreview = true
                s.inventory = TestFixtures.standardItemList
                return s
            }())
    }
}

#Preview("Empty") {
    NavigationStack {
        InventoryListView()
            .environmentObject({
                let s = AppSession()
                s.isUIPreview = true
                s.inventory = []
                return s
            }())
    }
}
