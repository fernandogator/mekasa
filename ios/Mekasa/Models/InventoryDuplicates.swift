import Foundation

/// Why items were grouped as duplicates, strongest first (REQ-INV-021 AC1).
enum DuplicateReason: String, Codable, Equatable {
    case sameBarcode = "same_barcode"
    case sameProduct = "same_product"
    case sameName = "same_name"

    var label: String {
        switch self {
        case .sameBarcode: return "Same barcode"
        case .sameProduct: return "Same product"
        case .sameName: return "Same name"
        }
    }

    fileprivate var rank: Int {
        switch self {
        case .sameBarcode: return 0
        case .sameProduct: return 1
        case .sameName: return 2
        }
    }
}

/// One duplicate group: `keepID` survives a merge (REQ-INV-021 AC2).
struct DuplicateGroup: Identifiable, Equatable {
    let reason: DuplicateReason
    let keepID: String
    let items: [InventoryItem]

    var id: String { items.map(\.id).sorted().joined(separator: "|") }

    var survivor: InventoryItem? { items.first { $0.id == keepID } }

    var others: [InventoryItem] { items.filter { $0.id != keepID } }

    /// Changes whenever any item in the group changes, so "Not duplicates" lapses (AC5).
    var signature: String {
        items
            .map { "\($0.id)@\(Int($0.updatedAt.timeIntervalSince1970))" }
            .sorted()
            .joined(separator: "|")
    }
}

/// Grouping, survivor choice and merge rules shared by the API path and local sessions.
/// Satisfies: REQ-INV-021 AC1–AC3, AC5, AC6
/// Spec version: 1.0
enum InventoryDuplicates {
    static let emptyTitle = "No duplicates found"
    static let emptySubtitle = "Your inventory is tidy."
    static let keepsPhotoLabel = "Keeps this photo"

    // MARK: Names (AC1)

    static func dedupeName(_ name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        let cleaned = folded.unicodeScalars.map { scalar -> Character in
            let value = scalar.value
            let isAlnum = (value >= 97 && value <= 122) || (value >= 48 && value <= 57)
            return isAlnum ? Character(scalar) : " "
        }
        return String(cleaned)
            .split(separator: " ")
            .map { singular(String($0)) }
            .joined(separator: " ")
    }

    private static func singular(_ word: String) -> String {
        guard word.count > 3 else { return word }
        if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if ["xes", "ches", "shes", "sses", "zes", "oes"].contains(where: { word.hasSuffix($0) }) {
            return String(word.dropLast(2))
        }
        if word.hasSuffix("s"), !["ss", "us", "is"].contains(where: { word.hasSuffix($0) }) {
            return String(word.dropLast())
        }
        return word
    }

