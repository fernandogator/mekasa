import Foundation

/// Maps Firestore document fields → local models (REQ-020).
/// Spec version: 1.0
/// Shared by `HouseholdSyncService` and unit tests (dictionary-shaped docs).
enum FirestoreDocumentMapper {
    static func inventoryItem(id: String, data: [String: Any]) -> InventoryItem? {
        // Soft-deleted docs stay in Firestore until purge — hide from live list.
        if bool(data["deleted"]) == true { return nil }
        guard let name = string(data["name"]), !name.isEmpty else { return nil }
        let quantity = int(data["quantity"]) ?? 0
        return InventoryItem(
            id: id,
            name: name,
            category: string(data["category"]) ?? InventoryCategory.other.rawValue,
            quantity: quantity,
            lowStockThreshold: int(data["low_stock_threshold"]) ?? 1,
            pricePaid: double(data["price_paid"]),
            barcode: string(data["barcode"]),
            source: InventorySource(rawValue: string(data["source"]) ?? "") ?? .manual,
            imageURL: string(data["image_url"]),
            health: ProductHealth(firestore: data["health"]),
            updatedAt: date(data["updated_at"]) ?? Date()
        )
    }

    static func shoppingListItem(id: String, data: [String: Any]) -> ShoppingListItem? {
        guard let name = string(data["name"]), !name.isEmpty else { return nil }
        return ShoppingListItem(
            id: id,
            name: name,
            quantity: int(data["quantity"]) ?? 1,
            quantityLabel: string(data["quantity_label"]),
            isChecked: bool(data["is_checked"]) ?? false,
            needsApproval: bool(data["needs_approval"]) ?? false,
            requestedBy: string(data["requested_by"]),
            inventoryItemID: string(data["inventory_item_id"]),
            kind: ShoppingListItem.Kind(rawValue: string(data["kind"]) ?? "") ?? .custom
        )
    }

    static func string(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let s = value as? String { return s }
        return nil
    }

    static func int(_ value: Any?) -> Int? {
        guard let value else { return nil }
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        return nil
    }

    static func double(_ value: Any?) -> Double? {
        guard let value else { return nil }
        if let d = value as? Double { return d }
        if let n = value as? NSNumber { return n.doubleValue }
        return nil
    }

    static func bool(_ value: Any?) -> Bool? {
        guard let value else { return nil }
        if let b = value as? Bool { return b }
        if let n = value as? NSNumber { return n.boolValue }
        return nil
    }

    static func date(_ value: Any?) -> Date? {
        guard let value else { return nil }
        if let d = value as? Date { return d }
        // Firebase Timestamp (avoid hard import in mapper tests via selector).
        let sel = NSSelectorFromString("dateValue")
        if let obj = value as? NSObject, obj.responds(to: sel),
           let result = obj.perform(sel)?.takeUnretainedValue() as? Date {
            return result
        }
        return nil
    }
}
