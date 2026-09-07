import SwiftUI

/// Free-form initial inventory scan placeholder (barcode/receipt later).
/// Satisfies: UI-003 AC1 (scan step), PRD onboarding step 5
/// Spec version: 1.0
struct InitialScanView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                OnboardingHeader(step: .initialScan)
                    .padding(.top, 48)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Add what's already home.")
                            .font(MekasaTheme.displayFont)
                            .foregroundStyle(MekasaTheme.brand)
                            .padding(.top, 36)

                        Text("Barcode and receipt scanning land next. For now, skip ahead or mark that you'll scan later.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)

                        VStack(spacing: 12) {
                            scanTile(icon: "barcode.viewfinder", title: "Scan barcodes", subtitle: "Coming soon")
                            scanTile(icon: "doc.text.viewfinder", title: "Scan a receipt", subtitle: "Coming soon")
                            scanTile(icon: "keyboard", title: "Add manually", subtitle: "Coming soon")
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 140)
                }

                StickyBottomBar(progress: 5.0 / 6.0) {
                    PrimaryButton(title: "I'm done for now") {
                        withAnimation { session.onboardingStep = .invite }
                    }
                }
            }
        }
    }

    private func scanTile(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(MekasaTheme.brandMuted.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
            }
            Spacer()
        }
        .padding(16)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1)
        )
        .foregroundStyle(MekasaTheme.brand)
    }
}

#Preview {
    InitialScanView().environmentObject(AppSession())
}
