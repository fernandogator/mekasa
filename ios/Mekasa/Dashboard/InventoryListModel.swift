import Foundation

/// Search + category grouping for the inventory list (UI-006 AC6–AC7).
/// Pure functions so Layer-0 tests can cover them without rendering.
/// Spec version: 1.0
enum InventoryListModel {
    struct Section: Identifiable, Equatable {
        let category: String
        let items: [InventoryItem]

        var id: String { category }
    }

    /// Case-insensitive "contains" on name or category; blank query matches everything.
    static func matches(_ item: InventoryItem, query: String) -> Bool {
        let needle = normalized(query)
        guard !needle.isEmpty else { return true }
        return item.name.localizedCaseInsensitiveContains(needle)
            || item.category.localizedCaseInsensitiveContains(needle)
    }

    static func filter(_ items: [InventoryItem], query: String) -> [InventoryItem] {
        items.filter { matches($0, query: query) }
    }

    /// Sections sorted by category name; rows inside a section sorted by item name.
    static func sections(_ items: [InventoryItem], query: String = "") -> [Section] {
        let grouped = Dictionary(grouping: filter(items, query: query), by: \.category)
        return grouped.keys
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { category in
                Section(
                    category: category,
                    items: grouped[category, default: []].sorted {
                        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                )
            }
    }

    /// Header eyebrow, e.g. "7 items · 3 low" (counts the full inventory, not the filtered rows).
    static func summary(_ items: [InventoryItem]) -> String {
        let low = items.filter(\.isLowStock).count
        let itemsWord = items.count == 1 ? "item" : "items"
        return "\(items.count) \(itemsWord) · \(low) low"
    }

    static func noMatchesMessage(query: String) -> String {
        "No items match “\(normalized(query))”."
    }

    private static func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
