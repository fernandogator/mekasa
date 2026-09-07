import SwiftUI

/// Voice entry path. Speech recognition comes next; demo phrase confirm now.
/// Satisfies: REQ-007 AC3 (confirm before save)
/// Spec version: 1.0
struct VoiceAddView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var listening = false
    @State private var showConfirm = false
    @State private var draft = InventoryItem(
        name: "Two avocados",
        category: InventoryCategory.produce.rawValue,
        quantity: 2,
        source: .voice
    )

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(title: "Say it out loud", onBack: { dismiss() })

                VStack(spacing: 28) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(MekasaTheme.accent.opacity(listening ? 0.18 : 0.08))
                            .frame(width: 160, height: 160)
                            .scaleEffect(listening ? 1.08 : 1)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: listening)

                        Button {
                            listening.toggle()
                        } label: {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 96, height: 96)
                                .background(MekasaTheme.accent)
                                .clipShape(Circle())
                                .shadow(color: MekasaTheme.accent.opacity(0.35), radius: 16, y: 8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(listening ? "Stop listening" : "Start listening")
                    }

                    Text(listening ? "Listening… (demo)" : "Tap the mic, then use a sample phrase.")
                        .font(MekasaTheme.bodyFont)
                        .foregroundStyle(MekasaTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Spacer()

                    StickyBottomBar(progress: nil) {
                        PrimaryButton(title: "Use sample: “two avocados”") {
                            listening = false
                            draft = InventoryItem(
                                name: "Avocados",
                                category: InventoryCategory.produce.rawValue,
                                quantity: 2,
                                source: .voice
                            )
                            showConfirm = true
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showConfirm) {
            ItemConfirmView(drafts: [draft], title: "Confirm item")
        }
    }
}

#Preview {
    NavigationStack {
        VoiceAddView()
    }
    .environmentObject(AppSession())
}
