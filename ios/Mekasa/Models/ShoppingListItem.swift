import Foundation

/// Local shopping list row until backend list APIs exist.
/// Satisfies: REQ-011–REQ-014 (client-side staging)
/// Spec version: 1.0
struct ShoppingListItem: Identifiable, Equatable, Hashable {
    enum Kind: String, Equatable, Hashable {
        case auto
        case custom
        case request
    }

    let id: String
    var name: String
    var quantity: Int
    var quantityLabel: String?
    var isChecked: Bool
    var needsApproval: Bool
    var requestedBy: String?
    var inventoryItemID: String?
    var kind: Kind

    init(
        id: String = UUID().uuidString,
        name: String,
        quantity: Int = 1,
        quantityLabel: String? = nil,
        isChecked: Bool = false,
        needsApproval: Bool = false,
        requestedBy: String? = nil,
        inventoryItemID: String? = nil,
        kind: Kind = .custom
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.quantityLabel = quantityLabel
        self.isChecked = isChecked
        self.needsApproval = needsApproval
        self.requestedBy = requestedBy
        self.inventoryItemID = inventoryItemID
        self.kind = kind
    }

    var displayQuantity: String {
        if let quantityLabel {
            return quantityLabel
        }
        return "×\(quantity)"
    }
}

enum ShoppingListFixtures {
    static let demo: [ShoppingListItem] = [
        ShoppingListItem(name: "2% milk", quantity: 2, isChecked: true, kind: .auto),
        ShoppingListItem(
            name: "Paper towels",
            quantity: 1,
            needsApproval: true,
            requestedBy: "Maya",
            kind: .request
        ),
        ShoppingListItem(name: "Eggs", quantity: 1, quantityLabel: "×1 dozen", kind: .auto),
        ShoppingListItem(name: "Avocados", quantity: 4, kind: .custom),
        ShoppingListItem(name: "Dish soap", quantity: 1, quantityLabel: "", kind: .custom),
    ]
}
