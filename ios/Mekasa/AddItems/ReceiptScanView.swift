import SwiftUI

/// Receipt scan path. OCR backend comes next; demo haul confirm now.
/// Satisfies: REQ-005 AC2 (review before save)
/// Spec version: 1.0
struct ReceiptScanView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirm = false
    @State private var sampleItems: [InventoryItem] = InventoryDemoCatalog.sampleReceiptLines.map { name, category, price in
        InventoryItem(
            name: name,
            category: category,
            quantity: 1,
            pricePaid: price,
            source: .receipt
        )
    }

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(title: "Scan receipt", onBack: { dismiss() })

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .fill(Color(red: 0xf1 / 255, green: 0xf4 / 255, blue: 0xf3 / 255))
                                .frame(height: 200)
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text.viewfinder")
                                    .font(.system(size: 40, weight: .semibold))
                                    .foregroundStyle(MekasaTheme.brand)
                                Text("Photograph your receipt")
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    .foregroundStyle(MekasaTheme.brand)
                            }
                        }

                        Text("Backend OCR isn’t live yet. Run a demo haul to practice the confirm step.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Demo haul")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .tracking(1)
                                .textCase(.uppercase)
                                .foregroundStyle(MekasaTheme.textMuted)
                            ForEach(sampleItems) { item in
                                HStack {
                                    Text(item.name)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                    Spacer()
                                    if let price = item.pricePaid {
                                        Text(String(format: "$%.2f", price))
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundStyle(MekasaTheme.textMuted)
                                    }
                                }
                                .foregroundStyle(MekasaTheme.brand)
                                .padding(.vertical, 6)
                            }
                        }
                        .padding(20)
                        .background(MekasaTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 140)
                }

                StickyBottomBar(progress: nil) {
                    PrimaryButton(title: "Review demo items") {
                        showConfirm = true
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showConfirm) {
            ItemConfirmView(drafts: sampleItems, title: "Confirm haul")
        }
    }
}

#Preview {
    NavigationStack {
        ReceiptScanView()
    }
    .environmentObject(AppSession())
}
