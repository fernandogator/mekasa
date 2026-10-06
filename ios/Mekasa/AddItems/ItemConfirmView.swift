import SwiftUI

/// Route for the catalog match sheet (avoids navigationDestination type-checker issues).
private struct CatalogMatchRoute: Identifiable, Hashable {
    let id: String
}

/// Pick a catalog product for an unmatched receipt / manual draft (REQ-005 / REQ-006).
/// Spec version: 1.0
struct ProductMatchPickerView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    let initialQuery: String
    let onSelect: (ProductSearchHitDTO) -> Void

    @State private var query: String
    @State private var results: [ProductSearchHitDTO] = []
    @State private var isSearching = false
    @State private var didSearch = false
    @State private var errorMessage: String?

    init(initialQuery: String, onSelect: @escaping (ProductSearchHitDTO) -> Void) {
        self.initialQuery = initialQuery
        self.onSelect = onSelect
        _query = State(initialValue: initialQuery)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSearch: Bool {
        trimmedQuery.count >= 2 && session.canSyncInventory && !isSearching
    }

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(title: "Match product", onBack: { dismiss() })

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Search the catalog and pick the right variant.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)

                        MekasaTextField(
                            label: "Search",
                            placeholder: "e.g. Oreos",
                            text: $query,
                            autocapitalization: .words
                        )
                        .accessibilityIdentifier(TestIdentifiers.nameField)

                        Button {
                            Task { await search() }
                        } label: {
                            HStack {
                                if isSearching { ProgressView() }
                                Text(isSearching ? "Searching…" : "Search catalog")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(canSearch ? MekasaTheme.text : MekasaTheme.textMuted)
                            .background(MekasaTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSearch)
                        .accessibilityIdentifier(TestIdentifiers.scanButton)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(MekasaTheme.bodyFont)
                                .foregroundStyle(MekasaTheme.textMuted)
                        }

                        if didSearch && results.isEmpty && !isSearching {
                            Text("No catalog matches for “\(trimmedQuery)”. Try a shorter name.")
                                .font(MekasaTheme.bodyFont)
                                .foregroundStyle(MekasaTheme.textMuted)
                                .accessibilityIdentifier(TestIdentifiers.emptyStateView)
                        }

                        if !results.isEmpty {
                            Text("Pick a variant")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(MekasaTheme.textMuted)
                                .textCase(.uppercase)

                            ForEach(results) { hit in
                                Button {
                                    onSelect(hit)
                                    dismiss()
                                } label: {
                                    ProductSearchHitRow(hit: hit)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier(TestIdentifiers.itemCell)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            guard canSearch else { return }
            await search()
        }
    }

    private func search() async {
        guard canSearch, let token = session.idToken else { return }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            let response = try await MekasaAPIClient.shared.searchProducts(
                query: trimmedQuery,
                limit: 8,
                token: token
            )
            results = response.results
            didSearch = true
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                session.handleAPIFailure(error)
            } else {
                errorMessage = "Couldn’t search the product catalog."
            }
            results = []
            didSearch = true
        }
    }
}

struct ProductSearchHitRow: View {
    let hit: ProductSearchHitDTO

    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnail(urlString: hit.imageUrl, size: 52, cornerRadius: 14)
            VStack(alignment: .leading, spacing: 4) {
                Text(hit.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.text)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Text(hit.category)
                    if let brand = hit.brand, !brand.isEmpty {
                        Text("·")
                        Text(brand)
                    }
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(MekasaTheme.textMuted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MekasaTheme.border)
        }
        .padding(12)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct AddFlowHeader: View {
    let title: String
    let onBack: () -> Void
    /// Small capsule on the right, e.g. the item detail position "3 of 24" (REQ-INV-020 AC3).
    var trailingLabel: String?

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MekasaTheme.text)
                    .frame(width: 40, height: 40)
                    .background(MekasaTheme.surfaceElevated)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer()

