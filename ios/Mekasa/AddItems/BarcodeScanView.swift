import SwiftUI

/// Barcode scan path. Camera + UPC API come next; demo + manual fallback now.
/// Satisfies: REQ-004 AC2 (manual fallback), AC3 (confirm qty)
/// Spec version: 1.0
struct BarcodeScanView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var confirmItems: [InventoryItem] = []
    @State private var showConfirm = false
    @State private var showManual = false
    @State private var unknownPrompt = false
    @State private var unknownCode = ""

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(title: "Scan barcode", onBack: { dismiss() })

                VStack(spacing: 24) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(MekasaTheme.brand.opacity(0.92))
                            .frame(height: 280)

                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [10, 8]))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .frame(width: 220, height: 120)

                        VStack(spacing: 12) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Point at a UPC")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                    Text("Live camera + product lookup ships with the barcode API. Use a demo scan or type it in.")
                        .font(MekasaTheme.bodyFont)
                        .foregroundStyle(MekasaTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer()

                    StickyBottomBar(progress: nil) {
                        VStack(spacing: 12) {
                            PrimaryButton(title: "Simulate known scan") {
                                if let item = InventoryDemoCatalog.lookup(barcode: InventoryDemoCatalog.sampleBarcode) {
                                    confirmItems = [item]
                                    showConfirm = true
                                }
                            }
                            SecondaryButton(title: "Simulate unknown barcode") {
                                unknownCode = "999999999999"
                                unknownPrompt = true
                            }
                            Button {
                                showManual = true
                            } label: {
                                Text("Enter manually")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(MekasaTheme.brand)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showConfirm) {
            ItemConfirmView(drafts: confirmItems, title: "Confirm item")
        }
        .navigationDestination(isPresented: $showManual) {
            ManualEntryView()
        }
        .alert("Unknown barcode", isPresented: $unknownPrompt) {
            Button("Enter manually") {
                showManual = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("No product for \(unknownCode). Add it by hand.")
        }
    }
}

#Preview {
    NavigationStack {
        BarcodeScanView()
    }
    .environmentObject(AppSession())
}
