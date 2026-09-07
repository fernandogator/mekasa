import Foundation

/// Local dashboard fixtures until inventory / spending APIs exist.
/// Satisfies: UI-004 (Home Dashboard)
/// Spec version: 1.0
struct ApprovalRequest: Identifiable, Equatable {
    let id: String
    let itemName: String
    let requestedBy: String
    let symbolName: String
}

struct ActivityItem: Identifiable, Equatable {
    enum Kind {
        case warning
        case success
    }

    let id: String
    let title: String
    let when: String
    let kind: Kind
}

enum DashboardFixtures {
    static let lowStockCount = 12
    static let weeklySpend = 430

    static let approvals: [ApprovalRequest] = [
        ApprovalRequest(id: "a1", itemName: "Oat Milk", requestedBy: "Leo", symbolName: "carton.fill"),
        ApprovalRequest(id: "a2", itemName: "Oreos", requestedBy: "Mia", symbolName: "circle.grid.2x2.fill"),
    ]

    static let activity: [ActivityItem] = [
        ActivityItem(id: "act1", title: "Eggs marked as depleted", when: "2 hours ago", kind: .warning),
        ActivityItem(id: "act2", title: "H-E-B run completed", when: "Yesterday", kind: .success),
    ]
}

enum MainTab: Int, CaseIterable, Identifiable {
    case home
    case list
    case spend
    case family

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .list: return "List"
        case .spend: return "Spend"
        case .family: return "Family"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .list: return "checklist"
        case .spend: return "chart.pie.fill"
        case .family: return "person.2.fill"
        }
    }
}
