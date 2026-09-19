import Foundation

/// Parses a spoken grocery phrase into quantity + product query (REQ-007).
/// Spec version: 1.0
enum VoicePhraseParser {
    struct Result: Equatable {
        let quantity: Int
        let productQuery: String
        let displayName: String
    }

    private static let numberWords: [String: Int] = [
        "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4,
        "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9,
        "ten": 10, "eleven": 11, "twelve": 12,
    ]

    /// Extracts leading quantity (digit or number word) and the remaining product name.
    static func parse(_ transcript: String) -> Result? {
        let cleaned = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[.!?,;:]+$"#, with: "", options: .regularExpression)
        guard !cleaned.isEmpty else { return nil }

        var tokens = cleaned.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !tokens.isEmpty else { return nil }

        var quantity = 1
        let first = tokens[0].lowercased()
        if let n = Int(first), n > 0 {
            quantity = min(n, 99)
            tokens.removeFirst()
        } else if let n = numberWords[first] {
            quantity = n
            tokens.removeFirst()
        }

        // Drop filler: "of", "packs of", "pack of", "bottles of", etc.
        while let head = tokens.first?.lowercased(),
              ["of", "pack", "packs", "bottle", "bottles", "box", "boxes", "bag", "bags"].contains(head) {
            tokens.removeFirst()
            if tokens.first?.lowercased() == "of" {
                tokens.removeFirst()
            }
        }

        guard !tokens.isEmpty else { return nil }
        let productQuery = tokens.joined(separator: " ")
        let displayName = productQuery.prefix(1).uppercased() + productQuery.dropFirst()
        return Result(quantity: quantity, productQuery: productQuery, displayName: String(displayName))
    }
}
