import Foundation

/// Satisfies: REQ-001, REQ-002, REQ-003
/// Spec version: 1.0
struct Household: Codable, Identifiable, Equatable {
    let id: String
    var name: String?
    var photoURL: String?
    let ownerUID: String
    var address: String?
    var latitude: Double?
    var longitude: Double?
    var storeIDs: [String]
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, address, latitude, longitude
        case photoURL = "photo_url"
        case ownerUID = "owner_uid"
        case storeIDs = "store_ids"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: String,
        name: String?,
        photoURL: String?,
        ownerUID: String,
        address: String?,
        latitude: Double?,
        longitude: Double?,
        storeIDs: [String],
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.id = id
        self.name = name
        self.photoURL = photoURL
        self.ownerUID = ownerUID
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.storeIDs = storeIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        photoURL = try c.decodeIfPresent(String.self, forKey: .photoURL)
        ownerUID = try c.decode(String.self, forKey: .ownerUID)
        address = try c.decodeIfPresent(String.self, forKey: .address)
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        storeIDs = try c.decodeIfPresent([String].self, forKey: .storeIDs) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

struct Store: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let distanceMiles: Double
    let provider: String

    enum CodingKeys: String, CodingKey {
        case id, name, address, latitude, longitude, provider
        case distanceMiles = "distance_miles"
    }
}

struct StoreSearchResponse: Codable {
    let householdId: String
    let radiusMiles: Double
    let stores: [Store]

    enum CodingKeys: String, CodingKey {
        case stores
        case householdId = "household_id"
        case radiusMiles = "radius_miles"
    }
}

struct UserProfile: Codable {
    let uid: String
    let email: String?
    let name: String?
}

/// API inventory item (snake_case JSON from Cloud Run).
/// Satisfies: REQ-004–REQ-009
/// Spec version: 1.0
struct InventoryItemDTO: Codable, Equatable, Identifiable {
    let id: String
    let householdId: String
    let name: String
    let category: String
    let quantity: Int
    let lowStockThreshold: Int
    let pricePaid: Double?
    let barcode: String?
    let source: String
    let createdByUid: String?
    let updatedByUid: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, category, quantity, barcode, source
        case householdId = "household_id"
        case lowStockThreshold = "low_stock_threshold"
        case pricePaid = "price_paid"
        case createdByUid = "created_by_uid"
        case updatedByUid = "updated_by_uid"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func toLocal() -> InventoryItem {
        InventoryItem(
            id: id,
            name: name,
            category: category,
            quantity: quantity,
            lowStockThreshold: lowStockThreshold,
            pricePaid: pricePaid,
            barcode: barcode,
            source: InventorySource(rawValue: source) ?? .manual,
            updatedAt: updatedAt ?? Date()
        )
    }
}

struct InventoryListResponse: Codable {
    let householdId: String
    let items: [InventoryItemDTO]

    enum CodingKeys: String, CodingKey {
        case items
        case householdId = "household_id"
    }
}

struct InventoryItemCreateBody: Encodable {
    let name: String
    let category: String
    let quantity: Int
    let lowStockThreshold: Int
    let pricePaid: Double?
    let barcode: String?
    let source: String

    enum CodingKeys: String, CodingKey {
        case name, category, quantity, barcode, source
        case lowStockThreshold = "low_stock_threshold"
        case pricePaid = "price_paid"
    }

    init(from item: InventoryItem) {
        name = item.name
        category = item.category
        quantity = item.quantity
        lowStockThreshold = item.lowStockThreshold
        pricePaid = item.pricePaid
        barcode = item.barcode
        source = item.source.rawValue
    }
}

