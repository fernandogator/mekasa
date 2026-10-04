import SwiftUI
import UIKit

/// Mekasa design tokens from design/design-system.md (Rich & Grounded). Every role
/// resolves per appearance (light / dark) and follows the system setting.
/// Satisfies: UI-002 AC3; NFR-005 AC2, AC5 — screens use only these roles, never literal
/// colors, and every text/fill pair here is contrast-checked in design/design-system.md.
enum MekasaTheme {
    /// Dark fills: tab bar, selected rows and chips, photo washes. Not a text color — use `text`.
    static let brand = dynamic(0x5d5652, dark: 0x3a3531)
    /// Decorative sage for washes, wells and disabled fills; fails 3:1, so never text, icons or outlines.
    static let brandMuted = dynamic(0x8fa085, dark: 0x5a6f4f)
    static let surface = dynamic(0xede8e0, dark: 0x1c1a18)
    static let surfaceElevated = dynamic(0xfaf7f3, dark: 0x272421)
    /// Primary text, and the onboarding progress fill.
    static let text = dynamic(0x5d5652, dark: 0xede8e0)
    static let textMuted = dynamic(0x5c6b54, dark: 0xa9b79f)
    /// Primary buttons, the Add button, selections, links and toggles.
    static let accent = dynamic(0x5a6f4f, dark: 0x8fa085)
    /// Errors, destructive actions, allergen and health warnings.
    static let danger = dynamic(0xa44a3f, dark: 0xe39286)
    static let success = dynamic(0x5a6f4f, dark: 0xa3b598)
    static let warning = dynamic(0x8b5c32, dark: 0xe2b07e)
    static let accentTint = dynamic(0xdce8d3, dark: 0x2c3628)
    static let dangerTint = dynamic(0xf6e3e0, dark: 0x3a2220)
    static let successTint = dynamic(0xdce8d3, dark: 0x2c3628)
    static let warningTint = dynamic(0xf3e6d8, dark: 0x3a2e22)
    /// Icons, input borders, chip outlines and unchecked controls (3:1 on surface).
    static let border = dynamic(0x76896b, dark: 0x7f8e76)
    /// Neutral fill for wells, image placeholders, steppers and unselected options.
    static let surfaceMuted = dynamic(0xece7df, dark: 0x312d29)
    static let progressTrack = dynamic(0xd9d3c9, dark: 0x3a3531)
    /// Text and icons on `brand` fills and over photos.
    static let onBrand = dynamic(0xffffff, dark: 0xede8e0)
    /// Text and icons on accent, success, warning and danger fills. Dark mode lightens
    /// those fills, so their labels turn charcoal there.
    static let onAccent = dynamic(0xffffff, dark: 0x1c1a18)
    /// Inactive icons and secondary text on `brand` fills.
    static let onBrandMuted = dynamic(0xc9d6c0, dark: 0xb5c2ab)
    /// Full-screen camera, scanner and photo viewer background.
    static let cameraSurface = dynamic(0x1a1918, dark: 0x0f0e0d)
    /// Text, icons and the reticle over `cameraSurface` or a live preview.
    static let onCamera = hex(0xfaf7f3)
    /// Darkening overlay on photos (busy spinners, overlaid text); always used with opacity.
    static let scrim = dynamic(0x1a1918, dark: 0x0f0e0d)
    static let shadow = Color.black

    /// Nutri-Score style A–D health grade colors; E uses `danger`.
    static let gradeA = Color(red: 0x1f / 255, green: 0x8a / 255, blue: 0x4c / 255)
    static let gradeB = Color(red: 0x6f / 255, green: 0xa8 / 255, blue: 0x2f / 255)
    static let gradeC = Color(red: 0xd9 / 255, green: 0xa4 / 255, blue: 0x06 / 255)
    static let gradeD = Color(red: 0xe0 / 255, green: 0x6c / 255, blue: 0x1a / 255)

    static let displayFont = Font.system(size: 32, weight: .black, design: .rounded)
    static let titleFont = Font.system(size: 28, weight: .black, design: .rounded)
    static let bodyFont = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let labelFont = Font.system(size: 10, weight: .bold, design: .rounded)

