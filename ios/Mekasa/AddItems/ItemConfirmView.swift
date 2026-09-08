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

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(title: title, onBack: { dismiss() })

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Review before anything saves.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)
                            .padding(.bottom, 4)

                        ForEach($drafts) { $draft in
                            draftCard($draft)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 140)
                }

                StickyBottomBar(progress: nil) {
                    PrimaryButton(title: drafts.count == 1 ? "Add to inventory" : "Add \(drafts.count) items") {
                        for draft in drafts {
                            session.addInventoryItem(draft)
                        }
                        saved = true
                    }
                }
            }
        }
        .navigationBarHidden(true)
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

    private func draftCard(_ draft: Binding<InventoryItem>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Name", text: draft.name)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.brand)

            Text(draft.wrappedValue.category)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(MekasaTheme.textMuted)

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
        }
        .padding(20)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1)
        )
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
