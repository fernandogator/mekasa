import Foundation

struct DuplicatesFailure: Error, Equatable {
    let message: String
}

/// Find and merge duplicate inventory items.
/// Satisfies: REQ-INV-021 AC1–AC3, AC6
/// Spec version: 1.0
extension AppSession {
    /// Signed in: the API's groups. Preview, UI tests and signed out: the same rules run locally.
    func findDuplicateGroups() async -> Result<[DuplicateGroup], DuplicatesFailure> {
        guard canSyncInventory, let token = idToken, let householdID = household?.id else {
            return .success(InventoryDuplicates.findGroups(inventory))
        }
        do {
            let response = try await MekasaAPIClient.shared.listInventoryDuplicates(householdID: householdID, token: token)
            return .success(response.groups.map { $0.toLocal() })
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                handleAPIFailure(error)
                return .failure(DuplicatesFailure(message: ""))
            }
            return .failure(DuplicatesFailure(message: "Couldn’t check for duplicates. Try again."))
        }
    }

    /// Merges one group and updates the local inventory and shopping list from the
    /// result (AC6). Success carries the confirmation ("Merged 2 items into Bananas").
    func mergeDuplicateGroup(_ group: DuplicateGroup) async -> Result<String, DuplicatesFailure> {
        guard canSyncInventory, let token = idToken, let householdID = household?.id else {
            guard let merged = InventoryDuplicates.merged(group) else {
                return .failure(DuplicatesFailure(message: "Couldn’t merge those items."))
            }
            applyMerge(survivor: merged, removedIDs: group.others.map(\.id), shoppingRows: [])
            return .success(InventoryDuplicates.confirmation(count: group.items.count, name: merged.name))
        }
        do {
            let response = try await MekasaAPIClient.shared.mergeInventoryItems(
                householdID: householdID,
                itemIDs: group.items.map(\.id),
                token: token
            )
            applyMerge(
                survivor: response.item.toLocal(),
                removedIDs: response.removedIds,
                shoppingRows: response.shoppingListItems.map { $0.toLocal() }
            )
            return .success(InventoryDuplicates.confirmation(count: response.removedIds.count + 1, name: response.item.name))
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                handleAPIFailure(error)
                return .failure(DuplicatesFailure(message: ""))
            }
            if let apiError = error as? APIError, case let .server(status, _) = apiError, status == 409 || status == 404 {
                return .failure(DuplicatesFailure(message: "Those items changed. Check for duplicates again."))
            }
            return .failure(DuplicatesFailure(message: "Couldn’t merge those items. Try again."))
        }
    }

    private func applyMerge(survivor: InventoryItem, removedIDs: [String], shoppingRows: [ShoppingListItem]) {
        let removed = Set(removedIDs)
        let position = inventory.firstIndex { $0.id == survivor.id || removed.contains($0.id) } ?? 0
        inventory.removeAll { $0.id == survivor.id || removed.contains($0.id) }
        inventory.insert(survivor, at: min(position, inventory.count))

        for index in shoppingList.indices {
            if let linked = shoppingList[index].inventoryItemID, removed.contains(linked) {
                shoppingList[index].inventoryItemID = survivor.id
            }
        }
        for row in shoppingRows {
            if let index = shoppingList.firstIndex(where: { $0.id == row.id }) {
                shoppingList[index] = row
            }
        }
        logActivity(InventoryDuplicates.confirmation(count: removedIDs.count + 1, name: survivor.name), kind: .success)
    }
}
