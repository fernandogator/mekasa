import PhotosUI
import SwiftUI

/// Store brand printed on the receipt, used in the capture guidance copy
/// ("We could not find the H-E-B Bananas…"). REQ-RCP-020 AC1.
struct ReceiptStoreContext: Equatable {
    let storeName: String?
}

/// Copy for receipt lines Open Food Facts could not identify. Pure for unit tests.
/// Spec version: 1.0
enum CaptureGuidance {
    static func message(itemName: String, storeName: String?) -> String {
        let name = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let store = storeName?.trimmingCharacters(in: .whitespacesAndNewlines), !store.isEmpty {
            return "We could not find the \(store) \(name). Please scan the item and take a picture."
        }
        return "We could not find \(name) in the catalog. Please scan the item and take a picture."
    }

    /// Digits only; PLU stickers on produce are 4–5 digits, GTINs up to 14.
    static func sanitizeCode(_ raw: String) -> String {
        String(raw.filter { $0.isASCII && $0.isNumber }.prefix(ManualBarcodeEntry.maxLength))
    }

    static func isValidCode(_ code: String) -> Bool {
        code.count >= 4 && code == sanitizeCode(code)
    }
}

// MARK: - Replace any item picture

/// "Take photo / Choose from library" for any item picture. Returns the picked image.
struct ItemPhotoReplacement: ViewModifier {
    @Binding var isPresented: Bool
    var onViewFullSize: (() -> Void)?
    let onImage: (UIImage) -> Void

    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var cameraImage: UIImage?
    @State private var libraryItem: PhotosPickerItem?

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Item photo", isPresented: $isPresented, titleVisibility: .visible) {
                if let onViewFullSize {
                    Button("View full size", action: onViewFullSize)
                }
                if CameraImagePicker.isCameraAvailable {
                    Button("Take photo") { showCamera = true }
                }
                Button("Choose from library") { showLibrary = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Replace this picture with your own.")
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraImagePicker(image: $cameraImage)
                    .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showLibrary, selection: $libraryItem, matching: .images)
            .onChange(of: cameraImage) { _, image in
                guard let image else { return }
                cameraImage = nil
                onImage(image)
            }
            .onChange(of: libraryItem) { _, item in
                guard let item else { return }
                libraryItem = nil
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        onImage(image)
                    }
                }
            }
    }
}

extension View {
    func itemPhotoReplacement(
        isPresented: Binding<Bool>,
        onViewFullSize: (() -> Void)? = nil,
        onImage: @escaping (UIImage) -> Void
    ) -> some View {
        modifier(ItemPhotoReplacement(isPresented: isPresented, onViewFullSize: onViewFullSize, onImage: onImage))
    }
}

/// Product thumbnail that offers "replace with my photo" on tap. The tap is a
/// high-priority gesture so it wins over an enclosing row link / button.
struct EditableProductThumbnail: View {
    let urlString: String?
    var size: CGFloat = 56
    var cornerRadius: CGFloat = 16
    var itemName: String = "item"
    let onImage: (UIImage) async -> Void

    @State private var showOptions = false
    @State private var isUploading = false

    var body: some View {
        ProductThumbnail(urlString: urlString, size: size, cornerRadius: cornerRadius)
            .overlay {
                if isUploading {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(MekasaTheme.scrim.opacity(0.35))
                        .overlay { ProgressView().tint(MekasaTheme.onBrand) }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "camera.fill")
                    .font(.system(size: max(9, size * 0.16), weight: .bold))
                    .foregroundStyle(MekasaTheme.onBrand)
                    .padding(4)
                    .background(MekasaTheme.brand.opacity(0.85))
                    .clipShape(Circle())
                    .padding(3)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .highPriorityGesture(TapGesture().onEnded { showOptions = true })
            .accessibilityElement()
            .accessibilityLabel("Photo of \(itemName)")
            .accessibilityHint("Double tap to replace it with your own photo")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { showOptions = true }
            .itemPhotoReplacement(isPresented: $showOptions) { image in
                Task {
                    isUploading = true
                    await onImage(image)
                    isUploading = false
                }
            }
    }
}

// MARK: - In-store capture for unidentified receipt lines

/// Scan the item's barcode (or type its PLU) and take a picture of it.
/// Satisfies: REQ-004, REQ-005
/// Spec version: 1.0
struct LocalItemCaptureView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    let itemName: String
    let store: ReceiptStoreContext?
    let onCaptured: (LocalItemCaptureResult) -> Void

