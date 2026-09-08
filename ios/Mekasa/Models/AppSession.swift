import Foundation
import SwiftUI

/// App-wide session: auth token + onboarding household progress.
/// Satisfies: REQ-001, UI-003
/// Spec version: 1.0
@MainActor
final class AppSession: ObservableObject {
    @Published var idToken: String?
    @Published var displayName: String?
    @Published var email: String?
    @Published var household: Household?
    @Published var onboardingStep: OnboardingStep = .welcome
    @Published var isBusy = false
    @Published var lastError: String?
    /// DEBUG-only local walkthrough — skips network/Firebase.
    @Published var isUIPreview = false
    /// Client-side inventory until backend CRUD exists (REQ-004–008).
    @Published var inventory: [InventoryItem] = []
    @Published var activity: [ActivityItem] = DashboardFixtures.activity
    /// Client-side shopping list until backend list APIs exist (REQ-011–014).
    @Published var shoppingList: [ShoppingListItem] = []
    /// True after demo seed applied (empty inventory first open).
    var didSeedShoppingList = false

    var isSignedIn: Bool { idToken != nil }

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
        idToken = "preview"
        email = "preview@mekasa.local"
        displayName = "Preview"
        household = nil
        onboardingStep = .household
        lastError = nil
        inventory = []
        activity = DashboardFixtures.activity
        shoppingList = []
        didSeedShoppingList = false
    }

    func signOut() {
        idToken = nil
        displayName = nil
        email = nil
        household = nil
        onboardingStep = .welcome
        lastError = nil
        isUIPreview = false
        inventory = []
        activity = DashboardFixtures.activity
        shoppingList = []
        didSeedShoppingList = false
    }

    func addInventoryItem(_ item: InventoryItem) {
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
            inventory[idx].updatedAt = next.updatedAt
            logActivity("Updated \(inventory[idx].name) (qty \(inventory[idx].quantity))", kind: .success)
        } else {
            inventory.insert(next, at: 0)
            logActivity("Added \(next.name)", kind: .success)
        }
        syncShoppingListFromInventory()
    }

    enum ConsumeResult {
        case decremented(name: String, remaining: Int)
        case depleted(name: String)
        case unknown
    }

    @discardableResult
    func consumeInventoryItem(id: String) -> ConsumeResult {
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

    /// Seed demo rows when the list is empty and there is no live inventory yet.
    func ensureShoppingListSeeded() {
        guard !didSeedShoppingList else { return }
        didSeedShoppingList = true
        guard shoppingList.isEmpty, inventory.isEmpty else {
            syncShoppingListFromInventory()
            return
        }
        shoppingList = ShoppingListFixtures.demo
    }

    /// REQ-011: low-stock inventory rows auto-appear on the list (no approval).
    func syncShoppingListFromInventory() {
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
        let name = shoppingList[idx].name
        if shoppingList[idx].isChecked {
            logActivity("Purchased \(name)", kind: .success)
        }
    }

    func addCustomShoppingItem(name: String, quantity: Int) {
        shoppingList.insert(
            ShoppingListItem(name: name, quantity: max(1, quantity), kind: .custom),
            at: 0
        )
        logActivity("Added \(name) to list", kind: .success)
    }

    func approveShoppingRequest(id: String) {
        guard let idx = shoppingList.firstIndex(where: { $0.id == id }) else { return }
        shoppingList[idx].needsApproval = false
        shoppingList[idx].kind = .custom
        logActivity("Approved \(shoppingList[idx].name)", kind: .success)
    }

    func rejectShoppingRequest(id: String) {
        guard let idx = shoppingList.firstIndex(where: { $0.id == id }) else { return }
        let name = shoppingList[idx].name
        shoppingList.remove(at: idx)
        logActivity("Denied \(name)", kind: .warning)
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
