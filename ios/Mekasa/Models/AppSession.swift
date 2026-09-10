import Foundation
import SwiftUI
import FirebaseAuth

/// App-wide session: auth token + onboarding household progress + inventory sync.
/// Satisfies: REQ-001, REQ-004–REQ-009, REQ-022, UI-003
/// Spec version: 1.0
@MainActor
final class AppSession: ObservableObject {
    @Published var idToken: String?
    @Published var displayName: String?
    @Published var email: String?
    /// Last successful sign-in email/username. Survives sign-out so Welcome can prefill it.
    @Published private(set) var lastSignedInEmail: String?
    @Published var household: Household?
    @Published var onboardingStep: OnboardingStep = .welcome
    @Published var isBusy = false
    @Published var lastError: String?

    private static let lastSignedInEmailKey = "mekasa.lastSignedInEmail"
    /// DEBUG-only local walkthrough — skips network/Firebase.
    @Published var isUIPreview = false
    /// XCUITest / snapshot mode: fixtures only, no network, animations off.
    @Published var isUITesting = false
    /// Household inventory (local cache; synced to API when signed in).
    @Published var inventory: [InventoryItem] = []
    @Published var activity: [ActivityItem] = DashboardFixtures.activity
    /// Client shopping list cache; synced to API when signed in (REQ-011–014).
    @Published var shoppingList: [ShoppingListItem] = []
    /// Recent trash-station events (UI testing / trash log).
    @Published var trashEvents: [TrashEvent] = []
    /// True after demo seed applied (empty inventory first open).
    var didSeedShoppingList = false
    /// In-flight creates keyed by name|category so consume can wait for server ids.
    private var pendingCreates: [String: Task<InventoryItemDTO?, Never>] = [:]
    private var unauthorizedObserver: NSObjectProtocol?
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var isHandlingSessionExpiry = false

    var isSignedIn: Bool { idToken != nil }

    init() {
        lastSignedInEmail = Self.loadLastSignedInEmail()
    }

    /// Live API sync when we have a real household + token (not UI preview / UI testing).
    var canSyncInventory: Bool {
        !isUIPreview
            && !isUITesting
            && idToken != nil
            && idToken != "preview"
            && idToken != "uitesting"
            && household != nil
    }

    var canSyncShoppingList: Bool { canSyncInventory }

    var lowStockCount: Int {
        let live = inventory.filter(\.isLowStock).count
        if inventory.isEmpty { return DashboardFixtures.lowStockCount }
        return live
    }

    var openShoppingCount: Int {
        shoppingList.filter { !$0.isChecked && !$0.needsApproval }.count
    }

    func startUIPreview() {
        isUIPreview = true
        isUITesting = false
        idToken = "preview"
        email = "preview@mekasa.local"
        displayName = "Preview"
        household = nil
        onboardingStep = .household
        lastError = nil
        inventory = []
        activity = DashboardFixtures.activity
        shoppingList = []
        trashEvents = []
        didSeedShoppingList = false
        pendingCreates = [:]
    }

    /// Launch argument `--uitesting`: deterministic fixtures, no network.
    func startUITesting(emptyInventory: Bool = false) {
        isUITesting = true
        isUIPreview = true
        idToken = "uitesting"
        email = "uitesting@mekasa.local"
        displayName = "UI Test"
        household = TestFixtures.previewHousehold
        onboardingStep = .done
        lastError = nil
        inventory = emptyInventory ? TestFixtures.emptyItemList : TestFixtures.standardItemList
        activity = DashboardFixtures.activity
        shoppingList = emptyInventory ? TestFixtures.emptyShoppingList : TestFixtures.standardShoppingList
        trashEvents = emptyInventory ? TestFixtures.emptyTrashEvents : TestFixtures.standardTrashEvents
        didSeedShoppingList = true
        pendingCreates = [:]
    }

