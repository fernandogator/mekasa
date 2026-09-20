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
    let imageURL: String?
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
        case imageURL = "image_url"
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
            imageURL: imageURL,
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
    let imageURL: String?
    let source: String

    enum CodingKeys: String, CodingKey {
        case name, category, quantity, barcode, source
        case lowStockThreshold = "low_stock_threshold"
        case pricePaid = "price_paid"
        case imageURL = "image_url"
    }

    init(from item: InventoryItem) {
        name = item.name
        category = item.category
        quantity = item.quantity
        lowStockThreshold = item.lowStockThreshold
        pricePaid = item.pricePaid
        barcode = item.barcode
        imageURL = item.imageURL
        source = item.source.rawValue
    }
}

/// API shopping list row (snake_case JSON from Cloud Run).
/// Satisfies: REQ-011–REQ-014
/// Spec version: 1.0
struct ShoppingListItemDTO: Codable, Equatable, Identifiable {
    let id: String
    let householdId: String
    let name: String
    let quantity: Int
    let quantityLabel: String?
    let isChecked: Bool
    let needsApproval: Bool
    let requestedBy: String?
    let inventoryItemId: String?
    let kind: String
    let createdByUid: String?
    let updatedByUid: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, kind
        case householdId = "household_id"
        case quantityLabel = "quantity_label"
        case isChecked = "is_checked"
        case needsApproval = "needs_approval"
        case requestedBy = "requested_by"
        case inventoryItemId = "inventory_item_id"
        case createdByUid = "created_by_uid"
        case updatedByUid = "updated_by_uid"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func toLocal() -> ShoppingListItem {
        ShoppingListItem(
            id: id,
            name: name,
            quantity: quantity,
            quantityLabel: quantityLabel,
            isChecked: isChecked,
            needsApproval: needsApproval,
            requestedBy: requestedBy,
            inventoryItemID: inventoryItemId,
            kind: ShoppingListItem.Kind(rawValue: kind) ?? .custom
        )
    }
}

struct ShoppingListAPIResponse: Codable {
    let householdId: String
    let items: [ShoppingListItemDTO]

    enum CodingKeys: String, CodingKey {
        case items
        case householdId = "household_id"
    }
}

struct ShoppingListSyncAPIResponse: Codable {
    let householdId: String
    let added: [ShoppingListItemDTO]
    let items: [ShoppingListItemDTO]

    enum CodingKeys: String, CodingKey {
        case added, items
        case householdId = "household_id"
    }
}

struct ShoppingListItemCreateBody: Encodable {
    let name: String
    let quantity: Int
    let quantityLabel: String?
    let isChecked: Bool
    let needsApproval: Bool
    let requestedBy: String?
    let inventoryItemId: String?
    let kind: String

    enum CodingKeys: String, CodingKey {
        case name, quantity, kind
        case quantityLabel = "quantity_label"
        case isChecked = "is_checked"
        case needsApproval = "needs_approval"
        case requestedBy = "requested_by"
        case inventoryItemId = "inventory_item_id"
    }

    init(from item: ShoppingListItem) {
        name = item.name
        quantity = item.quantity
        quantityLabel = item.quantityLabel
        isChecked = item.isChecked
        needsApproval = item.needsApproval
        requestedBy = item.requestedBy
        inventoryItemId = item.inventoryItemID
        kind = item.kind.rawValue
    }
}

/// Open Food Facts barcode lookup result.
/// Satisfies: REQ-004
/// Spec version: 1.0
struct BarcodeLookupDTO: Codable, Equatable {
    let barcode: String
    let found: Bool
    let name: String?
    let brand: String?
    let category: String?
    let quantity: Int
    let imageUrl: String?
    let source: String

    enum CodingKeys: String, CodingKey {
        case barcode, found, name, brand, category, quantity, source
        case imageUrl = "image_url"
    }
}

struct ProductSearchHitDTO: Codable, Equatable, Identifiable {
    var id: String { barcode ?? name }
    let barcode: String?
    let name: String
    let brand: String?
    let category: String
    let imageUrl: String?
    let source: String

    enum CodingKeys: String, CodingKey {
        case barcode, name, brand, category, source
        case imageUrl = "image_url"
    }

    func toDraft(
        quantity: Int = 1,
        pricePaid: Double? = nil,
        source: InventorySource = .manual
    ) -> InventoryItem {
        InventoryItem(
            name: name,
            category: category,
            quantity: quantity,
            pricePaid: pricePaid,
            barcode: barcode,
            source: source,
            imageURL: imageUrl
        )
    }
}

struct ProductSearchResponseDTO: Codable, Equatable {
    let query: String
    let results: [ProductSearchHitDTO]
}

struct DeviceRegistrationDTO: Codable, Equatable, Identifiable {
    let id: String
    let uid: String
    let fcmToken: String
    let platform: String
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, uid, platform
        case fcmToken = "fcm_token"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Consume-by-barcode result (REQ-008).
struct ConsumeByBarcodeResultDTO: Codable, Equatable {
    let found: Bool
    let item: InventoryItemDTO?
    let unknownEvent: UnknownBarcodeEventDTO?

    enum CodingKeys: String, CodingKey {
        case found, item
        case unknownEvent = "unknown_event"
    }
}

struct UnknownBarcodeEventDTO: Codable, Equatable, Identifiable {
    let id: String
    let householdId: String
    let barcode: String
    let scannedByUid: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, barcode
        case householdId = "household_id"
        case scannedByUid = "scanned_by_uid"
        case createdAt = "created_at"
    }
}

