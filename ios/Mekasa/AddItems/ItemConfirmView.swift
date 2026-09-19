import SwiftUI

/// Confirm one or more draft items before saving to local inventory.
/// Spec version: 1.0
struct ItemConfirmView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State var drafts: [InventoryItem]
    var title: String = "Confirm items"
    var onFinished: (() -> Void)?

    @State private var saved = false
    @State private var matchingDraftID: String?

    private var unidentifiedCount: Int {
        drafts.filter { !$0.isIdentified }.count
    }

    private var identifiedCount: Int {
        drafts.count - unidentifiedCount
    }

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(title: title, onBack: { dismiss() })

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Review before anything saves.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)

                        if drafts.count > 1 || unidentifiedCount > 0 {
                            recognitionSummary
                        }

                        ForEach($drafts) { $draft in
                            draftCard($draft)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 140)
                    .accessibilityIdentifier(TestIdentifiers.itemDetailView)
                }

                StickyBottomBar(progress: nil) {
                    PrimaryButton(
                        title: drafts.count == 1 ? "Add to inventory" : "Add \(drafts.count) items",
                        disabled: drafts.isEmpty
                    ) {
                        for draft in drafts {
                            session.addInventoryItem(draft)
                        }
                        saved = true
                    }
                    .accessibilityIdentifier(TestIdentifiers.saveButton)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(item: $matchingDraftID) { draftID in
            ProductMatchPickerView(
                initialQuery: drafts.first(where: { $0.id == draftID })?.name ?? ""
            ) { hit in
                applyMatch(hit, to: draftID)
            }
        }
        .alert("Saved", isPresented: $saved) {
            Button("Done") {
                onFinished?()
                dismiss()
            }
        } message: {
            Text(session.canSyncInventory
                  ? "Saved to your household inventory."
                  : "Saved on this device (sign in to sync).")
        }
    }

    private var recognitionSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(identifiedCount) recognized · \(unidentifiedCount) need review")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(MekasaTheme.brand)
            if unidentifiedCount > 0 {
                Text(
                    session.canSyncInventory
                        ? "Tap Find in catalog on unmatched lines to pick the right product."
                        : "Unidentified lines keep the receipt name and a category image — edit before saving."
                )
                .font(MekasaTheme.bodyFont)
                .foregroundStyle(MekasaTheme.textMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier(TestIdentifiers.emptyStateView)
    }

    private func draftCard(_ draft: Binding<InventoryItem>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                ProductThumbnail(urlString: draft.wrappedValue.imageURL, size: 64, cornerRadius: 16)
                    .accessibilityIdentifier(TestIdentifiers.itemImage)
                VStack(alignment: .leading, spacing: 6) {
                    if !draft.wrappedValue.isIdentified {
                        Text("Not identified")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(MekasaTheme.accent)
                            .accessibilityIdentifier(TestIdentifiers.scanPromptLabel)
                    }
                    TextField("Name", text: draft.name)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(MekasaTheme.brand)
                        .accessibilityIdentifier(TestIdentifiers.itemNameLabel)
                    Text(draft.wrappedValue.category)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(MekasaTheme.textMuted)
                    if let barcode = draft.wrappedValue.barcode, !barcode.isEmpty {
                        Text("UPC \(barcode)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(MekasaTheme.textMuted)
                            .accessibilityIdentifier(TestIdentifiers.itemBarcodeLabel)
                    }
                }
                Spacer(minLength: 0)
                if drafts.count > 1 {
                    Button {
                        drafts.removeAll { $0.id == draft.wrappedValue.id }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(MekasaTheme.textMuted)
                            .frame(width: 28, height: 28)
                            .background(Color(red: 0xf1 / 255, green: 0xf4 / 255, blue: 0xf3 / 255))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove item")
                }
            }

            if !draft.wrappedValue.isIdentified, session.canSyncInventory {
                Button {
                    matchingDraftID = draft.wrappedValue.id
                } label: {
                    Text("Find in catalog")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(MekasaTheme.brand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 0xf1 / 255, green: 0xf4 / 255, blue: 0xf3 / 255))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(TestIdentifiers.scanButton)
            } else if draft.wrappedValue.isIdentified, session.canSyncInventory {
                Button {
                    matchingDraftID = draft.wrappedValue.id
                } label: {
                    Text("Change match")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(MekasaTheme.textMuted)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text("Qty")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
                Spacer()
                Button {
                    draft.wrappedValue.quantity = max(1, draft.wrappedValue.quantity - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(Color(red: 0xf1 / 255, green: 0xf4 / 255, blue: 0xf3 / 255))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text("\(draft.wrappedValue.quantity)")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .frame(minWidth: 28)

                Button {
                    draft.wrappedValue.quantity += 1
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(Color(red: 0xf1 / 255, green: 0xf4 / 255, blue: 0xf3 / 255))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(MekasaTheme.brand)
            .accessibilityIdentifier(TestIdentifiers.quantityControl)

            HStack {
                Text("Price")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
                Spacer()
                TextField(
                    "0.00",
                    text: Binding(
                        get: {
                            draft.wrappedValue.pricePaid.map { String(format: "%.2f", $0) } ?? ""
                        },
                        set: { raw in
                            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty {
                                draft.wrappedValue.pricePaid = nil
                            } else if let value = Double(trimmed) {
                                draft.wrappedValue.pricePaid = value
                            }
                        }
                    )
                )
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(MekasaTheme.brand)
                .frame(maxWidth: 120)
                .accessibilityIdentifier(TestIdentifiers.locationField)
            }
        }
        .padding(20)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    draft.wrappedValue.isIdentified
                        ? MekasaTheme.brandMuted.opacity(0.3)
                        : MekasaTheme.accent.opacity(0.55),
                    lineWidth: 1
                )
        )
    }

    private func applyMatch(_ hit: ProductSearchHitDTO, to draftID: String) {
        guard let idx = drafts.firstIndex(where: { $0.id == draftID }) else { return }
        drafts[idx].name = hit.name
        drafts[idx].category = hit.category
        drafts[idx].barcode = hit.barcode
        drafts[idx].imageURL = hit.imageUrl
        drafts[idx].isIdentified = true
        matchingDraftID = nil
    }
}

struct AddFlowHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MekasaTheme.brand)
                    .frame(width: 40, height: 40)
                    .background(MekasaTheme.surfaceElevated)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer()

            Text(title)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.brand)

            Spacer()

            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}