    private static func normalizedCategory(_ category: String) -> String {
        category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func keys(for item: InventoryItem) -> [(DuplicateReason, String)] {
        var keys: [(DuplicateReason, String)] = []
        if let barcode = item.barcode?.trimmingCharacters(in: .whitespaces), !barcode.isEmpty {
            keys.append((.sameBarcode, barcode))
        }
        if let product = item.productId?.trimmingCharacters(in: .whitespaces), !product.isEmpty {
            keys.append((.sameProduct, product))
        }
        let name = dedupeName(item.name)
        if !name.isEmpty {
            keys.append((.sameName, "\(normalizedCategory(item.category))|\(name)"))
        }
        return keys
    }

    // MARK: Survivor (AC2)

    static func hasRealImage(_ item: InventoryItem) -> Bool {
        guard let url = item.imageURL?.trimmingCharacters(in: .whitespaces), !url.isEmpty else { return false }
        return !url.contains("placehold.co/")
    }

    static func imageTime(_ item: InventoryItem) -> Date {
        item.imageUpdatedAt ?? item.updatedAt
    }

    static func pickSurvivor(_ items: [InventoryItem]) -> InventoryItem? {
        let withImage = items.filter(hasRealImage)
        if !withImage.isEmpty {
            return withImage.max { lhs, rhs in
                (imageTime(lhs), lhs.updatedAt, lhs.id) < (imageTime(rhs), rhs.updatedAt, rhs.id)
            }
        }
        return items.max { lhs, rhs in (lhs.updatedAt, lhs.id) < (rhs.updatedAt, rhs.id) }
    }

    // MARK: Groups (AC1)

    static func findGroups(_ items: [InventoryItem]) -> [DuplicateGroup] {
        var parent = Array(items.indices)
        func root(_ index: Int) -> Int {
            var current = index
            while parent[current] != current {
                parent[current] = parent[parent[current]]
                current = parent[current]
            }
            return current
        }

        var firstByKey: [String: Int] = [:]
        var linkedBy: [(DuplicateReason, Int)] = []
        for (index, item) in items.enumerated() {
            for (reason, value) in keys(for: item) {
                let key = "\(reason.rawValue)#\(value)"
                if let first = firstByKey[key] {
                    parent[root(index)] = root(first)
                    linkedBy.append((reason, first))
                } else {
                    firstByKey[key] = index
                }
            }
        }

        var members: [Int: [Int]] = [:]
        for index in items.indices {
            members[root(index), default: []].append(index)
        }

        var groups: [DuplicateGroup] = []
        for indexes in members.values where indexes.count > 1 {
            let groupRoot = root(indexes[0])
            let reason = linkedBy
                .filter { root($0.1) == groupRoot }
                .map(\.0)
                .min { $0.rank < $1.rank } ?? .sameName
            let groupItems = indexes.map { items[$0] }.sorted { $0.updatedAt > $1.updatedAt }
            guard let survivor = pickSurvivor(groupItems) else { continue }
            groups.append(DuplicateGroup(reason: reason, keepID: survivor.id, items: groupItems))
        }
        return groups.sorted {
            ($0.reason.rank, dedupeName($0.items[0].name)) < ($1.reason.rank, dedupeName($1.items[0].name))
        }
    }

    // MARK: Merge (AC3)

    /// The survivor after a merge: higher quantity and threshold (not a sum), and
    /// barcode, product, price and health filled from the newest other item.
    static func merged(_ group: DuplicateGroup) -> InventoryItem? {
        guard var survivor = group.survivor else { return nil }
        let all = group.items
        survivor.quantity = all.map(\.quantity).max() ?? survivor.quantity
        survivor.lowStockThreshold = all.map(\.lowStockThreshold).max() ?? survivor.lowStockThreshold
        let newestFirst = group.others.sorted { $0.updatedAt > $1.updatedAt }
        if (survivor.barcode ?? "").isEmpty {
            survivor.barcode = newestFirst.compactMap { ($0.barcode ?? "").isEmpty ? nil : $0.barcode }.first
        }
        if (survivor.productId ?? "").isEmpty {
            survivor.productId = newestFirst.compactMap { ($0.productId ?? "").isEmpty ? nil : $0.productId }.first
        }
        if survivor.pricePaid == nil {
            survivor.pricePaid = newestFirst.compactMap(\.pricePaid).first
        }
        if survivor.health == nil {
            survivor.health = newestFirst.compactMap(\.health).first
        }
        survivor.updatedAt = Date()
        return survivor
    }

    // MARK: Copy (AC5)

    static func headline(groupCount: Int) -> String {
        groupCount == 1 ? "1 group found · review before merging" : "\(groupCount) groups found · review before merging"
    }

    /// "keeps qty 3 (higher) · newest photo", shown after "Merges into {name}".
    static func resultDetail(_ group: DuplicateGroup) -> String {
        let quantity = group.items.map(\.quantity).max() ?? 0
        var parts = ["keeps qty \(quantity) (higher)"]
        if let survivor = group.survivor, hasRealImage(survivor) {
            parts.append("newest photo")
        }
        return parts.joined(separator: " · ")
    }

    static func photoAge(_ item: InventoryItem, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard hasRealImage(item) else { return "No photo" }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: imageTime(item)),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        switch days {
        case ..<1: return "Photo updated today"
        case 1: return "Photo updated yesterday"
        default: return "Photo updated \(days) days ago"
        }
    }

    static func confirmation(count: Int, name: String) -> String {
        "Merged \(count) items into \(name)"
    }

    /// "Merge all": one group reads like a single merge; several name the item count.
    static func bulkConfirmation(_ merged: [DuplicateGroup]) -> String? {
        guard let first = merged.first else { return nil }
        let count = merged.reduce(0) { $0 + $1.items.count }
        if merged.count == 1 {
            return confirmation(count: count, name: first.survivor?.name ?? first.items[0].name)
        }
        return confirmation(count: count, name: "\(merged.count) items")
    }
}

/// "Not duplicates" choices, per device and household, until the items change (AC5).
struct DismissedDuplicates {
    private let defaults: UserDefaults
    private let key: String

    init(householdID: String?, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        key = "mekasa.dismissedDuplicates.\(householdID ?? "local")"
    }

    func contains(_ group: DuplicateGroup) -> Bool {
        Set(defaults.stringArray(forKey: key) ?? []).contains(group.signature)
    }

    func dismiss(_ group: DuplicateGroup) {
        var saved = defaults.stringArray(forKey: key) ?? []
        guard !saved.contains(group.signature) else { return }
        saved.append(group.signature)
        defaults.set(Array(saved.suffix(200)), forKey: key)
    }

    func visible(_ groups: [DuplicateGroup]) -> [DuplicateGroup] {
        groups.filter { !contains($0) }
    }
}
