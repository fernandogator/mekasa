import Foundation
import SwiftUI

/// Health grade + allergen data for a barcoded product (REQ-021).
/// Mirrors `backend/app/models.py::ProductHealth`; the grade is computed server-side.
/// Spec version: 1.0
struct ProductHealth: Codable, Equatable, Hashable {
    struct Additive: Codable, Equatable, Hashable, Identifiable {
        var id: String { code }
        let code: String
        let name: String
        let concern: String

        init(code: String, name: String, concern: String = "unknown") {
            self.code = code
            self.name = name
            self.concern = concern
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            code = try container.decode(String.self, forKey: .code)
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? code
            concern = try container.decodeIfPresent(String.self, forKey: .concern) ?? "unknown"
        }
    }

    var grade: String?
    var score: Int?
    var nutriscore: String?
    var novaGroup: Int?
    var additives: [Additive]
    var allergens: [String]
    var traces: [String]
    var ingredientsText: String?
    var flags: [String]

    enum CodingKeys: String, CodingKey {
        case grade, score, nutriscore, additives, allergens, traces, flags
        case novaGroup = "nova_group"
        case ingredientsText = "ingredients_text"
    }

    init(
        grade: String? = nil,
        score: Int? = nil,
        nutriscore: String? = nil,
        novaGroup: Int? = nil,
        additives: [Additive] = [],
        allergens: [String] = [],
        traces: [String] = [],
        ingredientsText: String? = nil,
        flags: [String] = []
    ) {
        self.grade = grade
        self.score = score
        self.nutriscore = nutriscore
        self.novaGroup = novaGroup
        self.additives = additives
        self.allergens = allergens
        self.traces = traces
        self.ingredientsText = ingredientsText
        self.flags = flags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        grade = try container.decodeIfPresent(String.self, forKey: .grade)
        score = try container.decodeIfPresent(Int.self, forKey: .score)
        nutriscore = try container.decodeIfPresent(String.self, forKey: .nutriscore)
        novaGroup = try container.decodeIfPresent(Int.self, forKey: .novaGroup)
        additives = try container.decodeIfPresent([Additive].self, forKey: .additives) ?? []
        allergens = try container.decodeIfPresent([String].self, forKey: .allergens) ?? []
        traces = try container.decodeIfPresent([String].self, forKey: .traces) ?? []
        ingredientsText = try container.decodeIfPresent(String.self, forKey: .ingredientsText)
        flags = try container.decodeIfPresent([String].self, forKey: .flags) ?? []
    }

    /// Firestore `health` map (snake_case keys, NSNumber-ish values) → model.
    init?(firestore raw: Any?) {
        guard let data = raw as? [String: Any] else { return nil }
        let additivesRaw = data["additives"] as? [[String: Any]] ?? []
        self.init(
            grade: FirestoreDocumentMapper.string(data["grade"]),
            score: FirestoreDocumentMapper.int(data["score"]),
            nutriscore: FirestoreDocumentMapper.string(data["nutriscore"]),
            novaGroup: FirestoreDocumentMapper.int(data["nova_group"]),
            additives: additivesRaw.compactMap { entry in
                guard let code = FirestoreDocumentMapper.string(entry["code"]) else { return nil }
                return Additive(
                    code: code,
                    name: FirestoreDocumentMapper.string(entry["name"]) ?? code,
                    concern: FirestoreDocumentMapper.string(entry["concern"]) ?? "unknown"
                )
            },
            allergens: data["allergens"] as? [String] ?? [],
            traces: data["traces"] as? [String] ?? [],
            ingredientsText: FirestoreDocumentMapper.string(data["ingredients_text"]),
            flags: data["flags"] as? [String] ?? []
        )
    }

    var hasGrade: Bool { grade != nil }

    /// Additives worth calling out (moderate/high concern first).
    var flaggedAdditives: [Additive] {
        additives.filter { $0.concern == "high" || $0.concern == "moderate" }
    }