    private static func hex(_ rgb: UInt32) -> Color {
        Color(uiColor: uiColor(rgb))
    }

    private static func dynamic(_ light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            uiColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    private static func uiColor(_ rgb: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((rgb >> 16) & 0xff) / 255,
            green: CGFloat((rgb >> 8) & 0xff) / 255,
            blue: CGFloat(rgb & 0xff) / 255,
            alpha: 1
        )
    }
}

struct MekasaScreen<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MekasaTheme.surface.ignoresSafeArea()
            Circle()
                .fill(MekasaTheme.brandMuted.opacity(0.2))
                .frame(width: 300, height: 300)
                .blur(radius: 40)
                .offset(x: 80, y: -80)
                .allowsHitTesting(false)
            content
        }
    }
}

struct OnboardingHeader: View {
    let step: OnboardingStep

    var body: some View {
        VStack(spacing: 4) {
            if !step.progressLabel.isEmpty {
                Text(step.progressLabel)
                    .font(MekasaTheme.labelFont)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(MekasaTheme.textMuted)
            }
            Text("Mekasa")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(MekasaTheme.text)
                .tracking(-0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

struct PrimaryButton: View {
    let title: String
    var disabled = false
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .tint(MekasaTheme.onAccent)
                }
            }
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(MekasaTheme.onAccent)
            .background(disabled || isLoading ? MekasaTheme.brandMuted : MekasaTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: MekasaTheme.accent.opacity(disabled ? 0 : 0.22), radius: 12, y: 6)
        }
        .disabled(disabled || isLoading)
        .animation(.easeInOut(duration: 0.12), value: isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    var disabled = false
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .tint(MekasaTheme.text)
                }
            }
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(MekasaTheme.text)
            .background(MekasaTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(MekasaTheme.border, lineWidth: 1)
            )
        }
        .disabled(disabled || isLoading)
        .animation(.easeInOut(duration: 0.12), value: isLoading)
    }
}

struct MekasaTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil
    /// Applied to the inner text field (not the wrapper) so XCUITest `textFields[...]`
    /// queries resolve to the editable element.
    var fieldIdentifier: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(MekasaTheme.textMuted)
                    .padding(.leading, 16)
            }
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(autocapitalization)
                }
            }
            .accessibilityIdentifier(fieldIdentifier ?? "")
            .submitLabel(submitLabel)
            .onSubmit { onSubmit?() }
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(MekasaTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(MekasaTheme.border, lineWidth: 1)
            )
        }
    }
}

struct StickyBottomBar<Content: View>: View {
    let progress: Double?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 16) {
            content
            if let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(MekasaTheme.progressTrack)
                        Capsule()
                            .fill(MekasaTheme.text)
                            .frame(width: max(8, geo.size.width * progress))
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            LinearGradient(
                colors: [MekasaTheme.surface.opacity(0), MekasaTheme.surface, MekasaTheme.surface],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Household photo helpers (dashboard hero + HomePhotoView)

/// Renders a household `photo_url` (remote HTTPS or `data:` URL).
enum HouseholdPhotoImage {
    static func uiImage(from urlString: String?) -> UIImage? {
        guard let urlString, !urlString.isEmpty else { return nil }
        if urlString.hasPrefix("data:"),
           let b64 = urlString.split(separator: ",").last,
           let data = Data(base64Encoded: String(b64)) {
            return UIImage(data: data)
        }
        return nil
    }
}

struct HouseholdPhotoView: View {
    let urlString: String?
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let local = HouseholdPhotoImage.uiImage(from: urlString) {
                Image(uiImage: local)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if let urlString, let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().aspectRatio(contentMode: contentMode)
                    case .failure:
                        placeholder
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(MekasaTheme.brandMuted.opacity(0.35))
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    MekasaTheme.brandMuted.opacity(0.55),
                    MekasaTheme.brand.opacity(0.85),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "house.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(MekasaTheme.onBrand.opacity(0.85))
        }
    }
}

/// Camera capture via `UIImagePickerController` (library uses PhotosUI elsewhere).
struct CameraImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraImagePicker

        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
    }
}
