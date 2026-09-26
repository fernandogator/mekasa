import PhotosUI
import SwiftUI

/// Receipt scan path with backend OCR + confirm (REQ-005).
/// Spec version: 1.0
struct ReceiptScanView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var photoItem: PhotosPickerItem?
    @State private var isScanning = false
    @State private var pastedText = ""
    @State private var statusMessage = "Photograph a receipt, paste its text, or run the demo haul."
    @State private var showConfirm = false
    @State private var drafts: [InventoryItem] = []
    @State private var engineLabel: String?

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(title: "Scan receipt", onBack: { dismiss() })

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .fill(Color(red: 0xf1 / 255, green: 0xf4 / 255, blue: 0xf3 / 255))
                                .frame(height: 200)
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text.viewfinder")
                                    .font(.system(size: 40, weight: .semibold))
                                    .foregroundStyle(MekasaTheme.brand)
                                Text("Photograph your receipt")
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    .foregroundStyle(MekasaTheme.brand)
                            }
                        }

                        Text(statusMessage)
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)

                        if let engineLabel {
                            Text("Engine: \(engineLabel)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(MekasaTheme.textMuted)
                        }

                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text("Choose receipt photo")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(MekasaTheme.brand)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .disabled(isScanning)
                        .onChange(of: photoItem) { _, item in
                            guard let item else { return }
                            Task { await scanPhoto(item) }
                        }

                        pasteTextSection

                        SecondaryButton(title: isScanning ? "Scanning…" : "Use demo haul") {
                            Task { await scanDemo() }
                        }
                        .disabled(isScanning)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 140)
                }
            }
        }
        .accessibilityIdentifier(TestIdentifiers.receiptScanView)
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showConfirm) {
            ItemConfirmView(drafts: drafts, title: "Confirm haul")
        }
    }

    /// Paste text from an emailed / app receipt when there's no paper copy to photograph.
    private var pasteTextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Or paste receipt text")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(MekasaTheme.textMuted)
                .padding(.leading, 16)

            ZStack(alignment: .topLeading) {
                if pastedText.isEmpty {
                    Text("BANANAS 1.29\nWHOLE MILK 3.49")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MekasaTheme.textMuted.opacity(0.6))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $pastedText)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MekasaTheme.brand)
                    .scrollContentBackground(.hidden)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(minHeight: 120, maxHeight: 180)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .accessibilityIdentifier(TestIdentifiers.receiptPasteField)
            }
            .background(MekasaTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1)
            )

            let lines = ReceiptTextInput.lineCount(pastedText)
            if lines > 0 {
                Text("\(lines) line\(lines == 1 ? "" : "s") ready to parse")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
                    .padding(.leading, 16)
                    .accessibilityIdentifier(TestIdentifiers.receiptPasteLineCount)
            }

            PrimaryButton(
                title: isScanning ? "Scanning…" : "Parse pasted text",
                disabled: isScanning || !ReceiptTextInput.isSubmittable(pastedText)
            ) {
                Task { await scanPastedText() }
            }
            .accessibilityIdentifier(TestIdentifiers.receiptPasteButton)
        }
    }

    private func scanPastedText() async {
        let text = ReceiptTextInput.normalize(pastedText)
        guard ReceiptTextInput.isSubmittable(text) else { return }
        await runScan(imageBase64: nil, rawText: text)
        if showConfirm {
            pastedText = ""
        }
    }

    private func scanDemo() async {
        await runScan(imageBase64: nil, rawText: """
        BANANAS 1.29
        WHOLE MILK 3.49
        SOURDOUGH LOAF 4.99
        SUBTOTAL 9.77
        TOTAL 9.77
        """)
    }

    private func scanPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            statusMessage = "Couldn’t read that photo."
            return
        }
        await runScan(imageBase64: data.base64EncodedString(), rawText: nil)
    }

    private func runScan(imageBase64: String?, rawText: String?) async {
        isScanning = true
        defer { isScanning = false }

        if session.isUIPreview || session.isUITesting || session.idToken == nil || session.household?.id == nil {
            drafts = InventoryDemoCatalog.sampleReceiptLines.map { name, category, price in
                InventoryItem(
                    name: name,
                    category: category,
                    quantity: 1,
                    pricePaid: price,
                    source: .receipt,
                    imageURL: Self.placeholderURL(for: category),
                    isIdentified: name != "Sourdough Loaf"
                )
            }
            engineLabel = "demo"
            let unidentified = drafts.filter { !$0.isIdentified }.count
            statusMessage = unidentified == 0
                ? "Review the demo haul, then save."
                : "Review the demo haul — \(unidentified) item needs review."
            showConfirm = true
            return
        }

        guard let token = session.idToken, let householdID = session.household?.id else { return }
        do {
            let response = try await MekasaAPIClient.shared.scanReceipt(
                householdID: householdID,
                imageBase64: imageBase64,
                rawText: rawText,
                token: token
            )
            drafts = response.items.map { $0.toLocal() }
            engineLabel = response.engine
            let unidentified = drafts.filter { !$0.isIdentified }.count
            if drafts.isEmpty {
                statusMessage = "No line items found — try another photo or demo haul."
            } else if unidentified > 0 {
                statusMessage = "Found \(drafts.count) items — \(unidentified) not identified in the catalog."
            } else {
                statusMessage = "Review \(drafts.count) recognized items, then save."
            }
            showConfirm = !drafts.isEmpty
        } catch {
            session.handleAPIFailure(error)
            statusMessage = error.localizedDescription
        }
    }

    private static func placeholderURL(for category: String) -> String {
        let label = category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Item"
        return "https://placehold.co/400x400/eeebe3/171e19/png?text=\(label)"
    }
}

#Preview {
    NavigationStack {
        ReceiptScanView()
    }
    .environmentObject(AppSession())
}
