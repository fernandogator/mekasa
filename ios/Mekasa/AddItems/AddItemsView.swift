import SwiftUI

/// Add-items hub: barcode, receipt, voice, manual, trash station.
/// Satisfies: UI-004 Add path · REQ-004–REQ-008 entry points
/// Spec version: 1.0
/// Design: design/mockups/AddItems.jsx
struct AddItemsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(MekasaTheme.brand)
                            .frame(width: 40, height: 40)
                            .background(MekasaTheme.surfaceElevated)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier(TestIdentifiers.cancelButton)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add to the house")
                                .font(MekasaTheme.displayFont)
                                .foregroundStyle(MekasaTheme.brand)
                            Text("Each path lets you confirm before anything saves.")
                                .font(MekasaTheme.bodyFont)
                                .foregroundStyle(MekasaTheme.textMuted)
                        }
                        .padding(.bottom, 8)

                        NavigationLink {
                            BarcodeScanView()
                        } label: {
                            pathRow(
                                icon: "barcode.viewfinder",
                                title: "Scan barcode",
                                subtitle: "Fastest for packaged pantry items",
                                accent: false
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(TestIdentifiers.scanButton)

                        NavigationLink {
                            ReceiptScanView()
                        } label: {
                            pathRow(
                                icon: "doc.text.viewfinder",
                                title: "Scan receipt",
                                subtitle: "Add full grocery hauls instantly",
                                accent: false
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            VoiceAddView()
                        } label: {
                            pathRow(
                                icon: "mic.fill",
                                title: "Say it out loud",
                                subtitle: "Hands-free when cooking or unpacking",
                                accent: false
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ManualEntryView()
                        } label: {
                            pathRow(
                                icon: "keyboard",
                                title: "Type it in",
                                subtitle: "Manual entry for produce or loose items",
                                accent: false
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(TestIdentifiers.addItemButton)

                        NavigationLink {
                            TrashStationView()
                        } label: {
                            pathRow(
                                icon: "trash",
                                title: "Trash station",
                                subtitle: "Mark things gone to restock them later",
                                accent: true
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(TestIdentifiers.trashStationView)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TestIdentifiers.addItemsHub)
    }

    private func pathRow(
        icon: String,
        title: String,
        subtitle: String,
        accent: Bool
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(accent ? MekasaTheme.accent : MekasaTheme.brand)
                .frame(width: 56, height: 56)
                .background(
                    accent
                        ? Color(red: 0xfc / 255, green: 0xe5 / 255, blue: 0xe7 / 255)
                        : Color(red: 0xf1 / 255, green: 0xf4 / 255, blue: 0xf3 / 255)
                )
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(accent ? MekasaTheme.accent : MekasaTheme.brand)
                Text(subtitle)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MekasaTheme.brandMuted)
        }
        .padding(20)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

#Preview {
    NavigationStack {
        AddItemsView()
    }
    .environmentObject(AppSession())
}
