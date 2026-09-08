import Foundation

/// HTTP client for the Mekasa Cloud Run API.
/// Satisfies: REQ-001–REQ-009, NFR-002
/// Spec version: 1.0
actor MekasaAPIClient {
    static let shared = MekasaAPIClient()

    /// Production Cloud Run service.
    var baseURL = URL(string: "https://mekasa-api-934775015882.us-central1.run.app")!

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.mekasaFractional.date(from: value)
                ?? ISO8601DateFormatter.mekasa.date(from: value)
            {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(value)"
            )
        }
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    func health() async throws -> [String: String] {
        let (data, _) = try await rawRequest(path: "/health", method: "GET", token: nil, body: nil as String?)
        return try JSONSerialization.jsonObject(with: data) as? [String: String] ?? [:]
    }

    func me(token: String) async throws -> UserProfile {
        try await request(path: "/v1/me", method: "GET", token: token)
    }

    func createHousehold(name: String?, photoURL: String?, token: String) async throws -> Household {
        struct Body: Encodable {
            let name: String?
            let photo_url: String?
        }
        return try await request(
            path: "/v1/households",
            method: "POST",
            token: token,
            body: Body(name: name, photo_url: photoURL)
        )
    }

    func currentHousehold(token: String) async throws -> Household {
        try await request(path: "/v1/households/current", method: "GET", token: token)
    }

    func updateAddress(
        householdID: String,
        address: String,
        latitude: Double?,
        longitude: Double?,
        token: String
    ) async throws -> Household {
        struct Body: Encodable {
            let address: String
            let latitude: Double?
            let longitude: Double?
        }
        return try await request(
            path: "/v1/households/\(householdID)/address",
            method: "PUT",
            token: token,
            body: Body(address: address, latitude: latitude, longitude: longitude)
        )
    }

    func nearbyStores(householdID: String, token: String) async throws -> StoreSearchResponse {
        try await request(
            path: "/v1/households/\(householdID)/stores/nearby",
            method: "GET",
            token: token
        )
    }

    func selectStores(householdID: String, storeIDs: [String], token: String) async throws -> Household {
        struct Body: Encodable {
            let store_ids: [String]
        }
        return try await request(
            path: "/v1/households/\(householdID)/stores",
            method: "PUT",
            token: token,
            body: Body(store_ids: storeIDs)
        )
    }

    // MARK: - Inventory (REQ-004–REQ-009)

    func listInventory(householdID: String, token: String) async throws -> InventoryListResponse {
        try await request(
            path: "/v1/households/\(householdID)/inventory",
            method: "GET",
            token: token
        )
    }

    func createInventoryItem(
        householdID: String,
        item: InventoryItem,
        token: String
    ) async throws -> InventoryItemDTO {
        try await request(
            path: "/v1/households/\(householdID)/inventory",
            method: "POST",
            token: token,
            body: InventoryItemCreateBody(from: item)
        )
    }

    func getInventoryItem(
        householdID: String,
        itemID: String,
        token: String
    ) async throws -> InventoryItemDTO {
        try await request(
            path: "/v1/households/\(householdID)/inventory/\(itemID)",
            method: "GET",
            token: token
        )
    }

    func updateInventoryItem(
        householdID: String,
        itemID: String,
        quantity: Int? = nil,
        lowStockThreshold: Int? = nil,
        name: String? = nil,
        category: String? = nil,
        pricePaid: Double? = nil,
        barcode: String? = nil,
        token: String
    ) async throws -> InventoryItemDTO {
        struct Body: Encodable {
            let name: String?
            let category: String?
            let quantity: Int?
            let low_stock_threshold: Int?
            let price_paid: Double?
            let barcode: String?
        }
        return try await request(
            path: "/v1/households/\(householdID)/inventory/\(itemID)",
            method: "PATCH",
            token: token,
            body: Body(
                name: name,
                category: category,
                quantity: quantity,
                low_stock_threshold: lowStockThreshold,
                price_paid: pricePaid,
                barcode: barcode
            )
        )
    }

    func deleteInventoryItem(householdID: String, itemID: String, token: String) async throws {
        _ = try await rawRequest(
            path: "/v1/households/\(householdID)/inventory/\(itemID)",
            method: "DELETE",
            token: token,
            body: nil as String?
        )
    }

    func consumeInventoryItem(
        householdID: String,
        itemID: String,
        amount: Int = 1,
        token: String
    ) async throws -> InventoryItemDTO {
        struct Body: Encodable {
            let amount: Int
        }
        return try await request(
            path: "/v1/households/\(householdID)/inventory/\(itemID)/consume",
            method: "POST",
            token: token,
            body: Body(amount: amount)
        )
    }

    func consumeInventoryByBarcode(
        householdID: String,
        barcode: String,
        amount: Int = 1,
        token: String
    ) async throws -> InventoryItemDTO {
        struct Body: Encodable {
            let barcode: String
            let amount: Int
        }
        return try await request(
            path: "/v1/households/\(householdID)/inventory/consume-by-barcode",
            method: "POST",
            token: token,
            body: Body(barcode: barcode, amount: amount)
        )
    }

    private func request<T: Decodable, B: Encodable>(
        path: String,
        method: String,
        token: String?,
        body: B? = nil
    ) async throws -> T {
        let (data, _) = try await rawRequest(path: path, method: method, token: token, body: body)
        return try decoder.decode(T.self, from: data)
    }

    private func request<T: Decodable>(path: String, method: String, token: String?) async throws -> T {
        let (data, _) = try await rawRequest(path: path, method: method, token: token, body: nil as String?)
        return try decoder.decode(T.self, from: data)
    }

    private func rawRequest<B: Encodable>(
        path: String,
        method: String,
        token: String?,
        body: B?
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw APIError.server(status: http.statusCode, detail: detail)
        }
        return (data, http)
    }
}

private extension ISO8601DateFormatter {
    static let mekasa: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static let mekasaFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

enum APIError: LocalizedError {
    case invalidResponse
    case server(status: Int, detail: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from server"
        case let .server(_, detail): return detail
        }
    }
}
