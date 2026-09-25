import SwiftUI

/// Full household inventory list with swipe Use 1 / Remove (REQ-INV-014–018).
/// Spec version: 1.0
struct InventoryListView: View {
    @EnvironmentObject private var session: AppSession

    private var sortedItems: [InventoryItem] {
        session.inventory.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        MekasaScreen {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    Text("Inventory")
                        .font(MekasaTheme.titleFont)
                        .foregroundStyle(MekasaTheme.brand)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    if sortedItems.isEmpty {
                        Text("Nothing in inventory yet. Use + to add items.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(24)
                            .accessibilityIdentifier(TestIdentifiers.emptyStateView)
                        Spacer()
                    } else {
                        List {
                            ForEach(sortedItems) { item in
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
                                        }
                                        Spacer()
                                        if item.isLowStock {
                                            Text("Low")
                                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                                .foregroundStyle(MekasaTheme.accent)
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
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .accessibilityIdentifier(TestIdentifiers.itemList)
                    }
                }

                if session.showInventoryUndoToast {
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
        .task {
            guard !session.isUITesting else { return }
            await session.refreshInventory()
        }
    }
}

#Preview {
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
