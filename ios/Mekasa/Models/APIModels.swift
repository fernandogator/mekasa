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
