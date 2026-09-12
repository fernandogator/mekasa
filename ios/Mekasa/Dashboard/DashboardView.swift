import SwiftUI
import UIKit

/// Home dashboard: low stock, pending approvals, recent activity.
/// Satisfies: UI-004 AC1–AC2 (AC3 photo backdrop when photo_url exists)
/// Spec version: 1.0
struct DashboardView: View {
    @EnvironmentObject private var session: AppSession
    @State private var approvals = DashboardFixtures.approvals
    @State private var toast: String?
    @State private var selectedItemID: String?

    var body: some View {
        ZStack {
            householdBackdrop
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header
                    statsRow
                    lowStockSection
                    needsApprovalSection
                    recentActivitySection
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 140)
            }
        }
        .accessibilityIdentifier(TestIdentifiers.dashboardView)
        .navigationDestination(item: $selectedItemID) { itemID in
            ItemDetailView(itemID: itemID)
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
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: toast)
        .animation(.easeInOut(duration: 0.2), value: approvals)
    }

    @ViewBuilder
    private var householdBackdrop: some View {
        if let urlString = session.household?.photoURL {
            if urlString.hasPrefix("data:"),
               let b64 = urlString.split(separator: ",").last,
               let data = Data(base64Encoded: String(b64)),
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.18)
                    .ignoresSafeArea()
            } else if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if case let .success(image) = phase {
                        image.resizable().scaledToFill().opacity(0.18).ignoresSafeArea()
                    }
                }
            }
        }
    }

    private var lowStockItems: [InventoryItem] {
        session.inventory.filter(\.isLowStock)
    }

    private var lowStockSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Low stock")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.brand)
            if lowStockItems.isEmpty {
                Text("Nothing below threshold right now.")
                    .font(MekasaTheme.bodyFont)
                    .foregroundStyle(MekasaTheme.textMuted)
            } else {
                ForEach(lowStockItems) { item in
                    Button {
                        selectedItemID = item.id
                    } label: {
                        HStack(spacing: 14) {
                            ProductThumbnail(urlString: item.imageURL, size: 56, cornerRadius: 16)
                                .accessibilityIdentifier(TestIdentifiers.itemThumbnail)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(MekasaTheme.brand)
                                Text("Qty \(item.quantity) · threshold \(item.lowStockThreshold)")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(MekasaTheme.textMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(MekasaTheme.textMuted)
                        }
                        .padding(14)
                        .background(MekasaTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens item details")
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(MekasaTheme.labelFont)
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(MekasaTheme.textMuted)
                Text(householdTitle)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(MekasaTheme.brand)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
            Button {
                showToast("Notifications come next")
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(MekasaTheme.brand)
                        .frame(width: 40, height: 40)
                        .background(MekasaTheme.surfaceElevated)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1))
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                    Circle()
                        .fill(MekasaTheme.accent)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        .offset(x: -2, y: 2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Notifications")
        }
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            statCard(
                icon: "exclamationmark.circle",
                iconBg: Color(red: 0xfc / 255, green: 0xe5 / 255, blue: 0xe7 / 255),
                label: "Low Stock",
                value: "\(session.lowStockCount) items"
            )
            statCard(
                icon: "creditcard",
                iconBg: Color(red: 0xea / 255, green: 0xf1 / 255, blue: 0xec / 255),
                label: "Spend",
                value: "$\(DashboardFixtures.weeklySpend)",
                suffix: "/wk"
            )
        }
    }

    private func statCard(
        icon: String,
        iconBg: Color,
        label: String,
        value: String,
        suffix: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MekasaTheme.brand)
                    .frame(width: 32, height: 32)
                    .background(iconBg)
                    .clipShape(Circle())
                Text(label)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(MekasaTheme.brand)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(MekasaTheme.textMuted)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private var needsApprovalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Needs Approval")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(MekasaTheme.brand)
                Spacer()
                Button("View All") {
                    showToast("Full approval inbox comes next")
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(MekasaTheme.textMuted)
            }

            if approvals.isEmpty {
                Text("You're all caught up.")
                    .font(MekasaTheme.bodyFont)
                    .foregroundStyle(MekasaTheme.textMuted)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MekasaTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .accessibilityIdentifier(TestIdentifiers.emptyStateView)
            } else {
                VStack(spacing: 4) {
                    ForEach(approvals) { request in
                        approvalRow(request)
                    }
                }
                .padding(8)
                .background(MekasaTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(MekasaTheme.brandMuted.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 24, y: 12)
                .accessibilityIdentifier(TestIdentifiers.requestQueue)
            }
        }
    }

    private func approvalRow(_ request: ApprovalRequest) -> some View {
        HStack(spacing: 16) {
            Image(systemName: request.symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MekasaTheme.brand)
                .frame(width: 40, height: 40)
                .background(Color(red: 0xf1 / 255, green: 0xf4 / 255, blue: 0xf3 / 255))
                .clipShape(Circle())
                .accessibilityIdentifier(TestIdentifiers.itemThumbnail)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.itemName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.brand)
                    .accessibilityIdentifier(TestIdentifiers.requestedItemLabel)
                Text("Requested by \(request.requestedBy)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
                    .accessibilityIdentifier(TestIdentifiers.requestorLabel)
            }

            Spacer()

            Button {
                dismiss(request, approved: false)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MekasaTheme.brand)
                    .frame(width: 40, height: 40)
                    .overlay(Circle().stroke(MekasaTheme.brandMuted.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Deny \(request.itemName)")
            .accessibilityIdentifier(TestIdentifiers.rejectButton)

            Button {
                dismiss(request, approved: true)
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(MekasaTheme.brand)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Approve \(request.itemName)")
            .accessibilityIdentifier(TestIdentifiers.approveButton)
        }
        .padding(12)
        .accessibilityIdentifier(TestIdentifiers.requestCell)
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.brand)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(session.activity) { item in
                    HStack(alignment: .top, spacing: 16) {
                        Circle()
                            .fill(item.kind == .warning
                                  ? Color(red: 0xc4 / 255, green: 0x5c / 255, blue: 0x12 / 255)
                                  : MekasaTheme.success)
                            .frame(width: 8, height: 8)
                            .padding(.top, 8)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.brand)
                            Text(item.when)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .tracking(0.8)
                                .textCase(.uppercase)
                                .foregroundStyle(MekasaTheme.textMuted)
                        }
                    }
                }
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5 ..< 12: return "Good Morning"
        case 12 ..< 17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    private var householdTitle: String {
        if let name = session.household?.name, !name.isEmpty {
            return name
        }
        return "Your house"
    }

    private func dismiss(_ request: ApprovalRequest, approved: Bool) {
        approvals.removeAll { $0.id == request.id }
        showToast(approved ? "Approved \(request.itemName)" : "Denied \(request.itemName)")
    }

    private func showToast(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if toast == message { toast = nil }
        }
    }
}

#Preview {
    MekasaScreen {
        DashboardView()
            .environmentObject({
                let s = AppSession()
                s.household = PreviewFixtures.household(name: "The Rodriguez House")
                return s
            }())
    }
}
