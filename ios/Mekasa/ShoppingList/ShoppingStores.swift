import Foundation

/// Per-store shopping lists and store picker rules. Pure functions so Layer-0
/// tests can cover them without SwiftUI.
/// Satisfies: REQ-024 AC5, AC7; REQ-003 AC11
/// Spec version: 1.0
enum ShoppingStores {
    /// List key for rows that can be bought anywhere (REQ-024).
    static let anyStore = "any"
    /// Selector key that shows every row.
    static let allStores = "all"
    static let anyStoreName = "Any store"
    static let allStoresName = "All stores"
    static let noStoresHint = "Want a list per store? Choose your grocery stores in Family settings."
    static let emptySettingsMessage = "No stores saved yet. Add where you shop to keep a shopping list for each store."
    static let addressNotFound = "We couldn't find that address. Check it and try again."

    /// One chip in the store selector.
    /// Satisfies: REQ-024 AC7
    struct Tab: Equatable, Identifiable {
        let key: String
        let title: String
        let count: Int
        var id: String { key }
    }

    /// The list a row is on: its store, or "Any store" when it has none or its store
    /// is no longer saved.
    /// Satisfies: REQ-024 AC5, AC7
    /// Spec version: 1.0
    static func listKey(for storeID: String?, saved: [SavedStore]) -> String {
        guard let storeID, saved.contains(where: { $0.id == storeID }) else { return anyStore }
        return storeID
    }

    /// Rows on `list` (a store id, `anyStore`, or `allStores` for every row), in source order.
    /// Satisfies: REQ-024 AC5, AC7
    /// Spec version: 1.0
    static func filter(_ items: [ShoppingListItem], list: String, saved: [SavedStore]) -> [ShoppingListItem] {
        guard list != allStores else { return items }
        return items.filter { listKey(for: $0.storeID, saved: saved) == list }
    }

    /// Rows still to buy (not checked) on `list`.
    /// Satisfies: REQ-024 AC7
    /// Spec version: 1.0
    static func count(_ items: [ShoppingListItem], list: String, saved: [SavedStore]) -> Int {
        filter(items, list: list, saved: saved).filter { !$0.isChecked }.count
    }

    /// Counts keyed by list: `allStores`, each saved store id, and `anyStore`.
    /// Satisfies: REQ-024 AC7
    /// Spec version: 1.0
    static func counts(_ items: [ShoppingListItem], saved: [SavedStore]) -> [String: Int] {
        var result: [String: Int] = [allStores: 0, anyStore: 0]
        for store in saved { result[store.id] = 0 }
        for item in items where !item.isChecked {
            result[allStores, default: 0] += 1
            result[listKey(for: item.storeID, saved: saved), default: 0] += 1
        }
        return result
    }

    /// Selector chips: "All stores", one per saved store, then "Any store".
    /// Empty when the household has no saved stores (one list as before).
    /// Satisfies: REQ-024 AC7
    /// Spec version: 1.0
    static func tabs(_ items: [ShoppingListItem], saved: [SavedStore]) -> [Tab] {
        guard !saved.isEmpty else { return [] }
        let counts = counts(items, saved: saved)
        var tabs = [Tab(key: allStores, title: allStoresName, count: counts[allStores] ?? 0)]
        tabs += saved.map { Tab(key: $0.id, title: $0.name, count: counts[$0.id] ?? 0) }
        tabs.append(Tab(key: anyStore, title: anyStoreName, count: counts[anyStore] ?? 0))
        return tabs
    }

    /// Display name of a list key ("Any store" for unknown keys).
    /// Satisfies: REQ-024 AC7
    /// Spec version: 1.0
    static func storeName(for listKey: String, saved: [SavedStore]) -> String {
        if listKey == allStores { return allStoresName }
        return saved.first(where: { $0.id == listKey })?.name ?? anyStoreName
    }

    /// Store name shown on a row while "All stores" is selected.
    /// Satisfies: REQ-024 AC7
    /// Spec version: 1.0
    static func rowStoreName(_ item: ShoppingListItem, saved: [SavedStore]) -> String {
        storeName(for: listKey(for: item.storeID, saved: saved), saved: saved)
    }

    /// The `store_id` to save a new row with: the selected store, or nil for
    /// "Any store" and "All stores".
    /// Satisfies: REQ-024 AC7
    /// Spec version: 1.0
    static func storeIDForNewItem(selected: String, saved: [SavedStore]) -> String? {
        guard selected != allStores, selected != anyStore,
              saved.contains(where: { $0.id == selected }) else { return nil }
        return selected
    }

    /// A selection that still exists after the saved stores change.
    /// Satisfies: REQ-024 AC7
    /// Spec version: 1.0
    static func validSelection(_ selected: String, saved: [SavedStore]) -> String {
        if selected == allStores || selected == anyStore { return selected }
        return saved.contains(where: { $0.id == selected }) ? selected : allStores
    }

    // MARK: - Store picker (REQ-003 AC11)

    /// IDs the picker starts with checked: only stores saved with details, so bare
    /// IDs from older clients are not counted.
    /// Satisfies: REQ-003 AC11
    /// Spec version: 1.0
    static func preselectedIDs(_ household: Household?) -> Set<String> {
        Set(household?.stores.map(\.id) ?? [])
    }

    /// Nearby stores plus saved ones the search no longer returns, nearest first.
    /// Satisfies: REQ-003 AC4, AC11
    /// Spec version: 1.0
    static func pickerStores(nearby: [Store], saved: [SavedStore]) -> [SavedStore] {
        var rows = nearby.map { SavedStore($0) }
        let seen = Set(rows.map(\.id))
        rows += saved.filter { !seen.contains($0.id) }
        return rows.enumerated()
            .sorted { lhs, rhs in
                let l = lhs.element.distanceMiles ?? .infinity
                let r = rhs.element.distanceMiles ?? .infinity
                return l == r ? lhs.offset < rhs.offset : l < r
            }
            .map(\.element)
    }

    /// Search by name or address.
    /// Satisfies: REQ-003 AC11
    /// Spec version: 1.0
    static func filterStores(_ stores: [SavedStore], query: String) -> [SavedStore] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return stores }
        return stores.filter { "\($0.name) \($0.address)".lowercased().contains(needle) }
    }

    /// Checked rows in list order, ready to save with their details.
    /// Satisfies: REQ-003 AC6, AC11
    /// Spec version: 1.0
    static func selectedStores(_ stores: [SavedStore], selected: Set<String>) -> [SavedStore] {
        stores.filter { selected.contains($0.id) }
    }

    /// "1.4 mi" (one decimal under 10 miles, whole miles above); empty when unknown.
    /// Satisfies: REQ-003 AC11
    /// Spec version: 1.0
    static func miles(_ distance: Double?) -> String {
        guard let distance else { return "" }
        if distance < 10 { return String(format: "%.1f mi", distance) }
        return "\(Int(distance.rounded())) mi"
    }

    /// Short label for the logo circle, e.g. "HE" for "H-E-B Plus" or "COST" for "Costco".
    /// Satisfies: REQ-003 AC11
    /// Spec version: 1.0
    static func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(4))
    }
}
