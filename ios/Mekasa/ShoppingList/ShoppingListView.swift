import SwiftUI

/// Shared shopping list: check off, approve requests, add custom.
/// Satisfies: REQ-011–REQ-014 (client staging)
/// Spec version: 1.0
/// Design: design/mockups/ShoppingList.jsx
struct ShoppingListView: View {
    @EnvironmentObject private var session: AppSession
    @State private var showAddCustom = false
    @State private var customName = ""
    @State private var customQty = 1
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                purchaseLockNotice
                listCard
                addCustomButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 56)
            .padding(.bottom, 140)
        }
        .accessibilityIdentifier(TestIdentifiers.shoppingListView)
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
        .animation(.easeInOut(duration: 0.2), value: session.shoppingList)
        .onAppear {
            session.ensureShoppingListSeeded()
        }
        .task {
            guard !session.isUITesting else { return }
            if session.canSyncShoppingList {
                await session.refreshShoppingList(syncLowStock: true)
            }
        }
        .sheet(isPresented: $showAddCustom) {
            addCustomSheet
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(listTitle)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(MekasaTheme.brand)
                HStack(spacing: 8) {
                    Label(householdTitle, systemImage: "house.fill")
                        .labelStyle(.titleAndIcon)
                    Text("·")
                    Text(ShoppingListSections.toBuySummary(session.shoppingList))
                        .accessibilityIdentifier(TestIdentifiers.shoppingToBuySummary)
                    Text("·")
                    HStack(spacing: 6) {
                        Circle()
                            .fill(MekasaTheme.success)
                            .frame(width: 8, height: 8)
                        Text(session.isRealtimeSyncActive
                              ? "live"
                              : (session.canSyncShoppingList ? "synced" : "on this device"))
                    }
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(MekasaTheme.textMuted)
            }
            Spacer()
            Button {
                showToast("List options come next")
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(MekasaTheme.brand)
                    .frame(width: 40, height: 40)
                    .background(MekasaTheme.surfaceElevated)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1))
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("List options")
        }
    }

    private var grouped: ShoppingListSections.Grouped {
        ShoppingListSections.group(session.shoppingList)
    }

    @ViewBuilder
    private var purchaseLockNotice: some View {
        if !session.canMarkShoppingPurchased {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(ShoppingListSections.purchaseLockNotice)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(MekasaTheme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(TestIdentifiers.purchaseLockNotice)
        }
    }

    private var listCard: some View {
        Group {
            if session.shoppingList.isEmpty {
                Text("Nothing to buy yet. Mark inventory low or add a custom item.")
                    .font(MekasaTheme.bodyFont)
                    .foregroundStyle(MekasaTheme.textMuted)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MekasaTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .accessibilityIdentifier(TestIdentifiers.emptyStateView)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    section("Needs approval", items: grouped.pending)
                    section("To buy", items: grouped.toBuy)
                    section("Purchased", items: grouped.purchased)
                }
                .padding(8)
                .background(MekasaTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(MekasaTheme.brandMuted.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 24, y: 12)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(TestIdentifiers.itemList)
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, items: [ShoppingListItem]) -> some View {
        if !items.isEmpty {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(MekasaTheme.textMuted)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 2)
                .accessibilityIdentifier(TestIdentifiers.shoppingSectionHeader)
            ForEach(items) { item in
                row(item)
            }
        }
    }

    private func removeButton(_ item: ShoppingListItem) -> some View {
        Button {
            session.removeShoppingItem(id: item.id)
            showToast("Removed \(item.name)")
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MekasaTheme.textMuted)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(item.name)")
        .accessibilityIdentifier(TestIdentifiers.shoppingRemoveButton)
    }

    private func chip(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(MekasaTheme.success)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay(Capsule().stroke(MekasaTheme.success.opacity(0.5), lineWidth: 1))
            .accessibilityIdentifier(TestIdentifiers.shoppingAutoChip)
    }

    @ViewBuilder
    private func row(_ item: ShoppingListItem) -> some View {
        if item.needsApproval {
            pendingRow(item)
        } else {
            standardRow(item)
        }
    }

    private func standardRow(_ item: ShoppingListItem) -> some View {
        let canPurchase = session.canMarkShoppingPurchased
        // The remove control sits beside (not inside) the toggle button so the two
        // taps never compete.
        let origin = item.kind == .auto ? ", auto-added" : ""
        return HStack(spacing: 0) {
            if canPurchase {
                Button {
                    session.toggleShoppingItemChecked(id: item.id)
                } label: {
                    shoppingRowLabel(item, showCheckbox: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.name)\(origin), \(item.isChecked ? "purchased" : "not purchased")")
                .accessibilityIdentifier(TestIdentifiers.itemCell)
            } else {
                shoppingRowLabel(item, showCheckbox: true)
                    .accessibilityLabel("\(item.name)\(origin), view only")
                    .accessibilityIdentifier(TestIdentifiers.itemCell)
            }
            removeButton(item)
        }
        .padding(.trailing, 4)
    }

    private func shoppingRowLabel(_ item: ShoppingListItem, showCheckbox: Bool) -> some View {
        HStack(spacing: 16) {
            checkbox(checked: item.isChecked)
                .opacity(session.canMarkShoppingPurchased ? 1 : 0.45)
                .accessibilityIdentifier(TestIdentifiers.itemThumbnail)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .strikethrough(item.isChecked)
                    .foregroundStyle(MekasaTheme.brand)
                    .accessibilityIdentifier(TestIdentifiers.itemTitle)
                HStack(spacing: 8) {
                    if !item.displayQuantity.isEmpty {
                        Text(item.displayQuantity)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(MekasaTheme.textMuted)
                            .accessibilityIdentifier(TestIdentifiers.itemSubtitle)
                    }
                    // Rows added by low-stock sync are marked so a shopper knows why they're here.
                    if let label = ShoppingListSections.chipLabel(for: item) {
                        chip(label)
                    }
                }
            }
            .opacity(item.isChecked ? 0.5 : 1)
            Spacer()
            // REQ-021 AC2: the linked inventory product contains something a member avoids.
            AffectedMembersChip(warnings: shoppingWarnings(for: item))
        }
        .padding(12)
        .contentShape(Rectangle())
    }

    /// Warnings for the inventory product behind a list row (by id, else by name).
    private func shoppingWarnings(for item: ShoppingListItem) -> [MemberWarning] {
        let linked = session.inventory.first(where: { $0.id == item.inventoryItemID })
            ?? session.inventory.first(where: { $0.name.caseInsensitiveCompare(item.name) == .orderedSame })
        return session.memberWarnings(for: linked?.health)
    }

    private func pendingRow(_ item: ShoppingListItem) -> some View {
        HStack(spacing: 16) {
            Text(initials(item.requestedBy ?? "?"))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(MekasaTheme.brand)
                .frame(width: 40, height: 40)
                .background(Color(red: 0xf1 / 255, green: 0xf4 / 255, blue: 0xf3 / 255))
                .clipShape(Circle())
                .overlay(Circle().stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(MekasaTheme.brand)
                        .accessibilityIdentifier(TestIdentifiers.requestedItemLabel)
                    Text("Needs approval")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 0xc4 / 255, green: 0x5c / 255, blue: 0x12 / 255))
                        .clipShape(Capsule())
                }
                Text("\(item.displayQuantity) • Requested by \(item.requestedBy ?? "member")")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0xc4 / 255, green: 0x5c / 255, blue: 0x12 / 255))
                    .accessibilityIdentifier(TestIdentifiers.requestorLabel)
            }

            Spacer(minLength: 0)

            if session.isHouseholdOwner {
                Button {
                    session.rejectShoppingRequest(id: item.id)
                    showToast("Denied \(item.name)")
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(MekasaTheme.brand)
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(MekasaTheme.brandMuted.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Deny \(item.name)")
                .accessibilityIdentifier(TestIdentifiers.rejectButton)

                Button {
                    session.approveShoppingRequest(id: item.id)
                    showToast("Approved \(item.name)")
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(MekasaTheme.brand)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Approve \(item.name)")
                .accessibilityIdentifier(TestIdentifiers.approveButton)
            } else {
                removeButton(item)
            }
        }
        .padding(12)
        .background(Color(red: 1, green: 0xf5 / 255, blue: 0xf0 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityIdentifier(TestIdentifiers.requestCell)
    }

    private func checkbox(checked: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(checked ? MekasaTheme.accent : MekasaTheme.brandMuted, lineWidth: 2)
                .background(Circle().fill(checked ? MekasaTheme.accent : Color.clear))
            if checked {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 40, height: 40)
    }

    private var addCustomButton: some View {
        Button {
            customName = ""
            customQty = 1
            showAddCustom = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18, weight: .semibold))
                Text("Add custom item")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundStyle(MekasaTheme.brand)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .foregroundStyle(MekasaTheme.brandMuted)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add custom item")
        .accessibilityIdentifier(TestIdentifiers.addItemButton)
    }

    private var addCustomSheet: some View {
        NavigationStack {
            MekasaScreen {
                VStack(spacing: 20) {
                    MekasaTextField(
                        label: "Item",
                        placeholder: "e.g. Tortillas",
                        text: $customName,
                        autocapitalization: .words
                    )
                    HStack {
                        Text("Quantity")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(MekasaTheme.textMuted)
                        Spacer()
                        Stepper("\(customQty)", value: $customQty, in: 1 ... 99)
                            .labelsHidden()
                        Text("\(customQty)")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(MekasaTheme.brand)
                            .frame(minWidth: 28)
                    }
                    .padding(16)
                    .background(MekasaTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Spacer()
                    PrimaryButton(
                        title: session.isHouseholdOwner ? "Add to list" : "Request item",
                        disabled: customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        session.addCustomShoppingItem(
                            name: customName.trimmingCharacters(in: .whitespacesAndNewlines),
                            quantity: customQty
                        )
                        showAddCustom = false
                        showToast(session.isHouseholdOwner ? "Added to list" : "Requested")
                    }
                }
                .padding(24)
            }
            .navigationTitle("Custom item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { showAddCustom = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var listTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return "\(formatter.string(from: Date())) list"
    }

    private var householdTitle: String {
        if let name = session.household?.name, !name.isEmpty {
            return name
        }
        return "Your house"
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let chars = parts.prefix(2).compactMap(\.first)
        return chars.isEmpty ? String(name.prefix(2)).uppercased() : String(chars).uppercased()
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
    MekasaScreen {
        ShoppingListView()
            .environmentObject({
                let s = AppSession()
                s.household = PreviewFixtures.household(name: "The Rivas House")
                s.ensureShoppingListSeeded()
                return s
            }())
    }
}
