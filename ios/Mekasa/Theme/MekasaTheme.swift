import SwiftUI
import UIKit

/// Mekasa design tokens from design/design-system.md.
/// Supports Grounded (default) and Halloween seasonal palettes; each resolves
/// light / dark from the system appearance.
/// Satisfies: UI-002 AC3; NFR-005 AC2, AC5 — screens use only these roles, never literal
/// colors, and every text/fill pair is contrast-checked in design/design-system.md.
enum MekasaTheme {
    /// Dark fills: tab bar, selected rows and chips, photo washes. Not a text color — use `text`.
    static var brand: Color { role(\.brand) }
    /// Decorative wash / wells; never text, icons or outlines when muted.
    static var brandMuted: Color { role(\.brandMuted) }
    static var surface: Color { role(\.surface) }
    static var surfaceElevated: Color { role(\.surfaceElevated) }
    /// Primary text, and the onboarding progress fill.
    static var text: Color { role(\.text) }
    static var textMuted: Color { role(\.textMuted) }
    /// Primary buttons, the Add button, selections, links and toggles.
    static var accent: Color { role(\.accent) }
    /// Errors, destructive actions, allergen and health warnings.
    static var danger: Color { role(\.danger) }
    static var success: Color { role(\.success) }
    static var warning: Color { role(\.warning) }
    static var accentTint: Color { role(\.accentTint) }
    static var dangerTint: Color { role(\.dangerTint) }
    static var successTint: Color { role(\.successTint) }
    static var warningTint: Color { role(\.warningTint) }
    /// Icons, input borders, chip outlines and unchecked controls (3:1 on surface).
    static var border: Color { role(\.border) }
    /// Neutral fill for wells, image placeholders, steppers and unselected options.
    static var surfaceMuted: Color { role(\.surfaceMuted) }
    static var progressTrack: Color { role(\.progressTrack) }
    /// Hairline dividers (3:1). Decorative washes use `brandMuted` instead.
    static var line: Color { role(\.line) }
    /// Text and icons on `brand` fills and over photos.
    static var onBrand: Color { role(\.onBrand) }
    /// Text and icons on accent, success, warning and danger fills.
    static var onAccent: Color { role(\.onAccent) }
    /// Inactive icons and secondary text on `brand` fills.
    static var onBrandMuted: Color { role(\.onBrandMuted) }
    /// Full-screen camera, scanner and photo viewer background.
    static var cameraSurface: Color { role(\.cameraSurface) }
    /// Text, icons and the reticle over `cameraSurface` or a live preview.
    static var onCamera: Color { role(\.onCamera) }
    /// Darkening overlay on photos (busy spinners, overlaid text); always used with opacity.
    static var scrim: Color { role(\.scrim) }
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

