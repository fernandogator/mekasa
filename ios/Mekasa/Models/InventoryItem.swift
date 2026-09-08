import Foundation

/// Household inventory item (local cache of API / Firestore rows).
/// Satisfies: REQ-004–REQ-008
/// Spec version: 1.0
struct InventoryItem: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var category: String
    var quantity: Int
    var lowStockThreshold: Int
    var pricePaid: Double?
    var barcode: String?
    var source: InventorySource
    var imageURL: String?
    var updatedAt: Date

    var isLowStock: Bool { quantity <= lowStockThreshold }

    init(
        id: String = UUID().uuidString,
        name: String,
        category: String,
        quantity: Int = 1,
        lowStockThreshold: Int = 1,
        pricePaid: Double? = nil,
        barcode: String? = nil,
        source: InventorySource,
        imageURL: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.quantity = quantity
        self.lowStockThreshold = lowStockThreshold
        self.pricePaid = pricePaid
        self.barcode = barcode
        self.source = source
        self.imageURL = imageURL
        self.updatedAt = updatedAt
    }
}

enum InventorySource: String, Equatable, Hashable {
    case manual
    case barcode
    case receipt
    case voice
}

enum InventoryCategory: String, CaseIterable, Identifiable {
    case produce = "Produce"
    case dairy = "Dairy"
    case pantry = "Pantry"
    case meat = "Meat"
    case frozen = "Frozen"
    case beverages = "Beverages"
    case household = "Household"
    case other = "Other"

    var id: String { rawValue }
}

enum InventoryDemoCatalog {
    /// Demo UPC lookup until third-party barcode API is wired (REQ-004).
    static func lookup(barcode: String) -> InventoryItem? {
        let known: [String: (String, String)] = [
            "012345678905": ("Organic Oat Milk", InventoryCategory.dairy.rawValue),
            "041220576037": ("Cheerios 12oz", InventoryCategory.pantry.rawValue),
            "000000000001": ("Demo Pasta Box", InventoryCategory.pantry.rawValue),
        ]
        guard let hit = known[barcode] else { return nil }
        return InventoryItem(
            name: hit.0,
            category: hit.1,
            quantity: 1,
            barcode: barcode,
            source: .barcode
        )
    }

    static let sampleBarcode = "012345678905"

    static let sampleReceiptLines: [(String, String, Double)] = [
        ("Bananas", InventoryCategory.produce.rawValue, 1.29),
        ("Whole Milk", InventoryCategory.dairy.rawValue, 3.49),
        ("Sourdough Loaf", InventoryCategory.pantry.rawValue, 4.99),
    ]
}
