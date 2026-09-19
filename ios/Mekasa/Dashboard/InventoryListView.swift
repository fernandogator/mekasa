import SwiftUI

/// Full household inventory list with navigation to item detail (REQ-006 / REQ-009).
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
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .accessibilityIdentifier(TestIdentifiers.itemList)
                }
            }
        }
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
