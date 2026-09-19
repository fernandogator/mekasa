import SwiftUI

/// Local spending snapshot from inventory `pricePaid` until dedicated spend API ships (REQ-015–018).
/// Spec version: 1.0
struct SpendingView: View {
    @EnvironmentObject private var session: AppSession

    private var pricedItems: [InventoryItem] {
        session.inventory
            .filter { ($0.pricePaid ?? 0) > 0 }
            .sorted { ($0.pricePaid ?? 0) > ($1.pricePaid ?? 0) }
    }

    private var totalSpend: Double {
        pricedItems.reduce(0) { $0 + ($1.pricePaid ?? 0) * Double(max($1.quantity, 1)) }
    }

    private var byCategory: [(String, Double)] {
        var map: [String: Double] = [:]
        for item in pricedItems {
            let amount = (item.pricePaid ?? 0) * Double(max(item.quantity, 1))
            map[item.category, default: 0] += amount
        }
        return map.sorted { $0.value > $1.value }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Spending")
                    .font(MekasaTheme.titleFont)
                    .foregroundStyle(MekasaTheme.brand)

                Text("Totals from prices you captured on receipts and manual adds. Full weekly reports land with the spend API.")
                    .font(MekasaTheme.bodyFont)
                    .foregroundStyle(MekasaTheme.textMuted)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tracked total")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(MekasaTheme.textMuted)
                    Text(String(format: "$%.2f", totalSpend))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(MekasaTheme.brand)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MekasaTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                if byCategory.isEmpty {
                    Text("No priced items yet. Scan a receipt or add a price when confirming items.")
                        .font(MekasaTheme.bodyFont)
                        .foregroundStyle(MekasaTheme.textMuted)
                        .accessibilityIdentifier(TestIdentifiers.emptyStateView)
                } else {
                    Text("By category")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(MekasaTheme.brand)
                    ForEach(byCategory, id: \.0) { category, amount in
                        HStack {
                            Text(category)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(MekasaTheme.brand)
                            Spacer()
                            Text(String(format: "$%.2f", amount))
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(MekasaTheme.brand)
                        }
                        .padding(14)
                        .background(MekasaTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 64)
            .padding(.bottom, 140)
        }
    }
}

#Preview {
    SpendingView().environmentObject({
        let s = AppSession()
        s.isUIPreview = true
        s.inventory = TestFixtures.standardItemList
        return s
    }())
}