    /// Remember the username/email used at sign-in so Welcome can prefill after sign-out.
    /// Satisfies: REQ-022 AC5
    func rememberSignedInEmail(_ value: String?) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return }
        lastSignedInEmail = trimmed
        UserDefaults.standard.set(trimmed, forKey: Self.lastSignedInEmailKey)
    }

    func signOut(expiredSessionMessage: String? = nil) {
        // Keep lastSignedInEmail so Welcome can prefill the username field.
        if let email, !email.isEmpty {
            rememberSignedInEmail(email)
        }
        idToken = nil
        displayName = nil
        email = nil
        household = nil
        onboardingStep = .welcome
        lastError = expiredSessionMessage
        isUIPreview = false
        isUITesting = false
        inventory = []
        activity = DashboardFixtures.activity
        shoppingList = []
        trashEvents = []
        didSeedShoppingList = false
        pendingCreates = [:]
    }

    private static func loadLastSignedInEmail() -> String? {
        let value = UserDefaults.standard.string(forKey: lastSignedInEmailKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false) ? value : nil
    }

    /// Wire 401 + Firebase auth-state monitoring. Call once from app launch.
    /// Satisfies: REQ-022
    /// Spec version: 1.0
    func startSessionMonitoring() {
        guard unauthorizedObserver == nil else { return }
        unauthorizedObserver = NotificationCenter.default.addObserver(
            forName: .mekasaSessionUnauthorized,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleUnauthorizedAPIResponse()
            }
        }
        authStateHandle = AuthService.shared.addAuthStateListener { [weak self] isAuthenticated in
            guard let self else { return }
            // Ignore preview / UI-test fixtures and the moment we clear token ourselves.
            guard !self.isUIPreview, !self.isUITesting else { return }
            guard self.idToken != nil, self.idToken != "preview", self.idToken != "uitesting" else { return }
            if !isAuthenticated {
                self.endSessionBecauseExpired()
            }
        }
    }

    func stopSessionMonitoring() {
        if let unauthorizedObserver {
            NotificationCenter.default.removeObserver(unauthorizedObserver)
            self.unauthorizedObserver = nil
        }
        AuthService.shared.removeAuthStateListener(authStateHandle)
        authStateHandle = nil
    }

    /// Shared API failure path: expired sessions → Welcome; other errors → banner.
    func handleAPIFailure(_ error: Error) {
        if SessionExpiry.isUnauthorized(error) {
            Task { await handleUnauthorizedAPIResponse() }
            return
        }
        lastError = error.localizedDescription
    }

    /// On HTTP 401: try one Firebase token refresh; if that fails, force sign-out to Welcome.
    func handleUnauthorizedAPIResponse() async {
        guard !isUIPreview, !isUITesting else { return }
        guard !isHandlingSessionExpiry else { return }
        isHandlingSessionExpiry = true
        defer { isHandlingSessionExpiry = false }

        // Skip fixture tokens.
        guard let token = idToken, token != "preview", token != "uitesting" else { return }

        do {
            let refreshed = try await AuthService.shared.refreshIDToken(forcingRefresh: true)
            idToken = refreshed
            // Soft notice — next request uses the fresh token.
            lastError = nil
        } catch {
            endSessionBecauseExpired()
        }
    }

    /// Clears Firebase + local session and returns to the sign-in screen.
    func endSessionBecauseExpired() {
        try? AuthService.shared.signOut()
        signOut(expiredSessionMessage: SessionExpiry.userMessage)
    }

    /// Pull inventory from Cloud Run / Firestore.
    func refreshInventory() async {
        guard canSyncInventory,
              let token = idToken,
              let householdID = household?.id
        else { return }
        do {
            let response = try await MekasaAPIClient.shared.listInventory(
                householdID: householdID,
                token: token
            )
            inventory = response.items.map { $0.toLocal() }
            await refreshShoppingList(syncLowStock: true)
        } catch {
            handleAPIFailure(error)
        }
    }

    /// Pull shopping list from Cloud Run / Firestore (optionally sync low-stock first).
    func refreshShoppingList(syncLowStock: Bool = false) async {
        guard canSyncShoppingList,
              let token = idToken,
              let householdID = household?.id
        else { return }
        do {
            if syncLowStock {
                let response = try await MekasaAPIClient.shared.syncShoppingListFromInventory(
                    householdID: householdID,
                    token: token
                )
                shoppingList = response.items.map { $0.toLocal() }
            } else {
                let response = try await MekasaAPIClient.shared.listShoppingList(
                    householdID: householdID,
                    token: token
                )
                shoppingList = response.items.map { $0.toLocal() }
            }
            didSeedShoppingList = true
        } catch {
            handleAPIFailure(error)
        }
    }

    func addInventoryItem(_ item: InventoryItem) {
        applyLocalAdd(item)
        guard canSyncInventory else { return }
        let key = Self.mergeKey(name: item.name, category: item.category)
        let task = Task<InventoryItemDTO?, Never> { [weak self] in
            await self?.persistCreate(item)
        }
        pendingCreates[key] = task
        Task {
            _ = await task.value
            pendingCreates[key] = nil
        }
    }

    enum ConsumeResult {
        case decremented(name: String, remaining: Int)
        case depleted(name: String)
        case unknown
    }

    @discardableResult
    func consumeInventoryItem(id: String) -> ConsumeResult {
        let snapshot = inventory.first(where: { $0.id == id })
        let result = applyLocalConsume(id: id)
        if canSyncInventory {
            switch result {
            case .unknown:
                break
            case .decremented, .depleted:
                Task { await persistConsume(itemID: id, fallback: snapshot) }
            }
        }
        return result
    }

    func logActivity(_ title: String, kind: ActivityItem.Kind) {
        let item = ActivityItem(
            id: UUID().uuidString,
            title: title,
            when: "Just now",
            kind: kind
        )
        activity.insert(item, at: 0)
        if activity.count > 20 {
            activity = Array(activity.prefix(20))
        }
    }

    /// Seed demo rows when offline/preview; otherwise refresh from API.
    func ensureShoppingListSeeded() {
        guard !didSeedShoppingList else { return }
        if canSyncShoppingList {
            didSeedShoppingList = true
            Task { await refreshShoppingList(syncLowStock: true) }
            return
        }
        didSeedShoppingList = true
        guard shoppingList.isEmpty, inventory.isEmpty else {
            syncShoppingListFromInventory()
            return
        }
        shoppingList = ShoppingListFixtures.demo
    }

    /// REQ-011: low-stock inventory rows auto-appear on the list (no approval).
    func syncShoppingListFromInventory() {
        if canSyncShoppingList {
            Task { await refreshShoppingList(syncLowStock: true) }
            return
        }
        for item in inventory where item.isLowStock {
            let already = shoppingList.contains {
                !$0.isChecked
                    && (
                        $0.inventoryItemID == item.id
                            || $0.name.localizedCaseInsensitiveCompare(item.name) == .orderedSame
                    )
            }
            guard !already else { continue }
            let needed = max(1, item.lowStockThreshold - item.quantity + 1)
            shoppingList.insert(
                ShoppingListItem(
                    name: item.name,
                    quantity: needed,
                    inventoryItemID: item.id,
                    kind: .auto
                ),
                at: 0
            )
            logActivity("\(item.name) added to shopping list", kind: .warning)
        }
    }

    func toggleShoppingItemChecked(id: String) {
        guard let idx = shoppingList.firstIndex(where: { $0.id == id }) else { return }
        guard !shoppingList[idx].needsApproval else { return }
        shoppingList[idx].isChecked.toggle()
        let checked = shoppingList[idx].isChecked
        let name = shoppingList[idx].name
        if checked {
            logActivity("Purchased \(name)", kind: .success)
        }
        guard canSyncShoppingList else { return }
        Task { await persistShoppingPatch(itemID: id, isChecked: checked) }
    }

    func addCustomShoppingItem(name: String, quantity: Int) {
        let item = ShoppingListItem(name: name, quantity: max(1, quantity), kind: .custom)
        shoppingList.insert(item, at: 0)
        logActivity("Added \(name) to list", kind: .success)
        guard canSyncShoppingList else { return }
        Task { await persistShoppingCreate(item) }
    }

    func approveShoppingRequest(id: String) {
        guard let idx = shoppingList.firstIndex(where: { $0.id == id }) else { return }
        shoppingList[idx].needsApproval = false
        shoppingList[idx].kind = .custom
        logActivity("Approved \(shoppingList[idx].name)", kind: .success)
        guard canSyncShoppingList else { return }
        Task { await persistShoppingApprove(itemID: id) }
    }

    func rejectShoppingRequest(id: String) {
        guard let idx = shoppingList.firstIndex(where: { $0.id == id }) else { return }
        let name = shoppingList[idx].name
        shoppingList.remove(at: idx)
        logActivity("Denied \(name)", kind: .warning)
        guard canSyncShoppingList else { return }
        Task { await persistShoppingReject(itemID: id) }
    }

    // MARK: - Local inventory mutators

    private func applyLocalAdd(_ item: InventoryItem) {
        var next = item
        next.updatedAt = Date()
        if let idx = inventory.firstIndex(where: {
            $0.name.localizedCaseInsensitiveCompare(next.name) == .orderedSame
                && $0.category == next.category
        }) {
            inventory[idx].quantity += next.quantity
            if let price = next.pricePaid {
                inventory[idx].pricePaid = price
            }
            if let barcode = next.barcode {
                inventory[idx].barcode = barcode
            }
            inventory[idx].updatedAt = next.updatedAt
            logActivity("Updated \(inventory[idx].name) (qty \(inventory[idx].quantity))", kind: .success)
        } else {
            inventory.insert(next, at: 0)
            logActivity("Added \(next.name)", kind: .success)
        }
        syncShoppingListFromInventory()
    }

    private func applyLocalConsume(id: String) -> ConsumeResult {
        guard let idx = inventory.firstIndex(where: { $0.id == id }) else {
            return .unknown
        }
        let name = inventory[idx].name
        inventory[idx].quantity = max(0, inventory[idx].quantity - 1)
        inventory[idx].updatedAt = Date()
        let qty = inventory[idx].quantity
        syncShoppingListFromInventory()
        if qty == 0 {
            logActivity("\(name) marked as depleted", kind: .warning)
            return .depleted(name: name)
        }
        logActivity("\(name) consumed (qty \(qty))", kind: .warning)
        return .decremented(name: name, remaining: qty)
    }

    private func upsertRemote(_ remote: InventoryItemDTO, preserveLowerLocalQuantity: Bool = false) {
        let local = remote.toLocal()
        if let idx = inventory.firstIndex(where: { $0.id == local.id }) {
            inventory[idx] = merged(existing: inventory[idx], remote: local, preserveLower: preserveLowerLocalQuantity)
        } else if let idx = inventory.firstIndex(where: {
            $0.name.localizedCaseInsensitiveCompare(local.name) == .orderedSame
                && $0.category.localizedCaseInsensitiveCompare(local.category) == .orderedSame
        }) {
            inventory[idx] = merged(existing: inventory[idx], remote: local, preserveLower: preserveLowerLocalQuantity)
        } else {
            inventory.insert(local, at: 0)
        }
        syncShoppingListFromInventory()
    }

    private func merged(
        existing: InventoryItem,
        remote: InventoryItem,
        preserveLower: Bool
    ) -> InventoryItem {
        var next = remote
        if preserveLower {
            next.quantity = min(existing.quantity, remote.quantity)
        }
        return next
    }

    private func persistCreate(_ item: InventoryItem) async -> InventoryItemDTO? {
        guard let token = idToken, let householdID = household?.id else { return nil }
        do {
            let remote = try await MekasaAPIClient.shared.createInventoryItem(
                householdID: householdID,
                item: item,
                token: token
            )
            upsertRemote(remote, preserveLowerLocalQuantity: true)
            return remote
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                handleAPIFailure(error)
                return nil
            }
            lastError = "Couldn’t sync \(item.name): \(error.localizedDescription)"
            return nil
        }
    }

    private func persistConsume(itemID: String, fallback: InventoryItem?) async {
        guard let token = idToken, let householdID = household?.id else { return }
        let keyItem = fallback ?? inventory.first(where: { $0.id == itemID })
        if let keyItem {
            let key = Self.mergeKey(name: keyItem.name, category: keyItem.category)
            if let pending = pendingCreates[key] {
                _ = await pending.value
            }
        }

        let resolvedID = inventory.first(where: {
            $0.id == itemID
                || (
                    keyItem != nil
                        && $0.name.localizedCaseInsensitiveCompare(keyItem!.name) == .orderedSame
                        && $0.category.localizedCaseInsensitiveCompare(keyItem!.category) == .orderedSame
                )
        })?.id ?? itemID

        do {
            let remote = try await MekasaAPIClient.shared.consumeInventoryItem(
                householdID: householdID,
                itemID: resolvedID,
                amount: 1,
                token: token
            )
            upsertRemote(remote)
            return
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                handleAPIFailure(error)
                return
            }
            if let barcode = keyItem?.barcode, !barcode.isEmpty {
                do {
                    let remote = try await MekasaAPIClient.shared.consumeInventoryByBarcode(
                        householdID: householdID,
                        barcode: barcode,
                        amount: 1,
                        token: token
                    )
                    upsertRemote(remote)
                    return
                } catch {
                    if SessionExpiry.isUnauthorized(error) {
                        handleAPIFailure(error)
                        return
                    }
                    lastError = "Couldn’t sync consume: \(error.localizedDescription)"
                    return
                }
            }
            lastError = "Couldn’t sync consume: \(error.localizedDescription)"
        }
    }

    private func upsertShoppingRemote(_ remote: ShoppingListItemDTO) {
        let local = remote.toLocal()
        if let idx = shoppingList.firstIndex(where: { $0.id == local.id }) {
            shoppingList[idx] = local
        } else if let idx = shoppingList.firstIndex(where: {
            !$0.isChecked
                && $0.name.localizedCaseInsensitiveCompare(local.name) == .orderedSame
        }) {
            shoppingList[idx] = local
        } else {
            shoppingList.insert(local, at: 0)
        }
    }

    private func persistShoppingCreate(_ item: ShoppingListItem) async {
        guard let token = idToken, let householdID = household?.id else { return }
        do {
            let remote = try await MekasaAPIClient.shared.createShoppingListItem(
                householdID: householdID,
                item: item,
                token: token
            )
            upsertShoppingRemote(remote)
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                handleAPIFailure(error)
                return
            }
            lastError = "Couldn’t sync list item: \(error.localizedDescription)"
        }
    }

    private func persistShoppingPatch(itemID: String, isChecked: Bool) async {
        guard let token = idToken, let householdID = household?.id else { return }
        do {
            let remote = try await MekasaAPIClient.shared.updateShoppingListItem(
                householdID: householdID,
                itemID: itemID,
                isChecked: isChecked,
                token: token
            )
            upsertShoppingRemote(remote)
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                handleAPIFailure(error)
                return
            }
            lastError = "Couldn’t sync purchase: \(error.localizedDescription)"
            await refreshShoppingList()
        }
    }

    private func persistShoppingApprove(itemID: String) async {
        guard let token = idToken, let householdID = household?.id else { return }
        do {
            let remote = try await MekasaAPIClient.shared.approveShoppingListItem(
                householdID: householdID,
                itemID: itemID,
                token: token
            )
            upsertShoppingRemote(remote)
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                handleAPIFailure(error)
                return
            }
            lastError = "Couldn’t sync approval: \(error.localizedDescription)"
        }
    }

    private func persistShoppingReject(itemID: String) async {
        guard let token = idToken, let householdID = household?.id else { return }
        do {
            try await MekasaAPIClient.shared.rejectShoppingListItem(
                householdID: householdID,
                itemID: itemID,
                token: token
            )
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                handleAPIFailure(error)
                return
            }
            lastError = "Couldn’t sync denial: \(error.localizedDescription)"
            await refreshShoppingList()
        }
    }

    private static func mergeKey(name: String, category: String) -> String {
        "\(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())|\(category.lowercased())"
    }
}

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case household
    case address
    case stores
    case initialScan
    case invite
    case done

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .household: return "Your home"
        case .address: return "Address"
        case .stores: return "Stores"
        case .initialScan: return "First scan"
        case .invite: return "Invite"
        case .done: return "Home"
        }
    }

    var progressLabel: String {
        switch self {
        case .welcome: return "1 / 6"
        case .household: return "2 / 6"
        case .address: return "3 / 6"
        case .stores: return "4 / 6"
        case .initialScan: return "5 / 6"
        case .invite: return "6 / 6"
        case .done: return ""
        }
    }
}
