import SwiftUI

/// Duplicates review: one card per group, the survivor marked "Keeps this photo",
/// Merge / Not duplicates per card and "Merge all N" at the bottom.
/// Satisfies: REQ-INV-021 AC5–AC7
/// Design: design/pages/inventory-duplicates.html
/// Spec version: 1.0
struct InventoryDuplicatesView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var groups: [DuplicateGroup] = []
    @State private var isLoading = true
    @State private var mergingIDs: Set<String> = []
    @State private var confirmation: String?
    @State private var errorMessage: String?

    private var dismissed: DismissedDuplicates {
        DismissedDuplicates(householdID: session.household?.id)
    }

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                header
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if groups.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(groups) { group in
                                card(group)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                    PrimaryButton(
                        title: "Merge all \(groups.count)",
                        disabled: !mergingIDs.isEmpty,
                        isLoading: !mergingIDs.isEmpty
                    ) {
                        Task { await mergeAll() }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .accessibilityIdentifier(TestIdentifiers.duplicatesMergeAllButton)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TestIdentifiers.duplicatesView)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
                    .accessibilityIdentifier(TestIdentifiers.duplicatesDoneButton)
            }
        }
        .overlay(alignment: .bottom) {
            if let confirmation {
                Text(confirmation)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.onBrand)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(MekasaTheme.brand)
                    .clipShape(Capsule())
                    .padding(.bottom, 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityIdentifier(TestIdentifiers.duplicatesConfirmation)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: confirmation)
        .task { await load() }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Duplicates")
                .font(MekasaTheme.titleFont)
                .foregroundStyle(MekasaTheme.text)
            if !isLoading, !groups.isEmpty {
                Text(InventoryDuplicates.headline(groupCount: groups.count))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(MekasaTheme.textMuted)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(MekasaTheme.danger)
                    .accessibilityIdentifier(TestIdentifiers.duplicatesError)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "checkmark.seal")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(MekasaTheme.accent)
                .accessibilityHidden(true)
            Text(InventoryDuplicates.emptyTitle)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(MekasaTheme.text)
            Text(InventoryDuplicates.emptySubtitle)
                .font(MekasaTheme.bodyFont)
                .foregroundStyle(MekasaTheme.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(TestIdentifiers.duplicatesEmptyState)
    }

    private func card(_ group: DuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(group.reason.label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(MekasaTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(MekasaTheme.accentTint)
                .clipShape(Capsule())

            ForEach(group.items) { item in
                itemRow(item, keeps: item.id == group.keepID)
            }

            if let survivor = group.survivor {
                (Text("Merges into ").foregroundStyle(MekasaTheme.textMuted)
                    + Text(survivor.name).bold().foregroundStyle(MekasaTheme.text)
                    + Text(" · \(InventoryDuplicates.resultDetail(group))").foregroundStyle(MekasaTheme.textMuted))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }

            HStack(spacing: 12) {
                PrimaryButton(
                    title: "Merge",
                    disabled: !mergingIDs.isEmpty,
                    isLoading: mergingIDs.contains(group.id)
                ) {
                    Task { await merge(group) }
                }
                .accessibilityIdentifier(TestIdentifiers.duplicatesMergeButton)
                SecondaryButton(title: "Not duplicates", disabled: !mergingIDs.isEmpty) {
                    dismissed.dismiss(group)
                    groups.removeAll { $0.id == group.id }
                }
                .accessibilityIdentifier(TestIdentifiers.duplicatesDismissButton)
            }
        }
        .padding(16)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TestIdentifiers.duplicatesGroupCard)
    }

    private func itemRow(_ item: InventoryItem, keeps: Bool) -> some View {
        HStack(spacing: 12) {
            ProductThumbnail(urlString: item.imageURL, size: 48, cornerRadius: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.text)
                Text("\(item.category) · qty \(item.quantity)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
                Text(InventoryDuplicates.photoAge(item))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
            }
            Spacer()
            if keeps {
                Text(InventoryDuplicates.keepsPhotoLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.onAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(MekasaTheme.accent)
                    .clipShape(Capsule())
                    .accessibilityIdentifier(TestIdentifiers.duplicatesKeepsBadge)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(keeps ? "\(item.name), keeps this photo" : item.name)
        .accessibilityValue("\(item.category), quantity \(item.quantity), \(InventoryDuplicates.photoAge(item))")
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        switch await session.findDuplicateGroups() {
        case let .success(found):
            groups = dismissed.visible(found)
            errorMessage = nil
        case let .failure(failure):
            errorMessage = failure.message.isEmpty ? nil : failure.message
        }
        isLoading = false
    }

    private func merge(_ group: DuplicateGroup) async {
        mergingIDs.insert(group.id)
        defer { mergingIDs.remove(group.id) }
        switch await session.mergeDuplicateGroup(group) {
        case let .success(message):
            groups.removeAll { $0.id == group.id }
            errorMessage = nil
            show(message)
        case let .failure(failure):
            errorMessage = failure.message.isEmpty ? nil : failure.message
        }
    }

    private func mergeAll() async {
        let pending = groups
        var merged: [DuplicateGroup] = []
        for group in pending {
            mergingIDs.insert(group.id)
            let result = await session.mergeDuplicateGroup(group)
            mergingIDs.remove(group.id)
            switch result {
            case .success:
                merged.append(group)
                groups.removeAll { $0.id == group.id }
            case let .failure(failure):
                errorMessage = failure.message.isEmpty ? nil : failure.message
            }
        }
        if let message = InventoryDuplicates.bulkConfirmation(merged) {
            show(message)
        }
    }

    private func show(_ message: String) {
        confirmation = message
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if confirmation == message { confirmation = nil }
        }
    }
}
