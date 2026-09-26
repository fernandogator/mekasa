import Foundation

/// Section split + header copy for the shopping list (REQ-012 / REQ-014 client parity
/// with the Android fable list). Pure functions so Layer-0 tests can cover them.
/// Spec version: 1.0
enum ShoppingListSections {
    struct Grouped: Equatable {
        /// Requests awaiting an owner decision.
        var pending: [ShoppingListItem] = []
        /// Approved, not yet purchased.
        var toBuy: [ShoppingListItem] = []
        /// Checked off.
        var purchased: [ShoppingListItem] = []

        var isEmpty: Bool { pending.isEmpty && toBuy.isEmpty && purchased.isEmpty }
    }

    static let purchaseLockNotice = "Only household owners can mark items purchased."

    /// Order within each section is preserved from the source list.
    static func group(_ items: [ShoppingListItem]) -> Grouped {
        var grouped = Grouped()
        for item in items {
            if item.isChecked {
                grouped.purchased.append(item)
            } else if item.needsApproval {
                grouped.pending.append(item)
            } else {
                grouped.toBuy.append(item)
            }
        }
        return grouped
    }

    static func toBuyCount(_ items: [ShoppingListItem]) -> Int {
        group(items).toBuy.count
    }

    /// Header eyebrow: "3 to buy", "1 to buy", or "Nothing to buy".
    static func toBuySummary(_ items: [ShoppingListItem]) -> String {
        let count = toBuyCount(items)
        return count == 0 ? "Nothing to buy" : "\(count) to buy"
    }

    /// Chip shown next to a row's quantity, if any.
    static func chipLabel(for item: ShoppingListItem) -> String? {
        if item.needsApproval && !item.isChecked { return "Needs approval" }
        if item.kind == .auto { return "Auto" }
        return nil
    }
}
