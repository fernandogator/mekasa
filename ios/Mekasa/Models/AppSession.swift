import Foundation
import SwiftUI
import UIKit
import FirebaseAuth

/// App-wide session: auth token + onboarding household progress + inventory sync.
/// Satisfies: REQ-001, REQ-004–REQ-009, REQ-022, UI-003
/// Spec version: 1.0
@MainActor
final class AppSession: ObservableObject {
    @Published var idToken: String?
    @Published var displayName: String?
    @Published var email: String?
    /// Firebase Auth uid for the signed-in user (nil in pure preview until set).
    @Published var userUID: String?
    /// Role from members API (`owner` / `member`); used with household.ownerUID.
    @Published var myMemberRole: String?
    /// Extra capabilities from members API (REQ-014 AC3, e.g. `buyer`).
    @Published var myPermissions: [String] = []
    /// Household members (REQ-019) — kept for REQ-021 avoid-list warnings on synced items.
    @Published var householdMembers: [HouseholdMemberDTO] = []
    /// Avoidance catalog from `GET /v1/health/avoidances`; falls back to the built-in list.
    @Published var avoidanceOptions: [AvoidanceOption] = AvoidanceMatcher.fallbackOptions
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
    /// Unknown barcodes logged at trash station (REQ-008 AC3).
    @Published var unknownTrashScans: [UnknownBarcodeEventDTO] = []
    /// Latest spending report from Cloud Run (REQ-017 / REQ-018); nil until first successful refresh.
    @Published var spendingReport: SpendingReportDTO?
    /// Invite token from deep link (`mekasa://invite?token=…`) awaiting accept after sign-in.
    @Published var pendingInviteToken: String?
    /// Full-screen trash kiosk (UI-005) — launch with `--trash-station` or Family tab.
    @Published var isTrashKioskMode = false
    /// True after demo seed applied (empty inventory first open).
    var didSeedShoppingList = false
    private static let pendingInviteTokenKey = "mekasa.pendingInviteToken"
    /// In-flight creates keyed by name|category so consume can wait for server ids.
    private var pendingCreates: [String: Task<InventoryItemDTO?, Never>] = [:]
    private var unauthorizedObserver: NSObjectProtocol?
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var isHandlingSessionExpiry = false
    private var didLoadAvoidanceOptions = false
    private var deepLinkObserver: NSObjectProtocol?
    /// True while Firestore inventory/shopping listeners are attached (REQ-020).
    @Published private(set) var isRealtimeSyncActive = false

    /// Soft-removed item awaiting Undo / purge (REQ-INV-016–018).
    @Published var showInventoryUndoToast = false
    private var lastRemovedItem: InventoryItem?
    private var lastRemovedIndex: Int?
    private var inventoryUndoTask: Task<Void, Never>?

    var isSignedIn: Bool { idToken != nil }

    init() {
        lastSignedInEmail = Self.loadLastSignedInEmail()
        pendingInviteToken = Self.loadPendingInviteToken()
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

    var canSyncSpending: Bool { canSyncInventory }

    /// Owners (or future buyer permission) may mark shopping items purchased (REQ-014).
    var canMarkShoppingPurchased: Bool {
        if isUIPreview || isUITesting { return true }
        if myPermissions.contains("buyer") { return true }
        return isHouseholdOwner
    }

    /// Document owner or member with owner role.
    var isHouseholdOwner: Bool {
        if isUIPreview || isUITesting { return true }
        guard let uid = userUID else { return false }
        if household?.ownerUID == uid { return true }
        return myMemberRole == "owner"
    }

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
        userUID = "preview-owner"
        myMemberRole = "owner"
        myPermissions = []
        householdMembers = []
        household = nil
        onboardingStep = .household
        lastError = nil
        inventory = []
        activity = DashboardFixtures.activity
        shoppingList = []
        trashEvents = []
        spendingReport = nil
        didSeedShoppingList = false
        pendingCreates = [:]
        showInventoryUndoToast = false
        lastRemovedItem = nil
        lastRemovedIndex = nil
        inventoryUndoTask?.cancel()
        inventoryUndoTask = nil
        stopRealtimeSync()
    }