    @State private var code = ""
    @State private var typedCode = ""
    @State private var cameraError: String?
    @State private var photo: UIImage?
    @State private var showCamera = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        !isSaving && (CaptureGuidance.isValidCode(code) || photo != nil)
    }

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(title: "Scan item", onBack: { dismiss() })

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(CaptureGuidance.message(itemName: itemName, storeName: store?.storeName))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(MekasaTheme.brand)
                            .accessibilityIdentifier(TestIdentifiers.captureGuidanceLabel)

                        barcodeStep
                        photoStep

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.accent)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 140)
                }

                StickyBottomBar(progress: nil) {
                    PrimaryButton(title: isSaving ? "Saving…" : "Save", disabled: !canSave) {
                        Task { await save() }
                    }
                    .accessibilityIdentifier(TestIdentifiers.captureSaveButton)
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker(image: $photo)
                .ignoresSafeArea()
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    photo = UIImage(data: data)
                }
                libraryItem = nil
            }
        }
    }

    private var barcodeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepTitle("1. Scan the barcode")
            if CaptureGuidance.isValidCode(code) {
                HStack {
                    Label("Code \(code)", systemImage: "barcode")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(MekasaTheme.brand)
                        .accessibilityIdentifier(TestIdentifiers.captureCodeLabel)
                    Spacer()
                    Button("Rescan") {
                        code = ""
                        typedCode = ""
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
                }
            } else {
                if BarcodeCameraView.isSupported, cameraError == nil, !session.isUITesting {
                    BarcodeCameraView(
                        onCode: { value in
                            let clean = CaptureGuidance.sanitizeCode(value)
                            guard CaptureGuidance.isValidCode(clean) else { return }
                            ScanFeedback.accepted()
                            code = clean
                        },
                        onError: { cameraError = $0 }
                    )
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                HStack(spacing: 10) {
                    TextField("Or type the barcode / PLU (e.g. 4011)", text: $typedCode)
                        .keyboardType(.numberPad)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(MekasaTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .onChange(of: typedCode) { _, raw in
                            let clean = CaptureGuidance.sanitizeCode(raw)
                            if clean != raw { typedCode = clean }
                        }
                        .accessibilityIdentifier(TestIdentifiers.captureCodeField)
                    Button("Use") { code = typedCode }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            CaptureGuidance.isValidCode(typedCode) ? MekasaTheme.brand : MekasaTheme.textMuted
                        )
                        .disabled(!CaptureGuidance.isValidCode(typedCode))
                }
                Text("No barcode? Produce stickers have a 4–5 digit PLU — or just take a picture.")
                    .font(MekasaTheme.bodyFont)
                    .foregroundStyle(MekasaTheme.textMuted)
            }
        }
    }

    private var photoStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepTitle("2. Take a picture")
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .accessibilityIdentifier(TestIdentifiers.capturePhotoPreview)
            }
            HStack(spacing: 12) {
                if CameraImagePicker.isCameraAvailable {
                    SecondaryButton(title: photo == nil ? "Take picture" : "Retake") {
                        showCamera = true
                    }
                }
                PhotosPicker(selection: $libraryItem, matching: .images) {
                    Text(photo == nil ? "From library" : "Choose another")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(MekasaTheme.brand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(MekasaTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .accessibilityIdentifier(TestIdentifiers.captureLibraryButton)
            }
        }
    }

    private func stepTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(MekasaTheme.textMuted)
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let result = await session.captureUnidentifiedItem(
            barcode: CaptureGuidance.isValidCode(code) ? code : nil,
            image: photo
        )
        guard let result else {
            errorMessage = session.lastError ?? "Couldn’t save the scan."
            return
        }
        onCaptured(result)
        dismiss()
    }
}
