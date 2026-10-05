import SwiftUI
import UIKit

/// Item detail: quantity + low-stock threshold (REQ-009), and swiping to the
/// previous / next item of the list it was opened from (REQ-INV-020).
/// Spec version: 1.0
struct ItemDetailView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var currentID: String
    /// Frozen at open so the order is the list as the user saw it (REQ-INV-020 AC1).
    @State private var openedPager: ItemPager
    @State private var threshold: Int = 1
    @State private var quantity: Int = 1
    @State private var useOneMessage: String?
    @State private var dragOffset: CGFloat = 0
    @State private var arrivalEdge: Edge = .trailing

    init(itemID: String, pager: ItemPager? = nil) {
        _currentID = State(initialValue: itemID)
        _openedPager = State(initialValue: pager ?? ItemPager(ids: []))
    }

    private var item: InventoryItem? {
        session.inventory.first(where: { $0.id == currentID })
    }

    private var pager: ItemPager {
        openedPager.keeping(Set(session.inventory.map(\.id)))
    }

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(
                    title: "Item detail",
                    onBack: { dismiss() },
                    trailingLabel: pager.positionLabel(for: currentID)
                )

                if let item {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            hero(item)

                            Text(item.name)
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(MekasaTheme.text)
                                .accessibilityIdentifier(TestIdentifiers.itemNameLabel)
                                .accessibilityAction(named: Text("Next item")) { move(.next) }
                                .accessibilityAction(named: Text("Previous item")) { move(.previous) }

                            Text(item.category)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.textMuted)

                            if let barcode = item.barcode, !barcode.isEmpty {
                                Text("UPC \(barcode)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(MekasaTheme.textMuted)
                                    .accessibilityIdentifier(TestIdentifiers.itemBarcodeLabel)
                            }

                            // REQ-021: who in the house should steer clear, then the grade breakdown.
                            if let health = item.health {
                                MemberWarningBanner(warnings: session.memberWarnings(for: health))
                                HealthSummaryCard(health: health)
                            }

                            stepperCard(title: "Quantity", value: $quantity) {
                                quantity = max(0, quantity)
                                session.updateLowStockThreshold(itemID: item.id, threshold: threshold)
                                // Persist quantity via existing update API path.
                                Task { await persistQuantity(itemID: item.id, quantity: quantity) }
                            }

                            stepperCard(title: "Low-stock threshold", value: $threshold) {
                                threshold = max(0, threshold)
                                session.updateLowStockThreshold(itemID: item.id, threshold: threshold)
                            }

                            Text(
                                quantity <= threshold
                                    ? "This item is low stock and will appear on the shopping list."
                                    : "Raise or lower the threshold anytime. Default is 1."
                            )
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)

                            // Parity with the Android row action: dispose one without leaving the screen.
                            SecondaryButton(title: "Use 1", disabled: quantity == 0) {
                                useOne(item)
                            }
                            .accessibilityIdentifier(TestIdentifiers.itemDetailUseOneButton)

                            if let useOneMessage {
                                Text(useOneMessage)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(MekasaTheme.text)
                                    .accessibilityIdentifier(TestIdentifiers.itemDetailUseOneStatus)
                            }

                            if pager.isActive {
                                Label("Swipe left or right for the next or previous item", systemImage: "arrow.left.and.right")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(MekasaTheme.textMuted)
                                    .frame(maxWidth: .infinity)
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                        .accessibilityIdentifier(TestIdentifiers.itemDetailView)
                    }
                    .id(currentID)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: arrivalEdge),
                            removal: .move(edge: arrivalEdge == .trailing ? .leading : .trailing)
                        )
                    )
                    .offset(x: dragOffset)
                    .simultaneousGesture(swipe, including: pager.isActive ? .all : .subviews)
                } else {
                    Text("Item not found")
                        .font(MekasaTheme.bodyFont)
                        .foregroundStyle(MekasaTheme.textMuted)
                        .padding(24)
                }
            }
            .clipped()
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadEditableValues)
        .onChange(of: currentID) { _, _ in
            useOneMessage = nil
            loadEditableValues()
        }
        .task(id: currentID) {
            await refetchMissingImageIfNeeded()
            await backfillHealthIfNeeded()
        }
    }

    private func loadEditableValues() {
        if let item {
            threshold = item.lowStockThreshold
            quantity = item.quantity
        }
    }

    // MARK: - Swipe between items (REQ-INV-020)

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let dx = value.translation.width
                guard abs(dx) > abs(value.translation.height) * 1.5 else { return }
                if dx > 0, value.startLocation.x < ItemPager.backEdgeInset { return }
                dragOffset = dx * 0.35
            }
            .onEnded { value in
                if let step = ItemPager.step(translation: value.translation, startX: value.startLocation.x) {
                    move(step)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragOffset = 0 }
                }
            }
    }

    private func move(_ step: ItemPager.Step) {
        guard let target = pager.neighbor(of: currentID, step) else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { dragOffset = 0 }
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        arrivalEdge = step == .next ? .trailing : .leading
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            dragOffset = 0
            currentID = target
        }
    }

    private func hero(_ item: InventoryItem) -> some View {
        ProductHeroImage(urlString: item.imageURL, title: item.name) { image in
            await session.replaceInventoryItemImage(itemID: item.id, image: image)
        }
        .background(alignment: .leading) { neighborSliver(.previous) }
        .background(alignment: .trailing) { neighborSliver(.next) }
        .overlay(alignment: .leading) { chevron(.previous) }
        .overlay(alignment: .trailing) { chevron(.next) }
    }

    /// Dimmed edge of the neighbouring item's picture, peeking from the side (AC3).
    @ViewBuilder
    private func neighborSliver(_ step: ItemPager.Step) -> some View {
        if let id = pager.neighbor(of: currentID, step),
           let neighbor = session.inventory.first(where: { $0.id == id }) {
            ProductThumbnail(urlString: neighbor.imageURL, size: 120, cornerRadius: 20)
                .frame(width: 14, alignment: step == .previous ? .trailing : .leading)
                .clipped()
                .opacity(0.45)
                .offset(x: step == .previous ? -18 : 18)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func chevron(_ step: ItemPager.Step) -> some View {
        if pager.neighbor(of: currentID, step) != nil {
            Button {
                move(step)
            } label: {
                Image(systemName: step == .previous ? "chevron.left" : "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MekasaTheme.text)
                    .frame(width: 34, height: 34)
                    .background(MekasaTheme.surfaceElevated.opacity(0.85))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(8)
            .accessibilityLabel(step == .previous ? "Previous item" : "Next item")
            .accessibilityIdentifier(step == .previous ? TestIdentifiers.itemPagerPrevious : TestIdentifiers.itemPagerNext)
        }
    }

    /// Same consume path as the inventory swipe and the trash station.
    private func useOne(_ item: InventoryItem) {
        let result = session.consumeInventoryItem(id: item.id)
        quantity = session.inventory.first(where: { $0.id == item.id })?.quantity ?? quantity
        useOneMessage = Self.useOneMessage(for: result)
    }

    /// "Used 1 — 2 left" / "Marked gone" / nil when the row vanished underneath us.
    static func useOneMessage(for result: AppSession.ConsumeResult) -> String? {
        switch result {
        case let .decremented(_, remaining):
            return "Used 1 — \(remaining) left"
        case .depleted:
            return "Marked gone — now on the shopping list if it’s tracked"
        case .unknown:
            return nil
        }
    }

    private func stepperCard(title: String, value: Binding<Int>, onChange: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(MekasaTheme.textMuted)
            HStack {
                Button {
                    value.wrappedValue = max(0, value.wrappedValue - 1)
                    onChange()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(MekasaTheme.surfaceElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text("\(value.wrappedValue)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(MekasaTheme.text)
                    .frame(maxWidth: .infinity)

                Button {
                    value.wrappedValue += 1
                    onChange()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(MekasaTheme.surfaceElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func persistQuantity(itemID: String, quantity: Int) async {
        guard session.canSyncInventory,
              let token = session.idToken,
              let householdID = session.household?.id
        else {
            if let idx = session.inventory.firstIndex(where: { $0.id == itemID }) {
                session.inventory[idx].quantity = quantity
            }
            return
        }
        do {
            let remote = try await MekasaAPIClient.shared.updateInventoryItem(
                householdID: householdID,
                itemID: itemID,
                quantity: quantity,
                token: token
            )
            if let idx = session.inventory.firstIndex(where: { $0.id == remote.id }) {
                session.inventory[idx] = remote.toLocal()
            }
            await session.refreshShoppingList(syncLowStock: true)
        } catch {
            session.handleAPIFailure(error)
        }
    }

    /// REQ-021 AC4: barcoded rows saved before grading get their health data on first open.
    private func backfillHealthIfNeeded() async {
        guard let item,
              item.health == nil,
              let barcode = item.barcode, !barcode.isEmpty,
              session.canSyncInventory,
              let token = session.idToken,
              let householdID = session.household?.id
        else { return }

        do {
            let remote = try await MekasaAPIClient.shared.refreshInventoryItemHealth(
                householdID: householdID,
                itemID: item.id,
                token: token
            )
            guard remote.health != nil else { return }
            if let idx = session.inventory.firstIndex(where: { $0.id == remote.id }) {
                session.inventory[idx] = remote.toLocal()
            }
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                session.handleAPIFailure(error)
            }
        }
    }

    /// Backend fills `image_url` via OFF / category placeholder when the row has none.
    private func refetchMissingImageIfNeeded() async {
        guard let item,
              item.imageURL == nil || item.imageURL?.isEmpty == true,
              session.canSyncInventory,
              let token = session.idToken,
              let householdID = session.household?.id
        else { return }

        do {
            let remote = try await MekasaAPIClient.shared.refreshInventoryItemImage(
                householdID: householdID,
                itemID: item.id,
                token: token
            )
            guard remote.imageURL != nil else { return }
            if let idx = session.inventory.firstIndex(where: { $0.id == remote.id }) {
                session.inventory[idx] = remote.toLocal()
            }
        } catch {
            // Opportunistic enrich — only escalate session expiry.
            if SessionExpiry.isUnauthorized(error) {
                session.handleAPIFailure(error)
            }
        }
    }
}
