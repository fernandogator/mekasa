import Foundation

/// Fixed, deterministic fixtures for UI tests and `--uitesting` mode.
/// Satisfies: UI-001–UI-005
/// Spec version: 1.0
enum TestFixtures {
    /// Fixed calendar instant — never use `Date()` in fixtures.
    static let fixedDate: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 1
        components.day = 15
        components.hour = 12
        components.minute = 0
        components.second = 0
        return components.date ?? Date(timeIntervalSince1970: 1_768_478_400)
    }()

    // MARK: - InventoryItem

    static let standardItemList: [InventoryItem] = [
        InventoryItem(
            id: "inv-1",
            name: "Organic Oat Milk",
            category: InventoryCategory.dairy.rawValue,
            quantity: 2,
            lowStockThreshold: 1,
            pricePaid: 4.99,
            barcode: "012345678905",
            source: .barcode,
            imageURL: "https://placehold.co/400x400/eeebe3/171e19/png?text=Dairy",
            updatedAt: fixedDate
        ),
        InventoryItem(
            id: "inv-2",
            name: "Bananas",
            category: InventoryCategory.produce.rawValue,
            quantity: 6,
            lowStockThreshold: 2,
            pricePaid: 1.29,
            barcode: nil,
            source: .manual,
            imageURL: "https://placehold.co/400x400/eeebe3/171e19/png?text=Produce",
            updatedAt: fixedDate
        ),
        InventoryItem(
            id: "inv-3",
            name: "Cheerios 12oz",
            category: InventoryCategory.pantry.rawValue,
            quantity: 1,
            lowStockThreshold: 1,
            pricePaid: 3.49,
            barcode: "041220576037",
            source: .barcode,
            imageURL: "https://placehold.co/400x400/eeebe3/171e19/png?text=Pantry",
            updatedAt: fixedDate
        ),
        InventoryItem(
            id: "inv-4",
            name: "Chicken Breast",
            category: InventoryCategory.meat.rawValue,
            quantity: 1,
            lowStockThreshold: 1,
            pricePaid: 8.50,
            barcode: nil,
            source: .receipt,
            imageURL: "https://placehold.co/400x400/eeebe3/171e19/png?text=Meat",
            updatedAt: fixedDate
        ),
        InventoryItem(
            id: "inv-5",
            name: "Frozen Peas",
            category: InventoryCategory.frozen.rawValue,
            quantity: 3,
            lowStockThreshold: 1,
            pricePaid: 2.19,
            barcode: nil,
            source: .manual,
            imageURL: "https://placehold.co/400x400/eeebe3/171e19/png?text=Frozen",
            updatedAt: fixedDate
        ),
        InventoryItem(
            id: "inv-6",
            name: "Diet Coke Soft Drink",
            category: InventoryCategory.beverages.rawValue,
            quantity: 1,
            lowStockThreshold: 1,
            pricePaid: 7.99,
            barcode: "049000028911",
            source: .barcode,
            // Live Open Food Facts front image for UPC 049000028911 (sample verified 2026-09-12)
            imageURL: "https://images.openfoodfacts.org/images/products/004/900/002/8911/front_en.24.400.jpg",
            updatedAt: fixedDate
        ),
        InventoryItem(
            id: "inv-7",
            name: "Paper Towels",
            category: InventoryCategory.household.rawValue,
            quantity: 1,
            lowStockThreshold: 1,
            pricePaid: 12.00,
            barcode: nil,
            source: .manual,
            imageURL: "https://placehold.co/400x400/eeebe3/171e19/png?text=Household",
            updatedAt: fixedDate
        ),
    ]

    static let emptyItemList: [InventoryItem] = []

    static let singleItem: [InventoryItem] = [
        InventoryItem(
            id: "inv-single",
            name: "Demo Pasta Box",
            category: InventoryCategory.pantry.rawValue,
            quantity: 1,
            lowStockThreshold: 1,
            pricePaid: 2.50,
            barcode: "000000000001",
            source: .barcode,
            imageURL: "https://placehold.co/400x400/eeebe3/171e19/png?text=Pantry",
            updatedAt: fixedDate
        ),
    ]

    // MARK: - PendingRequest / ShoppingListItem

    static let standardPendingRequests: [PendingRequest] = [
        PendingRequest(id: "req-1", itemName: "Oat Milk", requestedBy: "Leo", quantity: 1),
        PendingRequest(id: "req-2", itemName: "Oreos", requestedBy: "Mia", quantity: 2),
        PendingRequest(id: "req-3", itemName: "Paper towels", requestedBy: "Maya", quantity: 1),
    ]

    static let emptyPendingRequests: [PendingRequest] = []

    static let singlePendingRequest: [PendingRequest] = [
        PendingRequest(id: "req-single", itemName: "Eggs", requestedBy: "Sam", quantity: 1),
    ]

    static let standardShoppingList: [ShoppingListItem] = [
        ShoppingListItem(
            id: "shop-1",
            name: "2% milk",
            quantity: 2,
            quantityLabel: "×2",
            isChecked: true,
            kind: .auto
        ),
        ShoppingListItem(
            id: "shop-2",
            name: "Paper towels",
            quantity: 1,
            needsApproval: true,
            requestedBy: "Maya",
            kind: .request
        ),
        ShoppingListItem(
            id: "shop-3",
            name: "Eggs",
            quantity: 1,
            quantityLabel: "×1 dozen",
            kind: .auto
        ),
        ShoppingListItem(
            id: "shop-4",
            name: "Avocados",
            quantity: 4,
            kind: .custom
        ),
        ShoppingListItem(
            id: "shop-5",
            name: "Dish soap",
            quantity: 1,
            quantityLabel: "",
            kind: .custom
        ),
    ]

    static let emptyShoppingList: [ShoppingListItem] = []

    static let singleShoppingItem: [ShoppingListItem] = [
        ShoppingListItem(id: "shop-single", name: "Bread", quantity: 1, kind: .custom),
    ]

    // MARK: - HouseholdMember

    static let standardMembers: [HouseholdMember] = [
        HouseholdMember(id: "mem-1", name: "Alex Owner", email: "alex@mekasa.local", role: .owner),
        HouseholdMember(id: "mem-2", name: "Leo", email: "leo@mekasa.local", role: .member),
        HouseholdMember(id: "mem-3", name: "Mia", email: "mia@mekasa.local", role: .member),
        HouseholdMember(id: "mem-4", name: "Maya", email: "maya@mekasa.local", role: .child),
        HouseholdMember(id: "mem-5", name: "Sam", email: "sam@mekasa.local", role: .member),
    ]

    static let emptyMembers: [HouseholdMember] = []

    static let singleMember: [HouseholdMember] = [
        HouseholdMember(id: "mem-single", name: "Solo Owner", email: "solo@mekasa.local", role: .owner),
    ]

    // MARK: - TrashEvent

    static let standardTrashEvents: [TrashEvent] = [
        TrashEvent(id: "trash-1", itemName: "Eggs", quantityDelta: -1, scannedAt: "2026-01-15T12:00:00Z"),
        TrashEvent(id: "trash-2", itemName: "Milk", quantityDelta: -1, scannedAt: "2026-01-15T11:30:00Z"),
        TrashEvent(id: "trash-3", itemName: "Bread", quantityDelta: -1, scannedAt: "2026-01-14T18:00:00Z"),
    ]

    static let emptyTrashEvents: [TrashEvent] = []

    static let singleTrashEvent: [TrashEvent] = [
        TrashEvent(id: "trash-single", itemName: "Pasta", quantityDelta: -1, scannedAt: "2026-01-15T09:00:00Z"),
    ]

    static let previewHousehold = Household(
        id: "uitest-household",
        name: "The Test House",
        photoURL: nil,
        ownerUID: "uitest-user",
        address: "100 Test St",
        latitude: 30.27,
        longitude: -97.74,
        storeIDs: ["stub-heb"],
        createdAt: fixedDate,
        updatedAt: fixedDate
    )
}

/// Pending child / member request shown in request queues.
struct PendingRequest: Identifiable, Equatable, Hashable {
    let id: String
    var itemName: String
    var requestedBy: String
    var quantity: Int
}

/// Household member row for settings / family UI.
struct HouseholdMember: Identifiable, Equatable, Hashable {
    enum Role: String, Equatable, Hashable {
        case owner
        case member
        case child
    }

    let id: String
    var name: String
    var email: String
    var role: Role
}

/// Recent trash-station dispose event.
struct TrashEvent: Identifiable, Equatable, Hashable {
    let id: String
    var itemName: String
    var quantityDelta: Int
    /// ISO-8601 fixed string — never compute at runtime.
    var scannedAt: String
}
