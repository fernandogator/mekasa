import SwiftUI

/// Barcode scan path: live camera + Open Food Facts lookup via API.
/// Satisfies: REQ-004 AC1–AC3
/// Spec version: 1.0
struct BarcodeScanView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var confirmItems: [InventoryItem] = []
    @State private var showConfirm = false
    @State private var showManual = false
    @State private var unknownPrompt = false
    @State private var unknownCode = ""
    @State private var isLookingUp = false
    @State private var statusMessage = "Point at a UPC"
    @State private var cameraAuthorized = false
    @State private var typedCode = ""
    @State private var cameraError: String?

    private var cameraAvailable: Bool { BarcodeCameraView.isSupported }

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(title: "Scan barcode", onBack: { dismiss() })

                ScrollView {
                    VStack(spacing: 20) {
                        cameraPane
                            .padding(.horizontal, 24)
                            .padding(.top, 12)

                        Text(statusMessage)
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        if let cameraError {
                            Text(cameraError)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.accent)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }

                        typedEntry
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 160)
                }

                StickyBottomBar(progress: nil) {
                    VStack(spacing: 12) {
                        if isLookingUp {
                            ProgressView("Looking up product…")
                                .tint(MekasaTheme.brand)
                        }
                        if !cameraAvailable {
                            PrimaryButton(title: "Simulate known scan") {
                                Task { await lookup(InventoryDemoCatalog.sampleBarcode) }
                            }
                            SecondaryButton(title: "Simulate unknown barcode") {
                                unknownCode = "999999999999"
                                unknownPrompt = true
                            }
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
        .navigationBarHidden(true)
        .task {
            cameraAuthorized = await BarcodeCameraPermission.requestIfNeeded()
            if !cameraAuthorized {
                cameraError = "Camera access is off. Enable it in Settings, or enter a code below."
            }
        }
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

    @ViewBuilder
    private var cameraPane: some View {
        ZStack {
            if cameraAvailable, cameraAuthorized {
                BarcodeCameraView(
                    onCode: { code in
                        Task { await lookup(code) }
                    },
                    onError: { message in
                        cameraError = message
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .frame(height: 320)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [10, 8]))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .frame(width: 220, height: 120)
                        .allowsHitTesting(false)
                )
            } else {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(MekasaTheme.brand.opacity(0.92))
                    .frame(height: 280)
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(cameraAvailable ? "Camera permission needed" : "Camera unavailable here")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(cameraAvailable
                                  ? "Allow camera access, or type a UPC below."
                                  : "Simulator has no barcode camera — use Lookup / Simulate.")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }
            }
        }
    }

    private var typedEntry: some View {
        VStack(alignment: .leading, spacing: 10) {
            MekasaTextField(
                label: "Or type a UPC",
                placeholder: "e.g. 3017624010701",
                text: $typedCode,
                keyboard: .numberPad,
                autocapitalization: .never
            )
            PrimaryButton(
                title: "Look up code",
                disabled: typedCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 6 || isLookingUp
            ) {
                Task { await lookup(typedCode) }
            }
        }
    }

    @MainActor
    private func lookup(_ raw: String) async {
        let code = raw.filter(\.isNumber)
        guard code.count >= 6, !isLookingUp else { return }
        isLookingUp = true
        statusMessage = "Looking up \(code)…"
        defer { isLookingUp = false }

        // Prefer live API when signed in; fall back to local demo catalog.
        if session.canSyncInventory, let token = session.idToken {
            do {
                let result = try await MekasaAPIClient.shared.lookupBarcode(code: code, token: token)
                if result.found, let name = result.name {
                    confirmItems = [
                        InventoryItem(
                            name: name,
                            category: result.category ?? InventoryCategory.other.rawValue,
                            quantity: result.quantity,
                            barcode: result.barcode,
                            source: .barcode
                        )
                    ]
                    statusMessage = "Found — confirm to add"
                    showConfirm = true
                    return
                }
                unknownCode = code
                unknownPrompt = true
                statusMessage = "No product for that code"
                return
            } catch {
                session.lastError = error.localizedDescription
                statusMessage = "Lookup failed — try again or enter manually"
                return
            }
        }

        if let item = InventoryDemoCatalog.lookup(barcode: code) {
            confirmItems = [item]
            statusMessage = "Found (demo catalog)"
            showConfirm = true
        } else {
            unknownCode = code
            unknownPrompt = true
            statusMessage = "Sign in for live UPC lookup, or enter manually"
        }
    }
}

#Preview {
    NavigationStack {
        BarcodeScanView()
    }
    .environmentObject(AppSession())
}
