import Foundation

/// Local fixtures for DEBUG UI preview and unit tests.
enum PreviewFixtures {
    static func household(name: String? = "The Rivas House") -> Household {
        Household(
            id: "preview-household",
            name: name,
            photoURL: nil,
            ownerUID: "preview-user",
            address: nil,
            latitude: nil,
            longitude: nil,
            storeIDs: [],
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    static let nearbyStores: [Store] = [
        Store(
            id: "stub-heb",
            name: "H-E-B",
            address: "100 Main St",
            latitude: 30.27,
            longitude: -97.74,
            distanceMiles: 0.8,
            provider: "stub"
        ),
        Store(
            id: "stub-costco",
            name: "Costco",
            address: "200 Warehouse Blvd",
            latitude: 30.25,
            longitude: -97.70,
            distanceMiles: 4.2,
            provider: "stub"
        ),
        Store(
            id: "stub-kroger",
            name: "Kroger",
            address: "300 Market Ave",
            latitude: 30.28,
            longitude: -97.75,
            distanceMiles: 2.1,
            provider: "stub"
        ),
        Store(
            id: "stub-walmart",
            name: "Walmart Supercenter",
            address: "400 Retail Rd",
            latitude: 30.22,
            longitude: -97.78,
            distanceMiles: 6.7,
            provider: "stub"
        ),
        Store(
            id: "stub-target",
            name: "Target",
            address: "500 Circle Dr",
            latitude: 30.26,
            longitude: -97.72,
            distanceMiles: 5.4,
            provider: "stub"
        ),
    ]
}