    private static func role(_ keyPath: KeyPath<AppearanceTokens, UInt32>) -> Color {
        Color(uiColor: UIColor { traits in
            // Read UserDefaults directly so this stays safe off the main actor.
            let style = MekasaPaletteStyle(
                rawValue: UserDefaults.standard.string(forKey: ThemePreferences.styleKey) ?? ""
            ) ?? .grounded
            let tokens = PaletteTokens.tokens(for: style)
            let rgb = traits.userInterfaceStyle == .dark
                ? tokens.dark[keyPath: keyPath]
                : tokens.light[keyPath: keyPath]
            return uiColor(rgb)
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

/// Raw RGB roles for one appearance (light or dark).
struct AppearanceTokens {
    var brand: UInt32
    var brandMuted: UInt32
    var surface: UInt32
    var surfaceElevated: UInt32
    var surfaceMuted: UInt32
    var text: UInt32
    var textMuted: UInt32
    var accent: UInt32
    var danger: UInt32
    var success: UInt32
    var warning: UInt32
    var accentTint: UInt32
    var dangerTint: UInt32
    var successTint: UInt32
    var warningTint: UInt32
    var border: UInt32
    var line: UInt32
    var progressTrack: UInt32
    var onBrand: UInt32
    var onAccent: UInt32
    var onBrandMuted: UInt32
    var cameraSurface: UInt32
    var onCamera: UInt32
    var scrim: UInt32
}

struct PaletteTokens {
    let light: AppearanceTokens
    let dark: AppearanceTokens

    static func tokens(for style: MekasaPaletteStyle) -> PaletteTokens {
        switch style {
        case .grounded: return .grounded
        case .halloween: return .halloween
        }
    }

    /// Rich & Grounded (default).
    static let grounded = PaletteTokens(
        light: AppearanceTokens(
            brand: 0x5d5652, brandMuted: 0x8fa085,
            surface: 0xede8e0, surfaceElevated: 0xfaf7f3, surfaceMuted: 0xece7df,
            text: 0x5d5652, textMuted: 0x5c6b54,
            accent: 0x5a6f4f, danger: 0xa44a3f, success: 0x5a6f4f, warning: 0x8b5c32,
            accentTint: 0xdce8d3, dangerTint: 0xf6e3e0, successTint: 0xdce8d3, warningTint: 0xf3e6d8,
            border: 0x76896b, line: 0x76896b, progressTrack: 0xd9d3c9,
            onBrand: 0xffffff, onAccent: 0xffffff, onBrandMuted: 0xc9d6c0,
            cameraSurface: 0x1a1918, onCamera: 0xfaf7f3, scrim: 0x1a1918
        ),
        dark: AppearanceTokens(
            brand: 0x3a3531, brandMuted: 0x5a6f4f,
            surface: 0x1c1a18, surfaceElevated: 0x272421, surfaceMuted: 0x312d29,
            text: 0xede8e0, textMuted: 0xa9b79f,
            accent: 0x8fa085, danger: 0xe39286, success: 0xa3b598, warning: 0xe2b07e,
            accentTint: 0x2c3628, dangerTint: 0x3a2220, successTint: 0x2c3628, warningTint: 0x3a2e22,
            border: 0x7f8e76, line: 0x7f8e76, progressTrack: 0x3a3531,
            onBrand: 0xede8e0, onAccent: 0x1c1a18, onBrandMuted: 0xb5c2ab,
            cameraSurface: 0x0f0e0d, onCamera: 0xfaf7f3, scrim: 0x0f0e0d
        )
    )

    /// Halloween seasonal — Superdesign 2026-10-15, AA-tuned (NFR-005 AC2).
    static let halloween = PaletteTokens(
        light: AppearanceTokens(
            brand: 0x8b4a0c, brandMuted: 0xd4a574,
            surface: 0xfff8f0, surfaceElevated: 0xfffbf7, surfaceMuted: 0xf5e8dc,
            text: 0x3d2817, textMuted: 0x5c4336,
            accent: 0x6b247a, danger: 0xa03224, success: 0x4a5e2c, warning: 0x7a5210,
            accentTint: 0xf3e6f6, dangerTint: 0xf8e5df, successTint: 0xe8edd9, warningTint: 0xf5e8c8,
            border: 0x6f5638, line: 0x6f5638, progressTrack: 0xe8ddd0,
            onBrand: 0xfffbf7, onAccent: 0xfffbf7, onBrandMuted: 0xe8d7c3,
            cameraSurface: 0x1a1513, onCamera: 0xfffbf7, scrim: 0x1a1513
        ),
        dark: AppearanceTokens(
            brand: 0xd4a01b, brandMuted: 0xb8860b,
            surface: 0x1a1513, surfaceElevated: 0x2d2620, surfaceMuted: 0x3d3630,
            text: 0xf5e8dc, textMuted: 0xc4b5a0,
            accent: 0x9fd356, danger: 0xe8745c, success: 0xa8b86f, warning: 0xe8c74f,
            accentTint: 0x2a3318, dangerTint: 0x3a221c, successTint: 0x2a3318, warningTint: 0x3a2e14,
            border: 0xa8894a, line: 0xa8894a, progressTrack: 0x3d3630,
            onBrand: 0x1a1513, onAccent: 0x1a1513, onBrandMuted: 0x5c4a2e,
            cameraSurface: 0x0f0e0d, onCamera: 0xf5e8dc, scrim: 0x0f0e0d
        )
    )
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
