import SwiftUI

/// "I'm allergic to / I avoid…" editor for one household member (REQ-021 AC1).
/// Catalog chips toggle on/off; free-text entries (e.g. "cilantro") are matched
/// against ingredient lists as typed.
struct AvoidEditorView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    let member: HouseholdMemberDTO
    var onSaved: (() -> Void)?

    @State private var selected: [String]
    @State private var custom = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(member: HouseholdMemberDTO, onSaved: (() -> Void)? = nil) {
        self.member = member
        self.onSaved = onSaved
        _selected = State(initialValue: member.avoid)
    }

    private var displayName: String { member.name ?? member.email ?? member.uid }

    private var customEntries: [String] {
        let catalogKeys = Set(session.avoidanceOptions.map(\.key))
        return selected.filter { !catalogKeys.contains($0) }
    }

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(title: "\(displayName) avoids", onBack: { dismiss() })

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Pick anything \(member.uid == session.userUID ? "you" : displayName) can't or won't eat. Scans and the inventory will flag products that contain it.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)

                        FlowChips(values: session.avoidanceOptions.map(\.key)) { key in
                            let option = session.avoidanceOptions.first(where: { $0.key == key })
                            let isOn = selected.contains(key)
                            Button {
                                toggle(key)
                            } label: {
                                Text(option?.label ?? key)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(isOn ? .white : MekasaTheme.brand)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(isOn ? MekasaTheme.accent : MekasaTheme.surfaceElevated)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(
                                            isOn ? MekasaTheme.accent : MekasaTheme.brandMuted.opacity(0.5),
                                            lineWidth: 1
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                            .accessibilityIdentifier("AvoidChip_\(key)")
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Something else")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .textCase(.uppercase)
                                .tracking(0.6)
                                .foregroundStyle(MekasaTheme.textMuted)
                            HStack(spacing: 10) {
                                MekasaTextField(
                                    label: "",
                                    placeholder: "e.g. cilantro, red 40",
                                    text: $custom,
                                    autocapitalization: .never
                                )
                                .accessibilityIdentifier(TestIdentifiers.avoidCustomField)
                                Button {
                                    addCustom()
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .bold))
                                        .frame(width: 44, height: 44)
                                        .background(MekasaTheme.surfaceElevated)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .disabled(custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .accessibilityLabel("Add custom avoidance")
                            }
                            if !customEntries.isEmpty {
                                FlowChips(values: customEntries) { entry in
                                    Button {
                                        toggle(entry)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(entry.capitalized)
                                            Image(systemName: "xmark")
                                                .font(.system(size: 10, weight: .bold))
                                        }
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                        .background(MekasaTheme.brand)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

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
                    PrimaryButton(
                        title: selected.isEmpty ? "Save (nothing avoided)" : "Save \(selected.count) item\(selected.count == 1 ? "" : "s")",
                        isLoading: isSaving
                    ) {
                        Task { await save() }
                    }
                    .accessibilityIdentifier(TestIdentifiers.avoidSaveButton)
                }
            }
        }
        .navigationBarHidden(true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TestIdentifiers.avoidEditorView)
        .task { await session.refreshAvoidanceOptions() }
    }

    private func toggle(_ key: String) {
        if let idx = selected.firstIndex(of: key) {
            selected.remove(at: idx)
        } else {
            selected.append(key)
        }
    }

    private func addCustom() {
        let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        // Map a typed catalog label ("MSG", "Gluten") onto its key so it shows as a chip.
        let key = session.avoidanceOptions.first(where: { $0.label.lowercased() == trimmed })?.key ?? trimmed
        if !selected.contains(key) { selected.append(key) }
        custom = ""
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await session.updateMemberAvoid(memberUID: member.uid, avoid: selected)
            onSaved?()
            dismiss()
        } catch {
            session.handleAPIFailure(error)
            errorMessage = error.localizedDescription
        }
    }
}
