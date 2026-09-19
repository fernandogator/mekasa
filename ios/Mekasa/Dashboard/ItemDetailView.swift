import SwiftUI

/// Item detail: quantity + low-stock threshold (REQ-009).
/// Spec version: 1.0
struct ItemDetailView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    let itemID: String
    @State private var threshold: Int = 1
    @State private var quantity: Int = 1

    private var item: InventoryItem? {
        session.inventory.first(where: { $0.id == itemID })
    }

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(title: "Item detail", onBack: { dismiss() })

                if let item {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            Text(item.name)
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(MekasaTheme.brand)
                                .accessibilityIdentifier(TestIdentifiers.itemNameLabel)

                            Text(item.category)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.textMuted)

                            stepperCard(title: "Quantity", value: $quantity) {
                                quantity = max(0, quantity)
                                session.updateLowStockThreshold(itemID: item.id, threshold: threshold)
                                // Persist quantity via existing update API path.
                                Task { await persistQuantity(itemID: item.id, quantity: quantity) }
                            }

                            stepperCard(title: "Low-stock threshold", value: $threshold) {
                                threshold = max(0, threshold)
                                session.updateLowStockThreshold(itemID: item.id, threshold: threshold)
                            }

                            Text(
                                quantity <= threshold
                                    ? "This item is low stock and will appear on the shopping list."
                                    : "Raise or lower the threshold anytime. Default is 1."
                            )
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                        .accessibilityIdentifier(TestIdentifiers.itemDetailView)
                    }
                } else {
                    Text("Item not found")
                        .font(MekasaTheme.bodyFont)
                        .foregroundStyle(MekasaTheme.textMuted)
                        .padding(24)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if let item {
                threshold = item.lowStockThreshold
                quantity = item.quantity
            }
        }
    }

    private func stepperCard(title: String, value: Binding<Int>, onChange: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(MekasaTheme.textMuted)
            HStack {
                Button {
                    value.wrappedValue = max(0, value.wrappedValue - 1)
                    onChange()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(MekasaTheme.surfaceElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text("\(value.wrappedValue)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(MekasaTheme.brand)
                    .frame(maxWidth: .infinity)

                Button {
                    value.wrappedValue += 1
                    onChange()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(MekasaTheme.surfaceElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func persistQuantity(itemID: String, quantity: Int) async {
        guard session.canSyncInventory,
              let token = session.idToken,
              let householdID = session.household?.id
        else {
            if let idx = session.inventory.firstIndex(where: { $0.id == itemID }) {
                session.inventory[idx].quantity = quantity
            }
            return
        }
        do {
            let remote = try await MekasaAPIClient.shared.updateInventoryItem(
                householdID: householdID,
                itemID: itemID,
                quantity: quantity,
                token: token
            )
            if let idx = session.inventory.firstIndex(where: { $0.id == remote.id }) {
                session.inventory[idx] = remote.toLocal()
            }
            await session.refreshShoppingList(syncLowStock: true)
        } catch {
            session.handleAPIFailure(error)
        }
    }
}
