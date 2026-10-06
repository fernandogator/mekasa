import SwiftUI

/// Copy for photo-only captures and for adding a code later. Pure for unit tests.
/// Satisfies: REQ-RCP-020 AC15
/// Spec version: 1.0
enum PhotoOnlyCapture {
    static let sharedPhotoLabel = "Shared photo"
    static let savedCardNote = "No barcode · matched by receipt text next time"
    static let addCodeTitle = "Add barcode or PLU"
    static let addCodeHint = "Adding the code lets Mekasa look up nutrition info for this item."

    static func noCodeMessage(storeName: String?) -> String {
        let store = storeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let receipts = store.isEmpty ? "these receipts" : "\(store) receipts"
        return "No barcode scanned — the photo and name are shared for \(receipts)"
    }

    /// `invalid_upc` / `invalid_plu` from the capture API, in plain words.
    static func errorMessage(for error: Error) -> String {
        let detail = (error as? APIError)?.errorDescription ?? ""
        if detail.contains("invalid_upc") { return "That barcode isn’t valid. Barcodes have 8–14 digits." }
        if detail.contains("invalid_plu") { return "That PLU isn’t valid. Produce PLUs have 4 or 5 digits." }
        return "Couldn’t save the code. Try again."
    }
}

/// Scan or type a barcode / PLU for a saved item that has none (REQ-RCP-020 AC15).
struct AddItemCodeView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    let itemID: String
    let itemName: String

    @State private var typedCode = ""
    @State private var cameraError: String?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var code: CatalogCaptureCode? {
        CatalogCaptureCode(typedCode)
    }

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(title: PhotoOnlyCapture.addCodeTitle, onBack: { dismiss() })

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(itemName)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(MekasaTheme.text)
                        Text(PhotoOnlyCapture.addCodeHint)
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)

                        if BarcodeCameraView.isSupported, cameraError == nil, !session.isUITesting {
                            BarcodeCameraView(
                                onCode: { value in
                                    let clean = CaptureGuidance.sanitizeCode(value)
                                    guard CatalogCaptureCode(clean) != nil else { return }
                                    ScanFeedback.accepted()
                                    typedCode = clean
                                },
                                onError: { cameraError = $0 }
                            )
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }

                        TextField("Barcode or PLU (e.g. 4011)", text: $typedCode)
                            .keyboardType(.numberPad)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(MekasaTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .onChange(of: typedCode) { _, raw in
                                let clean = CaptureGuidance.sanitizeCode(raw)
                                if clean != raw { typedCode = clean }
                                errorMessage = nil
                            }
                            .accessibilityIdentifier(TestIdentifiers.addItemCodeField)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.danger)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 140)
                }

                StickyBottomBar(progress: nil) {
                    PrimaryButton(title: isSaving ? "Saving…" : "Save", disabled: code == nil || isSaving) {
                        Task { await save() }
                    }
                    .accessibilityIdentifier(TestIdentifiers.addItemCodeSaveButton)
                }
            }
        }
        .navigationBarHidden(true)
    }

    private func save() async {
        guard let code else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        if let message = await session.addCodeToInventoryItem(itemID: itemID, code: code) {
            errorMessage = message
        } else {
            dismiss()
        }
    }
}