    /// Launch argument `--uitesting`: deterministic fixtures, no network.
    func startUITesting(emptyInventory: Bool = false) {
        isUITesting = true
        isUIPreview = true
        idToken = "uitesting"
        email = "uitesting@mekasa.local"
        displayName = "UI Test"
        userUID = "uitesting-owner"
        myMemberRole = "owner"
        myPermissions = []
        householdMembers = TestFixtures.standardMemberDTOs
        household = TestFixtures.previewHousehold
        onboardingStep = .done
        lastError = nil
        inventory = emptyInventory ? TestFixtures.emptyItemList : TestFixtures.standardItemList
        activity = DashboardFixtures.activity
        shoppingList = emptyInventory ? TestFixtures.emptyShoppingList : TestFixtures.standardShoppingList
        trashEvents = emptyInventory ? TestFixtures.emptyTrashEvents : TestFixtures.standardTrashEvents
        unknownTrashScans = []
        spendingReport = nil
        didSeedShoppingList = true
        pendingCreates = [:]
        if CommandLine.arguments.contains("--trash-station") {
            isTrashKioskMode = true
        }
        stopRealtimeSync()
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
        let tokenForPush = idToken
        stopRealtimeSync()
        Task {
            await PushRegistrationService.shared.clearRegistration(idToken: tokenForPush)
        }
        idToken = nil
        displayName = nil
        email = nil
        userUID = nil
        myMemberRole = nil
        myPermissions = []
        householdMembers = []
        household = nil
        onboardingStep = .welcome
        lastError = expiredSessionMessage
        isUIPreview = false
        isUITesting = false
        inventory = []
        activity = DashboardFixtures.activity
        shoppingList = []
        trashEvents = []
        unknownTrashScans = []
        spendingReport = nil
        isTrashKioskMode = false
        didSeedShoppingList = false
        pendingCreates = [:]
        showInventoryUndoToast = false
        lastRemovedItem = nil
        lastRemovedIndex = nil
        inventoryUndoTask?.cancel()
        inventoryUndoTask = nil
    }

    private static func loadPendingInviteToken() -> String? {
        let value = UserDefaults.standard.string(forKey: pendingInviteTokenKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false) ? value : nil
    }

    private func persistPendingInviteToken(_ token: String?) {
        pendingInviteToken = token
        if let token, !token.isEmpty {
            UserDefaults.standard.set(token, forKey: Self.pendingInviteTokenKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.pendingInviteTokenKey)
        }
    }

    /// Handle `mekasa://invite?token=…`, `mekasa://invite/TOKEN`, or `mekasa://trash`.
    func handleDeepLink(_ url: URL) {
        guard url.scheme?.caseInsensitiveCompare("mekasa") == .orderedSame else { return }
        let host = (url.host ?? "").lowercased()
        if host == "trash" || url.path.lowercased().contains("trash") {
            isTrashKioskMode = true
            if onboardingStep == .done || isUITesting || isUIPreview {
                onboardingStep = .done
            }
            return
        }
        if host == "invite" || url.path.lowercased().hasPrefix("/invite") {
            if let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
               let token = items.first(where: { $0.name == "token" })?.value,
               !token.isEmpty {
                persistPendingInviteToken(token)
                return
            }
            // mekasa://invite/TOKEN or mekasa:///invite/TOKEN
            let pathToken = url.path
                .split(separator: "/")
                .map(String.init)
                .first { $0.caseInsensitiveCompare("invite") != .orderedSame && !$0.isEmpty }
            if let pathToken, pathToken != "preview" {
                persistPendingInviteToken(pathToken)
            }
        }
    }

