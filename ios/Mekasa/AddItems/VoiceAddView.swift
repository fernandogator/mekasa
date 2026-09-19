import SwiftUI

/// Voice entry: dictate (or sample), match catalog variants, confirm before save.
/// Satisfies: REQ-007 AC1–AC3
/// Spec version: 1.0
struct VoiceAddView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @StateObject private var speech = VoiceSpeechRecognizer()

    @State private var transcript = ""
    @State private var parsedQuantity = 1
    @State private var productQuery = ""
    @State private var searchResults: [ProductSearchHitDTO] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var didSearch = false
    @State private var confirmDraft: InventoryItem?
    @State private var showConfirm = false

    private var isListening: Bool {
        if case .listening = speech.status { return true }
        return false
    }

    private var statusMessage: String {
        switch speech.status {
        case .listening:
            let partial = speech.partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            return partial.isEmpty ? "Listening…" : partial
        case .requestingPermission:
            return "Checking microphone permission…"
        case .unavailable(let message):
            return message
        case .idle:
            if transcript.isEmpty {
                return speech.isAvailable
                    ? "Tap the mic and say an item, like “two avocados” or “Oreos”."
                    : "Speech isn’t available here — use a sample phrase below."
            }
            return "Heard: “\(transcript)”"
        }
    }

    private var canAddAsSpoken: Bool {
        !productQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(title: "Say it out loud", onBack: { dismiss() })

                ScrollView {
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(MekasaTheme.accent.opacity(isListening ? 0.18 : 0.08))
                                .frame(width: 160, height: 160)
                                .scaleEffect(isListening ? 1.08 : 1)
                                .animation(
                                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                    value: isListening
                                )

                            Button {
                                speech.toggleListening { text in
                                    applyTranscript(text)
                                }
                            } label: {
                                Image(systemName: isListening ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 36, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 96, height: 96)
                                    .background(MekasaTheme.accent)
                                    .clipShape(Circle())
                                    .shadow(color: MekasaTheme.accent.opacity(0.35), radius: 16, y: 8)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isListening ? "Stop listening" : "Start listening")
                            .accessibilityIdentifier(TestIdentifiers.scanButton)
                        }
                        .padding(.top, 12)

                        Text(statusMessage)
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)

                        if !transcript.isEmpty {
                            matchSection
                        }

                        samplePhrases
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 140)
                }

                StickyBottomBar(progress: nil) {
                    PrimaryButton(title: "Add as spoken", disabled: !canAddAsSpoken) {
                        confirmAsSpoken()
                    }
                    .accessibilityIdentifier(TestIdentifiers.saveButton)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showConfirm) {
            if let confirmDraft {
                ItemConfirmView(drafts: [confirmDraft], title: "Confirm item") {
                    dismiss()
                }
            }
        }
        .onDisappear {
            speech.stop()
        }
    }

    @ViewBuilder
    private var matchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if session.canSyncInventory {
                if isSearching {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Matching products…")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)
                    }
                }

                if let searchError {
                    Text(searchError)
                        .font(MekasaTheme.bodyFont)
                        .foregroundStyle(MekasaTheme.textMuted)
                }

                if didSearch && searchResults.isEmpty && !isSearching {
                    Text("No catalog matches. You can still add “\(productQuery)” as spoken.")
                        .font(MekasaTheme.bodyFont)
                        .foregroundStyle(MekasaTheme.textMuted)
                }

                if !searchResults.isEmpty {
                    Text("Pick a match")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(MekasaTheme.textMuted)
                        .textCase(.uppercase)

                    ForEach(searchResults) { hit in
                        Button {
                            selectHit(hit)
                        } label: {
                            ProductSearchHitRow(hit: hit)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(TestIdentifiers.itemCell)
                    }
                }
            } else {
                Text("Sign in to match spoken names against the product catalog.")
                    .font(MekasaTheme.bodyFont)
                    .foregroundStyle(MekasaTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var samplePhrases: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try a sample")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(MekasaTheme.textMuted)
                .textCase(.uppercase)

            sampleButton(title: "“two avocados”", phrase: "two avocados")
            sampleButton(title: "“Oreos”", phrase: "Oreos")
            sampleButton(title: "“three packs of oat milk”", phrase: "three packs of oat milk")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sampleButton(title: String, phrase: String) -> some View {
        Button {
            speech.stop()
            applyTranscript(phrase)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .foregroundStyle(MekasaTheme.brand)
                .background(MekasaTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func applyTranscript(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        transcript = trimmed
        if let parsed = VoicePhraseParser.parse(trimmed) {
            parsedQuantity = parsed.quantity
            productQuery = parsed.productQuery
        } else {
            parsedQuantity = 1
            productQuery = trimmed
        }
        searchResults = []
        didSearch = false
        searchError = nil
        Task { await findProducts() }
    }

    private func findProducts() async {
        guard session.canSyncInventory,
              let token = session.idToken,
              productQuery.count >= 2 else { return }
        isSearching = true
        searchError = nil
        defer { isSearching = false }
        do {
            let response = try await MekasaAPIClient.shared.searchProducts(
                query: productQuery,
                limit: 8,
                token: token
            )
            searchResults = response.results
            didSearch = true
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                session.handleAPIFailure(error)
            } else {
                searchError = "Couldn’t match products. You can still add as spoken."
            }
            searchResults = []
            didSearch = true
        }
    }

    private func selectHit(_ hit: ProductSearchHitDTO) {
        confirmDraft = hit.toDraft(quantity: parsedQuantity, source: .voice)
        showConfirm = true
    }

    private func confirmAsSpoken() {
        let name = productQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let display = name.prefix(1).uppercased() + name.dropFirst()
        confirmDraft = InventoryItem(
            name: String(display),
            category: InventoryCategory.other.rawValue,
            quantity: max(1, parsedQuantity),
            source: .voice,
            isIdentified: false
        )
        showConfirm = true
    }
}

#Preview {
    NavigationStack {
        VoiceAddView()
    }
    .environmentObject(AppSession())
}
