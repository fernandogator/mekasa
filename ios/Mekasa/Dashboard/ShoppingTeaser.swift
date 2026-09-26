import Foundation

/// Copy for the dashboard "Shopping list" teaser card (UI-004 AC4), parity with the
/// Android fable dashboard. Pure so Layer-0 tests can cover it.
/// Spec version: 1.0
enum ShoppingTeaser {
    /// Rows still to pick up: anything not checked off, including pending requests
    /// (they still need a trip once approved).
    static func openItems(_ items: [ShoppingListItem]) -> [ShoppingListItem] {
        items.filter { !$0.isChecked }
    }

    /// "3 items to pick up" / "1 item to pick up" / "List is clear".
    static func headline(_ items: [ShoppingListItem]) -> String {
        let count = openItems(items).count
        switch count {
        case 0: return "List is clear"
        case 1: return "1 item to pick up"
        default: return "\(count) items to pick up"
        }
    }

    /// Up to three open names for a one-line preview, e.g. "Eggs, Avocados, Dish soap".
    static func preview(_ items: [ShoppingListItem], limit: Int = 3) -> String? {
        let open = openItems(items)
        guard !open.isEmpty else { return nil }
        let names = open.prefix(limit).map(\.name)
        let rest = open.count - names.count
        return rest > 0 ? names.joined(separator: ", ") + " +\(rest) more" : names.joined(separator: ", ")
    }
}
