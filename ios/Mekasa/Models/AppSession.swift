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

    var isSignedIn: Bool { idToken != nil }

    var lowStockCount: Int {
        let live = inventory.filter(\.isLowStock).count
        if inventory.isEmpty { return DashboardFixtures.lowStockCount }
        return live
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
