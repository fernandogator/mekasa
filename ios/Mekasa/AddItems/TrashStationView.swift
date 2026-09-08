import SwiftUI

/// Trash station: decrement local inventory (REQ-008 client stub).
/// Spec version: 1.0
/// Design: design/mockups/TrashStationMode.jsx
struct TrashStationView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var toast: String?

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(title: "Trash station", onBack: { dismiss() })
                    .accessibilityIdentifier(TestIdentifiers.cancelButton)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Tap an item when you toss it. Quantity drops by 1 on this device.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)
                            .accessibilityIdentifier(TestIdentifiers.scanPromptLabel)

                        if session.inventory.isEmpty {
                            emptyState
                                .accessibilityIdentifier(TestIdentifiers.emptyStateView)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(session.inventory) { item in
                                    Button {
                                        consume(item)
                                    } label: {
                                        trashRow(item)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(item.quantity <= 0)
                                    .accessibilityIdentifier(TestIdentifiers.itemCell)
                                }
                            }
                            .accessibilityIdentifier(TestIdentifiers.itemList)
                        }

                        if let last = session.trashEvents.first {
                            Text(last.itemName)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(MekasaTheme.brand)
                                .accessibilityIdentifier(TestIdentifiers.lastScannedItem)
                        }

                        if !session.trashEvents.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(session.trashEvents) { event in
                                    Text("\(event.itemName) (\(event.quantityDelta))")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(MekasaTheme.textMuted)
                                }
                            }
                            .accessibilityIdentifier(TestIdentifiers.trashEventList)
                        }

                        SecondaryButton(title: "Simulate barcode dispose") {
                            simulateScan()
                        }
                        .padding(.top, 8)
                        .accessibilityIdentifier(TestIdentifiers.scanButton)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .overlay(alignment: .top) {
                if let toast {
                    Text(toast)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(MekasaTheme.brand)
                        .clipShape(Capsule())
                        .padding(.top, 64)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(session.isUITesting ? nil : .easeInOut(duration: 0.25), value: toast)
        }
        .accessibilityIdentifier(TestIdentifiers.trashStationView)
        .navigationBarHidden(true)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing to mark gone yet")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.brand)
            Text("Add items from Type it in or a demo scan, then come back here.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(MekasaTheme.textMuted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1)
        )
    }

    private func trashRow(_ item: InventoryItem) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "trash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MekasaTheme.accent)
                .frame(width: 44, height: 44)
                .background(Color(red: 0xfc / 255, green: 0xe5 / 255, blue: 0xe7 / 255))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.brand)
                Text("\(item.category) · qty \(item.quantity)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
            }
            Spacer()
            Text("−1")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.accent)
        }
        .padding(16)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1)
        )
        .accessibilityLabel("Dispose \(item.name)")
    }

    private func consume(_ item: InventoryItem) {
        let result = session.consumeInventoryItem(id: item.id)
        switch result {
        case .decremented(let name, let qty):
            session.trashEvents.insert(
                TrashEvent(
                    id: "trash-\(item.id)-\(session.trashEvents.count)",
                    itemName: name,
                    quantityDelta: -1,
                    scannedAt: "2026-01-15T12:00:00Z"
                ),
                at: 0
            )
            showToast("\(name) → \(qty) left")
        case .depleted(let name):
            session.trashEvents.insert(
                TrashEvent(
                    id: "trash-\(item.id)-gone",
                    itemName: name,
                    quantityDelta: -1,
                    scannedAt: "2026-01-15T12:00:00Z"
                ),
                at: 0
            )
            showToast("\(name) marked gone")
        case .unknown:
            showToast("Item not found")
        }
    }

    private func simulateScan() {
        if let first = session.inventory.first(where: { $0.quantity > 0 }) {
            consume(first)
        } else {
            showToast("No known items — unknown scan logged")
            session.logActivity("Unknown trash scan (no match)", kind: .warning)
        }
    }

    private func showToast(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if toast == message { toast = nil }
        }
    }
}

#Preview {
    NavigationStack {
        TrashStationView()
    }
    .environmentObject({
        let s = AppSession()
        s.addInventoryItem(InventoryItem(name: "Eggs", category: "Dairy", quantity: 2, source: .manual))
        return s
    }())
}
