import SwiftUI

/// Trash station: scan barcode to decrement inventory (REQ-008 / UI-005).
/// Spec version: 1.0
/// Design: design/mockups/TrashStationMode.jsx
struct TrashStationView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var toast: String?
    @State private var isBusy = false
    @State private var cameraError: String?

    private var cameraAvailable: Bool { BarcodeCameraView.isSupported }

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(title: "Trash station", onBack: { dismiss() })
                    .accessibilityIdentifier(TestIdentifiers.cancelButton)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Scan a barcode when you toss it. Quantity drops by 1 immediately.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)
                            .accessibilityIdentifier(TestIdentifiers.scanPromptLabel)

                        cameraPane
                            .accessibilityIdentifier(TestIdentifiers.scanButton)

                        if let cameraError {
                            Text(cameraError)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.accent)
                        }

                        if session.inventory.isEmpty {
                            emptyState
                                .accessibilityIdentifier(TestIdentifiers.emptyStateView)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(session.inventory.filter { $0.quantity > 0 }) { item in
                                    Button {
                                        Task { await consume(itemID: item.id, fallbackName: item.name) }
                                    } label: {
                                        trashRow(item)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isBusy)
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
                                ForEach(session.trashEvents.prefix(8)) { event in
                                    Text("\(event.itemName) (\(event.quantityDelta))")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(MekasaTheme.textMuted)
                                }
                            }
                            .accessibilityIdentifier(TestIdentifiers.trashEventList)
                        }

                        if !cameraAvailable {
                            SecondaryButton(title: "Simulate known dispose") {
                                Task { await simulateKnown() }
                            }
                            SecondaryButton(title: "Simulate unknown barcode") {
                                Task { await handleBarcode("000000000000") }
                            }
                        }
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

    @ViewBuilder
    private var cameraPane: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.85))
                .frame(height: 220)
            if cameraAvailable {
                BarcodeCameraView(
                    onCode: { code in
                        Task { await handleBarcode(code) }
                    },
                    onError: { message in
                        cameraError = message
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .frame(height: 220)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Camera unavailable — use simulate buttons")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            if isBusy {
                ProgressView()
                    .tint(.white)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing to mark gone yet")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.brand)
            Text("Add items from Type it in or a barcode scan, then come back here.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(MekasaTheme.textMuted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
    }

    private func handleBarcode(_ code: String) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        let result = await session.consumeInventoryByBarcode(code)
        apply(result, barcode: code)
    }

    private func consume(itemID: String, fallbackName: String) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        let result = session.consumeInventoryItem(id: itemID)
        apply(result, barcode: fallbackName)
    }

    private func simulateKnown() async {
        if let first = session.inventory.first(where: { $0.quantity > 0 && ($0.barcode?.isEmpty == false) }) {
            await handleBarcode(first.barcode!)
        } else if let first = session.inventory.first(where: { $0.quantity > 0 }) {
            await consume(itemID: first.id, fallbackName: first.name)
        } else {
            showToast("No known items — scan logged as unknown")
            _ = await session.consumeInventoryByBarcode("000000000000")
        }
    }

    private func apply(_ result: AppSession.ConsumeResult, barcode: String) {
        switch result {
        case let .decremented(name, qty):
            session.trashEvents.insert(
                TrashEvent(
                    id: UUID().uuidString,
                    itemName: name,
                    quantityDelta: -1,
                    scannedAt: ISO8601DateFormatter().string(from: Date())
                ),
                at: 0
            )
            showToast("\(name) → \(qty) left")
        case let .depleted(name):
            session.trashEvents.insert(
                TrashEvent(
                    id: UUID().uuidString,
                    itemName: name,
                    quantityDelta: -1,
                    scannedAt: ISO8601DateFormatter().string(from: Date())
                ),
                at: 0
            )
            showToast("\(name) marked gone")
        case .unknown:
            showToast("Unknown barcode logged — no negative qty")
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
        s.addInventoryItem(
            InventoryItem(name: "Eggs", category: "Dairy", quantity: 2, barcode: "041220576037", source: .manual)
        )
        return s
    }())
}
