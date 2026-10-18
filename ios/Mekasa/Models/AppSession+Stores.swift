import Foundation

/// What the store picker should show after loading.
/// Satisfies: REQ-003 AC10, AC11
/// Spec version: 1.0
enum StorePickerLoadResult: Equatable {
    /// Rows to pick from, plus the ids Google Places returned (for the "Places" badge).
    case stores([SavedStore], placesIDs: Set<String>)
    /// The household has no coordinates yet: ask for the home address first.
    case needsLocation
    case failed
}

/// Store picker and saved stores (onboarding store step and Family → Grocery stores).
/// Satisfies: REQ-003 AC4–AC7, AC10, AC11
/// Spec version: 1.0
extension AppSession {
    /// Loads nearby stores plus the saved ones the search no longer returns.
    /// Satisfies: REQ-003 AC4, AC10, AC11
    /// Spec version: 1.0
    func loadStorePicker() async -> StorePickerLoadResult {
        guard let household else { return .failed }
        guard household.hasCoordinates else { return .needsLocation }
        if isUIPreview {
            return .stores(
                ShoppingStores.pickerStores(nearby: PreviewFixtures.nearbyStores, saved: household.stores),
                placesIDs: []
            )
        }
        guard let token = idToken else {
            showError("Not signed in.")
            return .failed
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let response = try await MekasaAPIClient.shared.nearbyStores(householdID: household.id, token: token)
            if response.needsLocation { return .needsLocation }
            let places = Set(response.stores.filter { $0.provider == "places" }.map(\.id))
            return .stores(
                ShoppingStores.pickerStores(nearby: response.stores, saved: household.stores),
                placesIDs: places
            )
        } catch {
            handleAPIFailure(error)
            return .failed
        }
    }

    /// Saves the home address so the API can look up its coordinates. Returns nil on
    /// success, else the message the picker shows (address not found, or the API error).
    /// Satisfies: REQ-003 AC3, AC7, AC11
    /// Spec version: 1.0
    func saveHomeAddressForStoreSearch(_ address: String) async -> String? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Enter your home address." }
        guard var current = household else { return "Missing household." }
        if isUIPreview {
            current.address = trimmed
            current.latitude = current.latitude ?? 30.2672
            current.longitude = current.longitude ?? -97.7431
            household = current
            return nil
        }
        guard let token = idToken else { return "Not signed in." }
        isBusy = true
        defer { isBusy = false }
        do {
            let updated = try await MekasaAPIClient.shared.updateAddress(
                householdID: current.id,
                address: trimmed,
                latitude: nil,
                longitude: nil,
                token: token
            )
            household = updated
            return updated.hasCoordinates ? nil : ShoppingStores.addressNotFound
        } catch {
            handleAPIFailure(error)
            return error.localizedDescription
        }
    }

    /// Saves the selected stores with their details and updates `household`.
    /// Satisfies: REQ-003 AC5, AC6, AC11
    /// Spec version: 1.0
    func saveStores(_ stores: [SavedStore]) async -> Bool {
        guard var current = household else { return false }
        if isUIPreview {
            current.storeIDs = stores.map(\.id)
            current.stores = stores
            household = current
            return true
        }
        guard let token = idToken else {
            showError("Not signed in.")
            return false
        }
        isBusy = true
        defer { isBusy = false }
        do {
            household = try await MekasaAPIClient.shared.selectStores(
                householdID: current.id,
                stores: stores,
                token: token
            )
            AppLog.shared.info("stores", "Stores saved", fields: ["count": stores.count])
            return true
        } catch {
            handleAPIFailure(error)
            return false
        }
    }
}