struct ReceiptLineItemDTO: Codable, Equatable {
    let name: String
    let category: String
    let quantity: Int
    let pricePaid: Double?
    let barcode: String?
    let imageUrl: String?
    let identified: Bool

    enum CodingKeys: String, CodingKey {
        case name, category, quantity, barcode, identified
        case pricePaid = "price_paid"
        case imageUrl = "image_url"
    }

    init(
        name: String,
        category: String,
        quantity: Int,
        pricePaid: Double?,
        barcode: String? = nil,
        imageUrl: String? = nil,
        identified: Bool = false
    ) {
        self.name = name
        self.category = category
        self.quantity = quantity
        self.pricePaid = pricePaid
        self.barcode = barcode
        self.imageUrl = imageUrl
        self.identified = identified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        quantity = try container.decode(Int.self, forKey: .quantity)
        pricePaid = try container.decodeIfPresent(Double.self, forKey: .pricePaid)
        barcode = try container.decodeIfPresent(String.self, forKey: .barcode)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        identified = try container.decodeIfPresent(Bool.self, forKey: .identified) ?? false
    }

    func toLocal() -> InventoryItem {
        InventoryItem(
            name: name,
            category: category,
            quantity: quantity,
            pricePaid: pricePaid,
            barcode: barcode,
            source: .receipt,
            imageURL: imageUrl,
            isIdentified: identified
        )
    }
}

struct ReceiptScanResponseDTO: Codable, Equatable {
    let householdId: String
    let engine: String
    let items: [ReceiptLineItemDTO]

    enum CodingKeys: String, CodingKey {
        case engine, items
        case householdId = "household_id"
    }
}

struct HouseholdMemberDTO: Codable, Equatable, Identifiable {
    var id: String { uid }
    let uid: String
    let householdId: String
    let name: String?
    let email: String?
    let phone: String?
    let role: String
    let status: String
    let permissions: [String]

    enum CodingKeys: String, CodingKey {
        case uid, name, email, phone, role, status, permissions
        case householdId = "household_id"
    }

    init(
        uid: String,
        householdId: String,
        name: String?,
        email: String?,
        phone: String?,
        role: String,
        status: String,
        permissions: [String] = []
    ) {
        self.uid = uid
        self.householdId = householdId
        self.name = name
        self.email = email
        self.phone = phone
        self.role = role
        self.status = status
        self.permissions = permissions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decode(String.self, forKey: .uid)
        householdId = try container.decode(String.self, forKey: .householdId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        role = try container.decode(String.self, forKey: .role)
        status = try container.decode(String.self, forKey: .status)
        permissions = try container.decodeIfPresent([String].self, forKey: .permissions) ?? []
    }
}

struct HouseholdMembersResponseDTO: Codable, Equatable {
    let householdId: String
    let members: [HouseholdMemberDTO]

    enum CodingKeys: String, CodingKey {
        case members
        case householdId = "household_id"
    }
}

struct HouseholdInviteDTO: Codable, Equatable, Identifiable {
    let id: String
    let householdId: String
    let name: String
    let email: String?
    let phone: String?
    let role: String
    let token: String
    let status: String
    let inviteLink: String?

    enum CodingKeys: String, CodingKey {
        case id, name, email, phone, role, token, status
        case householdId = "household_id"
        case inviteLink = "invite_link"
    }

    /// App deep link preferred for share sheet; falls back to API https link.
    var shareURL: URL? {
        if let url = URL(string: "mekasa://invite?token=\(token)") {
            return url
        }
        return inviteLink.flatMap(URL.init(string:))
    }
}

struct HouseholdInvitesResponseDTO: Codable, Equatable {
    let householdId: String
    let invites: [HouseholdInviteDTO]

    enum CodingKeys: String, CodingKey {
        case invites
        case householdId = "household_id"
    }
}

// MARK: - Spending (REQ-015, REQ-017, REQ-018)

enum SpendingPeriod: String, Codable, Equatable, CaseIterable {
    case week
    case month
    case year
}

struct PurchaseEventDTO: Codable, Equatable, Identifiable {
    let id: String
    let householdId: String
    let name: String
    let category: String
    let pricePaid: Double
    let quantity: Int
    let storeId: String?
    let inventoryItemId: String?
    let source: String
    let purchasedAt: Date?
    let createdByUid: String
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, category, quantity, source
        case householdId = "household_id"
        case pricePaid = "price_paid"
        case storeId = "store_id"
        case inventoryItemId = "inventory_item_id"
        case purchasedAt = "purchased_at"
        case createdByUid = "created_by_uid"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var lineTotal: Double { pricePaid * Double(max(quantity, 1)) }
}

struct SpendingCategoryTotalDTO: Codable, Equatable, Identifiable {
    var id: String { category }
    let category: String
    let total: Double
}

struct SpendingReportDTO: Codable, Equatable {
    let householdId: String
    let period: SpendingPeriod
    let currency: String
    let total: Double
    let byCategory: [SpendingCategoryTotalDTO]
    let events: [PurchaseEventDTO]

    enum CodingKeys: String, CodingKey {
        case period, currency, total, events
        case householdId = "household_id"
        case byCategory = "by_category"
    }
}


