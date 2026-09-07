import SwiftUI

/// Manual inventory entry form (REQ-006).
/// Spec version: 1.0
struct ManualEntryView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category = InventoryCategory.pantry
    @State private var quantity = 1
    @State private var priceText = ""
    @State private var didSave = false

    private var pricePaid: Double? {
        let trimmed = priceText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && quantity > 0
    }

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(title: "Type it in", onBack: { dismiss() })

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Name, category, quantity — optional price.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)

                        MekasaTextField(
                            label: "Item name",
                            placeholder: "e.g. Avocados",
                            text: $name,
                            autocapitalization: .words
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .tracking(1)
                                .textCase(.uppercase)
                                .foregroundStyle(MekasaTheme.textMuted)
                                .padding(.leading, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(InventoryCategory.allCases) { cat in
                                        categoryChip(cat)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }

                        quantityStepper

                        MekasaTextField(
                            label: "Price paid (optional)",
                            placeholder: "0.00",
                            text: $priceText,
                            keyboard: .decimalPad,
                            autocapitalization: .never
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 140)
                }

                StickyBottomBar(progress: nil) {
                    PrimaryButton(title: "Add to inventory", disabled: !canSave) {
                        save()
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Added", isPresented: $didSave) {
            Button("Add another") {
                name = ""
                quantity = 1
                priceText = ""
                didSave = false
            }
            Button("Done", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Saved to this household’s inventory on this device.")
        }
    }

    private var quantityStepper: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quantity")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(MekasaTheme.textMuted)
                .padding(.leading, 16)

            HStack {
                Button {
                    quantity = max(1, quantity - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(MekasaTheme.surfaceElevated)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(MekasaTheme.brandMuted.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Decrease quantity")

                Text("\(quantity)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(MekasaTheme.brand)
                    .frame(maxWidth: .infinity)

                Button {
                    quantity += 1
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(MekasaTheme.surfaceElevated)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(MekasaTheme.brandMuted.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Increase quantity")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(MekasaTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1)
            )
            .foregroundStyle(MekasaTheme.brand)
        }
    }

    private func categoryChip(_ cat: InventoryCategory) -> some View {
        let selected = category == cat
        return Button {
            category = cat
        } label: {
            Text(cat.rawValue)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(selected ? Color.white : MekasaTheme.brand)
                .background(selected ? MekasaTheme.brand : MekasaTheme.surfaceElevated)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(MekasaTheme.brandMuted.opacity(selected ? 0 : 0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let item = InventoryItem(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category.rawValue,
            quantity: quantity,
            pricePaid: pricePaid,
            source: .manual
        )
        session.addInventoryItem(item)
        didSave = true
    }
}

#Preview {
    NavigationStack {
        ManualEntryView()
    }
    .environmentObject(AppSession())
}