            Text(title)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.text)

            Spacer()

            if let trailingLabel {
                Text(trailingLabel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.text)
                    .padding(.horizontal, 10)
                    .frame(minWidth: 40, minHeight: 28)
                    .background(MekasaTheme.surfaceMuted)
                    .clipShape(Capsule())
                    .accessibilityIdentifier(TestIdentifiers.itemPagerPosition)
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

/// Confirm one or more draft items before saving to local inventory.
/// Spec version: 1.0
struct ItemConfirmView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State var drafts: [InventoryItem]
    var title: String = "Confirm items"
    /// REQ-021 warnings returned by the barcode lookup, keyed by draft id.
    @State var serverWarnings: [String: [MemberWarning]] = [:]
    /// Store the receipt came from; nil for barcode / manual / voice confirms.
    var storeContext: ReceiptStoreContext?
    var onFinished: (() -> Void)?

    @State private var saved = false
    @State private var matchRoute: CatalogMatchRoute?
    @State private var captureRoute: CatalogMatchRoute?
    @State private var capturedDraftIDs: Set<String> = []
    /// Drafts whose photo goes to the catalog without a code (REQ-RCP-020 AC15).
    @State private var sharedPhotoDraftIDs: Set<String> = []
    /// Shared-catalog captures sent after each draft is created (REQ-RCP-020 AC6).
    @State private var catalogCaptures: [String: ProductCaptureRequestDTO] = [:]

    private var unidentifiedCount: Int {
        drafts.filter { !$0.isIdentified }.count
    }

    private var identifiedCount: Int {
        drafts.count - unidentifiedCount
    }

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                AddFlowHeader(title: title, onBack: { dismiss() })

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Review before anything saves.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)

                        if drafts.count > 1 || unidentifiedCount > 0 {
                            recognitionSummary
                        }

                        ForEach($drafts) { $draft in
                            draftCard($draft)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 140)
                    .accessibilityIdentifier(TestIdentifiers.itemDetailView)
                }

                StickyBottomBar(progress: nil) {
                    PrimaryButton(
                        title: drafts.count == 1 ? "Add to inventory" : "Add \(drafts.count) items",
                        disabled: drafts.isEmpty
                    ) {
                        for draft in drafts {
                            session.addInventoryItem(draft, catalogCapture: catalogCaptures[draft.id])
                        }
                        saved = true
                    }
                    .accessibilityIdentifier(TestIdentifiers.saveButton)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(item: $matchRoute) { route in
            NavigationStack {
                ProductMatchPickerView(
                    initialQuery: drafts.first(where: { $0.id == route.id })?.name ?? ""
                ) { hit in
                    applyMatch(hit, to: route.id)
                }
            }
            .environmentObject(session)
        }
        .sheet(item: $captureRoute) { route in
            NavigationStack {
                LocalItemCaptureView(
                    itemName: drafts.first(where: { $0.id == route.id })?.name ?? "",
                    store: storeContext,
                    shareWithoutCode: session.canSyncInventory
                        && CatalogCaptureCode.trimmedAlias(drafts.first(where: { $0.id == route.id })?.receiptText) != nil
                ) { result in
                    applyCapture(result, to: route.id)
                }
            }
            .environmentObject(session)
        }
        .alert("Saved", isPresented: $saved) {
            Button("Done") {
                onFinished?()
                dismiss()
            }
        } message: {
            Text(session.canSyncInventory
                  ? "Saved to your household inventory."
                  : "Saved on this device (sign in to sync).")
        }
    }

    private var recognitionSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(identifiedCount) recognized · \(unidentifiedCount) need review")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(MekasaTheme.text)
            if unidentifiedCount > 0 {
                Text("Scan unmatched items and take a picture, or find them in the catalog.")
                .font(MekasaTheme.bodyFont)
                .foregroundStyle(MekasaTheme.textMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier(TestIdentifiers.emptyStateView)
    }

    private func draftCard(_ draft: Binding<InventoryItem>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                EditableProductThumbnail(
                    urlString: draft.wrappedValue.imageURL,
                    size: 64,
                    cornerRadius: 16,
                    itemName: draft.wrappedValue.name
                ) { image in
                    await replaceDraftImage(image, draftID: draft.wrappedValue.id)
                }
                .accessibilityIdentifier(TestIdentifiers.itemImage)
                VStack(alignment: .leading, spacing: 6) {
                    if !draft.wrappedValue.isIdentified {
                        Text("Not identified")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(MekasaTheme.warning)
                            .accessibilityIdentifier(TestIdentifiers.scanPromptLabel)
                    } else if sharedPhotoDraftIDs.contains(draft.wrappedValue.id) {
                        Label(PhotoOnlyCapture.sharedPhotoLabel, systemImage: "person.2.fill")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(MekasaTheme.text)
                            .accessibilityIdentifier(TestIdentifiers.sharedPhotoLabel)
                    } else if capturedDraftIDs.contains(draft.wrappedValue.id) {
                        Text("Scanned in store")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(MekasaTheme.text)
                    }
                    TextField("Name", text: draft.name)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(MekasaTheme.text)
                        .accessibilityIdentifier(TestIdentifiers.itemNameLabel)
                    Text(draft.wrappedValue.category)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(MekasaTheme.textMuted)
                    if let barcode = draft.wrappedValue.barcode, !barcode.isEmpty {
                        Text("UPC \(barcode)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(MekasaTheme.textMuted)
                            .accessibilityIdentifier(TestIdentifiers.itemBarcodeLabel)
                    } else if sharedPhotoDraftIDs.contains(draft.wrappedValue.id) {
                        Text(PhotoOnlyCapture.savedCardNote)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(MekasaTheme.textMuted)
                    }
                    if let health = draft.wrappedValue.health, health.hasGrade {
                        HStack(spacing: 8) {
                            HealthGradeBadge(grade: health.grade, size: 22)
                            Text(HealthGrade.label(for: health.grade))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(HealthGrade.color(for: health.grade))
                            if !health.flaggedAdditives.isEmpty {
                                Text("· \(health.flaggedAdditives.map(\.code).joined(separator: ", "))")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(MekasaTheme.textMuted)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
                if drafts.count > 1 {
                    Button {
                        drafts.removeAll { $0.id == draft.wrappedValue.id }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(MekasaTheme.textMuted)
                            .frame(width: 28, height: 28)
                            .background(MekasaTheme.surfaceMuted)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove item")
                }
            }

            // REQ-021 AC2: warn before anything saves.
            if let health = draft.wrappedValue.health {
                MemberWarningBanner(warnings: warnings(for: draft.wrappedValue, health: health))
            }

            if !draft.wrappedValue.isIdentified {
                Text(CaptureGuidance.message(storeName: storeContext?.storeName))
                    .font(MekasaTheme.bodyFont)
                    .foregroundStyle(MekasaTheme.textMuted)
                    .accessibilityIdentifier(TestIdentifiers.captureGuidanceLabel)

                Button {
                    captureRoute = CatalogMatchRoute(id: draft.wrappedValue.id)
                } label: {
                    Label(CaptureGuidance.actionTitle, systemImage: "barcode.viewfinder")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(MekasaTheme.onBrand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(MekasaTheme.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(TestIdentifiers.captureItemButton)

                if session.canSyncInventory {
                    Button {
                        matchRoute = CatalogMatchRoute(id: draft.wrappedValue.id)
                    } label: {
                        Text("Find in catalog instead")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(MekasaTheme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(MekasaTheme.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(TestIdentifiers.scanButton)
                }
            } else if draft.wrappedValue.isIdentified, session.canSyncInventory {
                Button {
                    matchRoute = CatalogMatchRoute(id: draft.wrappedValue.id)
                } label: {
                    Text("Change match")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(MekasaTheme.textMuted)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text("Qty")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
                Spacer()
                Button {
                    draft.wrappedValue.quantity = max(1, draft.wrappedValue.quantity - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(MekasaTheme.surfaceMuted)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text("\(draft.wrappedValue.quantity)")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .frame(minWidth: 28)

                Button {
                    draft.wrappedValue.quantity += 1
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(MekasaTheme.surfaceMuted)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(MekasaTheme.text)
            .accessibilityIdentifier(TestIdentifiers.quantityControl)

            HStack {
                Text("Price")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
                Spacer()
                TextField(
                    "0.00",
                    text: Binding(
                        get: {
                            draft.wrappedValue.pricePaid.map { String(format: "%.2f", $0) } ?? ""
                        },
                        set: { raw in
                            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty {
                                draft.wrappedValue.pricePaid = nil
                            } else if let value = Double(trimmed) {
                                draft.wrappedValue.pricePaid = value
                            }
                        }
                    )
                )
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(MekasaTheme.text)
                .frame(maxWidth: 120)
                .accessibilityIdentifier(TestIdentifiers.locationField)
            }
        }
        .padding(20)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    draft.wrappedValue.isIdentified
                        ? MekasaTheme.brandMuted.opacity(0.3)
                        : MekasaTheme.warning,
                    lineWidth: 1
                )
        )
    }

    /// Server-provided warnings (barcode scan scoped to the household) win; otherwise
    /// match locally against the cached member avoid lists.
    private func warnings(for draft: InventoryItem, health: ProductHealth) -> [MemberWarning] {
        if let server = serverWarnings[draft.id], !server.isEmpty { return server }
        return session.memberWarnings(for: health)
    }

    private func applyMatch(_ hit: ProductSearchHitDTO, to draftID: String) {
        guard let idx = drafts.firstIndex(where: { $0.id == draftID }) else { return }
        drafts[idx].name = hit.name
        drafts[idx].category = hit.category
        drafts[idx].barcode = hit.barcode
        drafts[idx].imageURL = hit.imageUrl
        drafts[idx].health = hit.health
        drafts[idx].isIdentified = true
        serverWarnings[draftID] = nil
        sharedPhotoDraftIDs.remove(draftID)
        catalogCaptures[draftID] = storeContext.flatMap { store in
            CatalogCaptureCode(hit.barcode)?.request(
                photoID: nil,
                receiptText: drafts[idx].receiptText,
                storeChainId: store.storeChainId
            )
        }
        matchRoute = nil
    }

    private func replaceDraftImage(_ image: UIImage, draftID: String) async {
        let fromReceipt = drafts.first(where: { $0.id == draftID })?.source == .receipt
        let uploaded = await RequestTracing.$correlationID.withValue(fromReceipt ? session.receiptFlowID : nil) {
            await session.uploadItemPhoto(image)
        }
        guard let url = uploaded,
              let idx = drafts.firstIndex(where: { $0.id == draftID })
        else { return }
        drafts[idx].imageURL = url
    }

    /// A UPC / PLU capture, or a photo-only capture keyed by the receipt text (REQ-RCP-020 AC6, AC15).
    static func catalogCapture(
        for result: LocalItemCaptureResult,
        receiptText: String?,
        storeChainId: String?
    ) -> ProductCaptureRequestDTO? {
        if let code = CatalogCaptureCode(result.barcode) {
            return code.request(photoID: result.productPhotoID, receiptText: receiptText, storeChainId: storeChainId)
        }
        guard result.barcode == nil else { return nil }
        return CatalogCaptureCode.photoOnlyRequest(
            photoID: result.productPhotoID,
            receiptText: receiptText,
            storeChainId: storeChainId
        )
    }

    /// Capture result: the user's photo wins; a barcode catalog hit fills the rest.
    /// A UPC / PLU also queues the shared-catalog capture with the receipt text.
    private func applyCapture(_ result: LocalItemCaptureResult, to draftID: String) {
        guard let idx = drafts.firstIndex(where: { $0.id == draftID }) else { return }
        if let code = result.barcode {
            drafts[idx].barcode = code
        }
        if let hit = result.lookup {
            if let name = hit.name, !name.isEmpty { drafts[idx].name = name }
            if let category = hit.category, !category.isEmpty { drafts[idx].category = category }
            drafts[idx].health = hit.health
            serverWarnings[draftID] = hit.warnings
        }
        if let url = result.photoURL ?? result.lookup?.imageUrl {
            drafts[idx].imageURL = url
        }
        drafts[idx].isIdentified = true
        catalogCaptures[draftID] = Self.catalogCapture(
            for: result,
            receiptText: drafts[idx].receiptText,
            storeChainId: storeContext?.storeChainId
        )
        if result.barcode == nil, catalogCaptures[draftID] != nil {
            sharedPhotoDraftIDs.insert(draftID)
        } else {
            sharedPhotoDraftIDs.remove(draftID)
        }
        capturedDraftIDs.insert(draftID)
        captureRoute = nil
    }
}
