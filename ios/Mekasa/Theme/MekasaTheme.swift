import SwiftUI

/// Mekasa design tokens from design/design-system.md
enum MekasaTheme {
    static let brand = Color(red: 0x17 / 255, green: 0x1e / 255, blue: 0x19 / 255)
    static let brandMuted = Color(red: 0xb7 / 255, green: 0xc6 / 255, blue: 0xc2 / 255)
    static let surface = Color(red: 0xee / 255, green: 0xeb / 255, blue: 0xe3 / 255)
    static let surfaceElevated = Color.white
    static let text = brand
    static let textMuted = Color(red: 0x6d / 255, green: 0x7a / 255, blue: 0x76 / 255)
    static let accent = Color(red: 0xca / 255, green: 0x00 / 255, blue: 0x13 / 255)
    static let success = Color(red: 0x2f / 255, green: 0x6b / 255, blue: 0x4f / 255)

    static let displayFont = Font.system(size: 32, weight: .black, design: .rounded)
    static let titleFont = Font.system(size: 28, weight: .black, design: .rounded)
    static let bodyFont = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let labelFont = Font.system(size: 10, weight: .bold, design: .rounded)
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
                .foregroundStyle(MekasaTheme.brand)
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
                        .tint(.white)
                }
            }
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(MekasaTheme.brand)
                .background(MekasaTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(MekasaTheme.brandMuted.opacity(0.35), lineWidth: 1)
                )
        }
    }
}

struct MekasaTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

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
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(MekasaTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1)
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
                        Capsule().fill(Color(red: 0xd5 / 255, green: 0xdd / 255, blue: 0xd9 / 255))
                        Capsule()
                            .fill(MekasaTheme.brand)
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
