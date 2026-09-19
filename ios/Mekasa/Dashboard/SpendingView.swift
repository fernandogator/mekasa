import SwiftUI

/// Household spending from Cloud Run purchase events (REQ-015–018), with local inventory fallback.
/// Spec version: 1.0
struct SpendingView: View {
    @EnvironmentObject private var session: AppSession
    @State private var period: SpendingPeriod = .week

    private var report: SpendingReportDTO? { session.spendingReport }

    private var usingLiveReport: Bool {
        session.canSyncSpending && report != nil
    }

    private var totalSpend: Double {
        if let report { return report.total }
        return session.localTrackedSpend
    }

    private var byCategory: [(String, Double)] {
        if let report {
            return report.byCategory.map { ($0.category, $0.total) }
        }
        var map: [String: Double] = [:]
        for item in session.inventory where (item.pricePaid ?? 0) > 0 {
            let amount = (item.pricePaid ?? 0) * Double(max(item.quantity, 1))
            map[item.category, default: 0] += amount
        }
        return map.sorted { $0.value > $1.value }
    }

    private var periodLabel: String {
        switch period {
        case .week: return "This week"
        case .month: return "This month"
        case .year: return "This year"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Spending")
                    .font(MekasaTheme.titleFont)
                    .foregroundStyle(MekasaTheme.brand)

                Text(
                    usingLiveReport
                        ? "Purchase totals for \(periodLabel.lowercased()) from receipts and priced adds."
                        : "Totals from prices on this device. Sign in to load weekly household reports."
                )
                .font(MekasaTheme.bodyFont)
                .foregroundStyle(MekasaTheme.textMuted)

                if session.canSyncSpending {
                    Picker("Period", selection: $period) {
                        Text("Week").tag(SpendingPeriod.week)
                        Text("Month").tag(SpendingPeriod.month)
                        Text("Year").tag(SpendingPeriod.year)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: period) { _, newValue in
                        Task { await session.refreshSpending(period: newValue) }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(usingLiveReport ? periodLabel : "Tracked total")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(MekasaTheme.textMuted)
                    Text(String(format: "$%.2f", totalSpend))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(MekasaTheme.brand)
                    if let currency = report?.currency, usingLiveReport {
                        Text(currency)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(MekasaTheme.textMuted)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MekasaTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                if byCategory.isEmpty {
                    Text(
                        usingLiveReport
                            ? "No purchases in this period yet."
                            : "No priced items yet. Scan a receipt or add a price when confirming items."
                    )
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

                if usingLiveReport, let events = report?.events, !events.isEmpty {
                    Text("Recent purchases")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(MekasaTheme.brand)
                    ForEach(events.prefix(12)) { event in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.name)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(MekasaTheme.brand)
                                Text(event.category)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(MekasaTheme.textMuted)
                            }
                            Spacer()
                            Text(String(format: "$%.2f", event.lineTotal))
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
        .task {
            guard session.canSyncSpending else { return }
            await session.refreshSpending(period: period)
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