    /// Short human summary for list rows / confirm cards.
    var summaryLine: String {
        var parts: [String] = []
        if let nutriscore { parts.append("Nutri-Score \(nutriscore)") }
        if let novaGroup { parts.append("NOVA \(novaGroup)") }
        if !additives.isEmpty { parts.append("\(additives.count) additive\(additives.count == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }
}

/// Server-computed "this member avoids X" hit (REQ-021 AC2).
struct MemberWarning: Codable, Equatable, Hashable, Identifiable {
    var id: String { memberUid }
    let memberUid: String
    let memberName: String
    let matched: [String]

    enum CodingKeys: String, CodingKey {
        case matched
        case memberUid = "member_uid"
        case memberName = "member_name"
    }

    init(memberUid: String, memberName: String, matched: [String]) {
        self.memberUid = memberUid
        self.memberName = memberName
        self.matched = matched
    }

    var sentence: String {
        "\(memberName) avoids \(matched.joined(separator: ", "))"
    }
}

/// Catalog entry from `GET /v1/health/avoidances`.
struct AvoidanceOption: Codable, Equatable, Hashable, Identifiable {
    var id: String { key }
    let key: String
    let label: String
    let terms: [String]

    init(key: String, label: String, terms: [String] = []) {
        self.key = key
        self.label = label
        self.terms = terms
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        label = try container.decode(String.self, forKey: .label)
        terms = try container.decodeIfPresent([String].self, forKey: .terms) ?? []
    }
}

struct AvoidancesResponseDTO: Codable, Equatable {
    let options: [AvoidanceOption]
}

/// Display helpers for the A–E grade.
enum HealthGrade {
    static func color(for grade: String?) -> Color {
        switch grade?.uppercased() ?? "" {
        case "A": return Color(red: 0x1f / 255, green: 0x8a / 255, blue: 0x4c / 255)
        case "B": return Color(red: 0x6f / 255, green: 0xa8 / 255, blue: 0x2f / 255)
        case "C": return Color(red: 0xd9 / 255, green: 0xa4 / 255, blue: 0x06 / 255)
        case "D": return Color(red: 0xe0 / 255, green: 0x6c / 255, blue: 0x1a / 255)
        case "E": return MekasaTheme.accent
        default: return MekasaTheme.brandMuted
        }
    }

    static func label(for grade: String?) -> String {
        switch grade?.uppercased() ?? "" {
        case "A": return "Excellent"
        case "B": return "Good"
        case "C": return "Mediocre"
        case "D": return "Poor"
        case "E": return "Bad"
        default: return "No grade"
        }
    }

    static func concernColor(_ concern: String) -> Color {
        switch concern {
        case "high": return MekasaTheme.accent
        case "moderate": return Color(red: 0xe0 / 255, green: 0x6c / 255, blue: 0x1a / 255)
        case "low": return Color(red: 0xd9 / 255, green: 0xa4 / 255, blue: 0x06 / 255)
        case "none": return MekasaTheme.success
        default: return MekasaTheme.brandMuted
        }
    }
}

/// Client-side mirror of `backend/app/product_health.py::matched_avoidances`, used for
/// items that arrive via Firestore sync (no `warnings` field) and for offline previews.
/// The catalog from the API is preferred; `fallbackOptions` covers first launch.
enum AvoidanceMatcher {
    static let fallbackOptions: [AvoidanceOption] = [
        AvoidanceOption(key: "msg", label: "MSG", terms: ["e621", "e620", "e622", "monosodium glutamate", "glutamate", "yeast extract"]),
        AvoidanceOption(key: "gluten", label: "Gluten", terms: ["gluten", "wheat", "barley", "rye", "spelt", "malt"]),
        AvoidanceOption(key: "milk", label: "Milk / dairy", terms: ["milk", "dairy", "lactose", "whey", "casein", "butter", "cream", "cheese"]),
        AvoidanceOption(key: "eggs", label: "Eggs", terms: ["egg", "eggs", "albumin"]),
        AvoidanceOption(key: "peanuts", label: "Peanuts", terms: ["peanut", "peanuts", "groundnut"]),
        AvoidanceOption(key: "tree_nuts", label: "Tree nuts", terms: ["nuts", "almond", "hazelnut", "walnut", "cashew", "pecan", "pistachio", "macadamia"]),
        AvoidanceOption(key: "soy", label: "Soy", terms: ["soy", "soya", "soybean", "soybeans"]),
        AvoidanceOption(key: "fish", label: "Fish", terms: ["fish", "anchovy", "anchovies", "tuna", "salmon", "cod"]),
        AvoidanceOption(key: "shellfish", label: "Shellfish", terms: ["shellfish", "crustaceans", "shrimp", "prawn", "crab", "lobster", "molluscs", "clam", "mussel", "oyster", "squid"]),
        AvoidanceOption(key: "sesame", label: "Sesame", terms: ["sesame", "tahini"]),
        AvoidanceOption(key: "sulfites", label: "Sulfites", terms: ["sulfite", "sulfites", "sulphite", "sulphites", "sulphur dioxide", "e220", "e221", "e222", "e223", "e224", "e225", "e226", "e227", "e228"]),
        AvoidanceOption(key: "nitrites", label: "Nitrites / nitrates", terms: ["nitrite", "nitrate", "e249", "e250", "e251", "e252"]),
        AvoidanceOption(key: "aspartame", label: "Aspartame", terms: ["aspartame", "e951"]),
        AvoidanceOption(key: "artificial_colors", label: "Artificial colors", terms: ["e102", "e104", "e110", "e122", "e124", "e127", "e129", "e132", "e133", "tartrazine", "red 40", "yellow 5", "yellow 6", "blue 1", "allura red", "sunset yellow"]),
        AvoidanceOption(key: "hfcs", label: "High-fructose corn syrup", terms: ["high fructose corn syrup", "high-fructose corn syrup", "glucose-fructose syrup", "hfcs"]),
        AvoidanceOption(key: "palm_oil", label: "Palm oil", terms: ["palm oil", "palm-oil", "palm fat", "palm kernel"]),
        AvoidanceOption(key: "carrageenan", label: "Carrageenan", terms: ["carrageenan", "e407"]),
        AvoidanceOption(key: "caffeine", label: "Caffeine", terms: ["caffeine", "coffee", "guarana"]),
        AvoidanceOption(key: "pork", label: "Pork", terms: ["pork", "gelatin", "gelatine", "lard", "bacon", "ham"]),
    ]

    static func label(for term: String, options: [AvoidanceOption]) -> String {
        if let option = options.first(where: { $0.key == term }) { return option.label }
        return term.prefix(1).uppercased() + term.dropFirst()
    }

    /// Terms (catalog keys or free text) from `avoid` that the product triggers.
    static func matches(avoid: [String], health: ProductHealth?, options: [AvoidanceOption]) -> [String] {
        guard let health else { return [] }
        var tokens = Set<String>()
        for additive in health.additives { tokens.insert(additive.code.lowercased()) }
        for entry in health.allergens + health.traces + health.flags { tokens.insert(entry.lowercased()) }
        let text = (
            health.additives.map(\.name) + health.allergens + health.traces + health.flags
                + [health.ingredientsText ?? ""]
        ).joined(separator: " ").lowercased()

        var hits: [String] = []
        for raw in avoid {
            let term = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !term.isEmpty, !hits.contains(term) else { continue }
            let needles = options.first(where: { $0.key == term })?.terms.map { $0.lowercased() } ?? [term]
            if needles.contains(where: { tokens.contains($0) || containsWord(text, $0) }) {
                hits.append(term)
            }
        }
        return hits
    }

    static func warnings(
        members: [HouseholdMemberDTO],
        health: ProductHealth?,
        options: [AvoidanceOption]
    ) -> [MemberWarning] {
        members.compactMap { member in
            guard member.status == "active", !member.avoid.isEmpty else { return nil }
            let hits = matches(avoid: member.avoid, health: health, options: options)
            guard !hits.isEmpty else { return nil }
            return MemberWarning(
                memberUid: member.uid,
                memberName: member.name ?? member.email ?? "Household member",
                matched: hits.map { label(for: $0, options: options) }
            )
        }
    }

    /// Word-ish boundary match with optional plural, e.g. "egg" matches "eggs" but not "veggie".
    static func containsWord(_ text: String, _ needle: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: needle)
        guard let regex = try? NSRegularExpression(pattern: "(?<![a-z])\(escaped)(?:s|es)?(?![a-z])") else {
            return text.contains(needle)
        }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }
}