    /// Accept a pending invite after the user has a Firebase ID token (REQ-019).
    func acceptPendingInviteIfNeeded() async {
        guard let inviteToken = pendingInviteToken,
              let token = idToken,
              token != "preview",
              token != "uitesting"
        else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let member = try await MekasaAPIClient.shared.acceptHouseholdInvite(
                inviteToken: inviteToken,
                idToken: token
            )
            let hh = try await MekasaAPIClient.shared.currentHousehold(token: token)
            household = hh
            onboardingStep = .done
            persistPendingInviteToken(nil)
            logActivity("Joined household as \(member.role)", kind: .success)
            await refreshInventory()
            await refreshShoppingList(syncLowStock: true)
            updateRealtimeSync()
            PushRegistrationService.shared.requestPermissionAndRegister(idToken: token)
        } catch {
            handleAPIFailure(error)
        }
    }

    func refreshUnknownTrashScans() async {
        guard canSyncInventory, let token = idToken, let householdID = household?.id else { return }
        do {
            unknownTrashScans = try await MekasaAPIClient.shared.listUnknownTrashScans(
                householdID: householdID,
                token: token
            )
        } catch let error as APIError {
            // Owners only — members get 403; ignore quietly.
            if case let .server(status, _) = error, status == 403 { return }
            if error.isUnauthorized {
                handleAPIFailure(error)
            }
        } catch {
            // Non-critical list failure — leave existing cache.
        }
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
        if deepLinkObserver == nil {
            deepLinkObserver = NotificationCenter.default.addObserver(
                forName: .mekasaOpenDeepLink,
                object: nil,
                queue: .main
            ) { [weak self] note in
                guard let url = note.object as? URL else { return }
                Task { @MainActor in
                    self?.handleDeepLink(url)
                    await self?.acceptPendingInviteIfNeeded()
                }
            }
        }
        updateRealtimeSync()
        if canSyncInventory {
            PushRegistrationService.shared.requestPermissionAndRegister(idToken: idToken)
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
    /// No error alert — silent return to Welcome (REQ-022).
    func endSessionBecauseExpired() {
        try? AuthService.shared.signOut()
        signOut(expiredSessionMessage: nil)
        lastError = nil
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
            updateRealtimeSync()
            PushRegistrationService.shared.requestPermissionAndRegister(idToken: token)
        } catch {
            handleAPIFailure(error)
        }
    }

    /// Attach or detach Firestore listeners for inventory + shopping list (REQ-020).
    func updateRealtimeSync() {
        guard canSyncInventory, let householdID = household?.id else {
            stopRealtimeSync()
            return
        }
        HouseholdSyncService.shared.start(
            householdID: householdID,
            onInventory: { [weak self] items in
                guard let self, self.canSyncInventory else { return }
                self.inventory = items
                self.isRealtimeSyncActive = HouseholdSyncService.shared.isListening
            },
            onShoppingList: { [weak self] items in
                guard let self, self.canSyncShoppingList else { return }
                self.shoppingList = items
                self.didSeedShoppingList = true
                self.isRealtimeSyncActive = HouseholdSyncService.shared.isListening
            }
        )
        isRealtimeSyncActive = HouseholdSyncService.shared.isListening
    }

    func stopRealtimeSync() {
        HouseholdSyncService.shared.stop()
        isRealtimeSyncActive = false
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
            await refreshMyMembership()
        } catch {
            handleAPIFailure(error)
        }
    }

    /// Refresh this user's role/permissions for purchase gating (REQ-014).
    func refreshMyMembership() async {
        guard canSyncInventory,
              let token = idToken,
              let householdID = household?.id,
              let uid = userUID ?? AuthService.shared.currentUserUID
        else { return }
        userUID = uid
        if household?.ownerUID == uid {
            myMemberRole = "owner"
        }
        do {
            let response = try await MekasaAPIClient.shared.listHouseholdMembers(
                householdID: householdID,
                token: token
            )
            householdMembers = response.members
            if let me = response.members.first(where: { $0.uid == uid }) {
                myMemberRole = me.role
                myPermissions = me.permissions
            }
        } catch {
            // Non-fatal — ownerUID comparison still works for document owners.
        }
        await refreshAvoidanceOptions()
    }

    // MARK: - Health grade + avoidances (REQ-021)

    /// Load the allergen / additive catalog once per session (fallback list until then).
    func refreshAvoidanceOptions() async {
        guard canSyncInventory, let token = idToken, !didLoadAvoidanceOptions else { return }
        do {
            let response = try await MekasaAPIClient.shared.listAvoidances(token: token)
            if !response.options.isEmpty {
                avoidanceOptions = response.options
                didLoadAvoidanceOptions = true
            }
        } catch {
            // Fallback catalog stays in place; nothing user-facing to report.
        }
    }

    /// The signed-in user's own avoid list (empty until members load).
    var myAvoidList: [String] {
        guard let uid = userUID else { return [] }
        return householdMembers.first(where: { $0.uid == uid })?.avoid ?? []
    }

    /// Members whose avoid list this product triggers — computed locally so items that
    /// arrive via Firestore sync (no `warnings` field) still warn (REQ-021 AC2, AC4).
    func memberWarnings(for health: ProductHealth?) -> [MemberWarning] {
        AvoidanceMatcher.warnings(members: householdMembers, health: health, options: avoidanceOptions)
    }

    /// Replace a member's avoid list on the server and in the local cache.
    func updateMemberAvoid(memberUID: String, avoid: [String]) async throws {
        guard let token = idToken, let householdID = household?.id else { return }
        if isUIPreview || isUITesting {
            replaceMember(uid: memberUID, avoid: avoid)
            return
        }
        let updated = try await MekasaAPIClient.shared.updateHouseholdMemberAvoid(
            householdID: householdID,
            memberUID: memberUID,
            avoid: avoid,
            token: token
        )
        replaceMember(uid: updated.uid, avoid: updated.avoid)
    }

    private func replaceMember(uid: String, avoid: [String]) {
        guard let idx = householdMembers.firstIndex(where: { $0.uid == uid }) else { return }
        let old = householdMembers[idx]
        householdMembers[idx] = HouseholdMemberDTO(
            uid: old.uid,
            householdId: old.householdId,
            name: old.name,
            email: old.email,
            phone: old.phone,
            role: old.role,
            status: old.status,
            permissions: old.permissions,
            avoid: avoid
        )
    }

    /// Pull spending report from Cloud Run (rolling week/month/year of purchase events).
    func refreshSpending(period: SpendingPeriod = .week) async {
        guard canSyncSpending,
              let token = idToken,
              let householdID = household?.id
        else { return }
        do {
            spendingReport = try await MekasaAPIClient.shared.getSpendingReport(
                householdID: householdID,
                period: period,
                token: token
            )
        } catch {
            handleAPIFailure(error)
        }
    }

    /// Local inventory price rollup used as offline / preview fallback for Spend UI.
    var localTrackedSpend: Double {
        inventory.reduce(0) { partial, item in
            partial + (item.pricePaid ?? 0) * Double(max(item.quantity, 1))
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

    /// Soft-remove from list with 5s Undo, then purge (REQ-INV-015–018).
    func softRemoveInventoryItem(id: String) {
        guard let idx = inventory.firstIndex(where: { $0.id == id }) else { return }
        let item = inventory[idx]
        lastRemovedItem = item
        lastRemovedIndex = idx
        inventory.remove(at: idx)
        syncShoppingListFromInventory()
        showInventoryUndoToast = true
        logActivity("Removed \(item.name)", kind: .warning)

        inventoryUndoTask?.cancel()
        if canSyncInventory {
            Task { await persistSoftDelete(itemID: id) }
        }
        inventoryUndoTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            showInventoryUndoToast = false
            let pending = lastRemovedItem
            lastRemovedItem = nil
            lastRemovedIndex = nil
            if canSyncInventory, let pending {
                await persistPurge(itemID: pending.id)
            }
        }
    }

    func undoInventoryRemove() {
        inventoryUndoTask?.cancel()
        inventoryUndoTask = nil
        showInventoryUndoToast = false
        guard let item = lastRemovedItem else { return }
        let index = min(lastRemovedIndex ?? 0, inventory.count)
        inventory.insert(item, at: index)
        syncShoppingListFromInventory()
        logActivity("Restored \(item.name)", kind: .success)
        lastRemovedItem = nil
        lastRemovedIndex = nil
        if canSyncInventory {
            Task { await persistRestore(itemID: item.id) }
        }
    }

    /// Trash station: consume by barcode via API when signed in, else local match.
    @discardableResult
    func consumeInventoryByBarcode(_ barcode: String) async -> ConsumeResult {
        let code = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return .unknown }

        if canSyncInventory, let token = idToken, let householdID = household?.id {
            do {
                let result = try await MekasaAPIClient.shared.consumeInventoryByBarcode(
                    householdID: householdID,
                    barcode: code,
                    amount: 1,
                    token: token
                )
                if result.found, let remote = result.item {
                    upsertRemote(remote)
                    await refreshShoppingList(syncLowStock: true)
                    if remote.quantity == 0 {
                        return .depleted(name: remote.name)
                    }
                    return .decremented(name: remote.name, remaining: remote.quantity)
                }
                if let event = result.unknownEvent {
                    trashEvents.insert(
                        TrashEvent(
                            id: event.id,
                            itemName: "Unknown (\(event.barcode))",
                            quantityDelta: 0,
                            scannedAt: ISO8601DateFormatter().string(from: Date())
                        ),
                        at: 0
                    )
                    logActivity("Unknown trash scan \(event.barcode)", kind: .warning)
                }
                return .unknown
            } catch {
                handleAPIFailure(error)
                return .unknown
            }
        }

        if let match = inventory.first(where: { $0.barcode == code }) {
            return consumeInventoryItem(id: match.id)
        }
        trashEvents.insert(
            TrashEvent(
                id: UUID().uuidString,
                itemName: "Unknown (\(code))",
                quantityDelta: 0,
                scannedAt: ISO8601DateFormatter().string(from: Date())
            ),
            at: 0
        )
        logActivity("Unknown trash scan \(code)", kind: .warning)
        return .unknown
    }

    func updateLowStockThreshold(itemID: String, threshold: Int) {
        guard let idx = inventory.firstIndex(where: { $0.id == itemID }) else { return }
        inventory[idx].lowStockThreshold = max(0, threshold)
        inventory[idx].updatedAt = Date()
        syncShoppingListFromInventory()
        guard canSyncInventory, let token = idToken, let householdID = household?.id else { return }
        Task {
            do {
                let remote = try await MekasaAPIClient.shared.updateInventoryItem(
                    householdID: householdID,
                    itemID: itemID,
                    lowStockThreshold: threshold,
                    token: token
                )
                upsertRemote(remote)
                await refreshShoppingList(syncLowStock: true)
            } catch {
                handleAPIFailure(error)
            }
        }
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
        guard canMarkShoppingPurchased else {
            lastError = "Only household owners can mark items purchased."
            return
        }
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
        let asRequest = !isHouseholdOwner && !isUIPreview && !isUITesting
        let item = ShoppingListItem(
            name: name,
            quantity: max(1, quantity),
            needsApproval: asRequest,
            requestedBy: asRequest ? (displayName ?? "Member") : nil,
            kind: asRequest ? .request : .custom
        )
        shoppingList.insert(item, at: 0)
        logActivity(
            asRequest ? "Requested \(name)" : "Added \(name) to list",
            kind: .success
        )
        guard canSyncShoppingList else { return }
        Task { await persistShoppingCreate(item) }
    }

    func approveShoppingRequest(id: String) {
        guard isHouseholdOwner else {
            lastError = "Only household owners can approve requests."
            return
        }
        guard let idx = shoppingList.firstIndex(where: { $0.id == id }) else { return }
        shoppingList[idx].needsApproval = false
        shoppingList[idx].kind = .custom
        logActivity("Approved \(shoppingList[idx].name)", kind: .success)
        guard canSyncShoppingList else { return }
        Task { await persistShoppingApprove(itemID: id) }
    }

    func rejectShoppingRequest(id: String) {
        guard isHouseholdOwner else {
            lastError = "Only household owners can deny requests."
            return
        }
        guard let idx = shoppingList.firstIndex(where: { $0.id == id }) else { return }
        let name = shoppingList[idx].name
        shoppingList.remove(at: idx)
        logActivity("Denied \(name)", kind: .warning)
        guard canSyncShoppingList else { return }
        Task { await persistShoppingReject(itemID: id) }
    }

    /// Remove a row from the list (any member; REQ-012). Pending requests should go
    /// through approve/reject when the caller is an owner.
    func removeShoppingItem(id: String) {
        guard let idx = shoppingList.firstIndex(where: { $0.id == id }) else { return }
        let name = shoppingList[idx].name
        shoppingList.remove(at: idx)
        logActivity("Removed \(name) from list", kind: .warning)
        guard canSyncShoppingList else { return }
        Task { await persistShoppingDelete(itemID: id) }
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
            if let imageURL = next.imageURL {
                inventory[idx].imageURL = imageURL
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
        // Prefer whichever side still has a product image (scan confirm vs refresh).
        if next.imageURL == nil {
            next.imageURL = existing.imageURL
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
                    let result = try await MekasaAPIClient.shared.consumeInventoryByBarcode(
                        householdID: householdID,
                        barcode: barcode,
                        amount: 1,
                        token: token
                    )
                    if result.found, let remote = result.item {
                        upsertRemote(remote)
                    } else if let event = result.unknownEvent {
                        logActivity("Unknown trash scan \(event.barcode)", kind: .warning)
                    }
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

    private func persistSoftDelete(itemID: String) async {
        guard let token = idToken, let householdID = household?.id else { return }
        do {
            try await MekasaAPIClient.shared.deleteInventoryItem(
                householdID: householdID,
                itemID: itemID,
                token: token
            )
        } catch {
            handleAPIFailure(error)
        }
    }

    private func persistRestore(itemID: String) async {
        guard let token = idToken, let householdID = household?.id else { return }
        do {
            let remote = try await MekasaAPIClient.shared.restoreInventoryItem(
                householdID: householdID,
                itemID: itemID,
                token: token
            )
            upsertRemote(remote)
        } catch {
            handleAPIFailure(error)
            await refreshInventory()
        }
    }

    private func persistPurge(itemID: String) async {
        guard let token = idToken, let householdID = household?.id else { return }
        do {
            try await MekasaAPIClient.shared.purgeInventoryItem(
                householdID: householdID,
                itemID: itemID,
                token: token
            )
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                handleAPIFailure(error)
            }
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

    private func persistShoppingDelete(itemID: String) async {
        guard let token = idToken, let householdID = household?.id else { return }
        do {
            try await MekasaAPIClient.shared.deleteShoppingListItem(
                householdID: householdID,
                itemID: itemID,
                token: token
            )
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                handleAPIFailure(error)
                return
            }
            lastError = "Couldn’t remove that item: \(error.localizedDescription)"
            await refreshShoppingList()
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

    /// Upload / replace the household home photo (REQ-002 / UI-004 AC3).
    @discardableResult
    func uploadHouseholdHomePhoto(_ image: UIImage, compressionQuality: CGFloat = 0.82) async -> Bool {
        guard let jpeg = image.jpegData(compressionQuality: compressionQuality) else {
            lastError = "Couldn’t encode that photo."
            return false
        }
        if isUIPreview || isUITesting {
            let b64 = jpeg.base64EncodedString()
            let dataURL = "data:image/jpeg;base64,\(b64)"
            if var hh = household {
                hh.photoURL = dataURL
                household = hh
            } else {
                household = PreviewFixtures.household(name: "Your house", photoURL: dataURL)
            }
            logActivity("Updated home photo", kind: .success)
            return true
        }
        guard isHouseholdOwner else {
            lastError = "Only household owners can change the home photo."
            return false
        }
        guard let token = idToken, let householdID = household?.id else {
            lastError = "Not signed in to a household."
            return false
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let updated = try await MekasaAPIClient.shared.uploadHouseholdPhoto(
                householdID: householdID,
                imageData: jpeg,
                mimeType: "image/jpeg",
                token: token
            )
            household = updated
            logActivity("Updated home photo", kind: .success)
            return true
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                handleAPIFailure(error)
                return false
            }
            lastError = error.localizedDescription
            return false
        }
    }

    /// Persist house name and/or cropped home photo in one busy cycle.
    @discardableResult
    func saveHomePhotoEdits(
        name: String?,
        image: UIImage?,
        nameChanged: Bool,
        imageChanged: Bool
    ) async -> Bool {
        guard nameChanged || imageChanged else { return true }
        if isUIPreview || isUITesting {
            if nameChanged {
                let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalized: String? = (trimmed?.isEmpty == false) ? trimmed : nil
                if var hh = household {
                    hh.name = normalized
                    household = hh
                } else {
                    household = PreviewFixtures.household(name: normalized)
                }
            }
            if imageChanged, let image {
                return await uploadHouseholdHomePhoto(image)
            }
            if nameChanged {
                logActivity("Updated house name", kind: .success)
            }
            return true
        }
        guard isHouseholdOwner else {
            lastError = "Only household owners can update the home photo."
            return false
        }
        guard let token = idToken, let householdID = household?.id else {
            lastError = "Not signed in to a household."
            return false
        }
        isBusy = true
        defer { isBusy = false }
        do {
            if nameChanged {
                let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalized: String? = (trimmed?.isEmpty == false) ? trimmed : nil
                household = try await MekasaAPIClient.shared.updateHouseholdName(
                    householdID: householdID,
                    name: normalized,
                    token: token
                )
            }
            if imageChanged, let image {
                guard let jpeg = image.jpegData(compressionQuality: 0.82) else {
                    lastError = "Couldn’t encode that photo."
                    return false
                }
                household = try await MekasaAPIClient.shared.uploadHouseholdPhoto(
                    householdID: householdID,
                    imageData: jpeg,
                    mimeType: "image/jpeg",
                    token: token
                )
                logActivity("Updated home photo", kind: .success)
            } else if nameChanged {
                logActivity("Updated house name", kind: .success)
            }
            return true
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                handleAPIFailure(error)
                return false
            }
            lastError = error.localizedDescription
            return false
        }
    }

    /// Update household display name (REQ-002 AC1), e.g. "The Guerrero Home".
    @discardableResult
    func updateHouseholdName(_ name: String?) async -> Bool {
        await saveHomePhotoEdits(
            name: name,
            image: nil,
            nameChanged: true,
            imageChanged: false
        )
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
