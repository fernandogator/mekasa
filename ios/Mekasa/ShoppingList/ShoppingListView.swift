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
                listCard
                addCustomButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 56)
            .padding(.bottom, 140)
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
        .animation(.easeInOut(duration: 0.2), value: session.shoppingList)
        .onAppear {
            session.ensureShoppingListSeeded()
            session.syncShoppingListFromInventory()
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
                    HStack(spacing: 6) {
                        Circle()
                            .fill(MekasaTheme.success)
                            .frame(width: 8, height: 8)
                        Text("on this device")
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
            } else {
                VStack(spacing: 4) {
                    ForEach(session.shoppingList) { item in
                        row(item)
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
            }
        }
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
        Button {
            session.toggleShoppingItemChecked(id: item.id)
        } label: {
            HStack(spacing: 16) {
                checkbox(checked: item.isChecked)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .strikethrough(item.isChecked)
                        .foregroundStyle(MekasaTheme.brand)
                    if !item.displayQuantity.isEmpty {
                        Text(item.displayQuantity)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(MekasaTheme.textMuted)
                    }
                }
                .opacity(item.isChecked ? 0.5 : 1)
                Spacer()
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.name), \(item.isChecked ? "purchased" : "not purchased")")
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
            }

            Spacer(minLength: 0)

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
        }
        .padding(12)
        .background(Color(red: 1, green: 0xf5 / 255, blue: 0xf0 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                        title: "Add to list",
                        disabled: customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        session.addCustomShoppingItem(
                            name: customName.trimmingCharacters(in: .whitespacesAndNewlines),
                            quantity: customQty
                        )
                        showAddCustom = false
                        showToast("Added to list")
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
