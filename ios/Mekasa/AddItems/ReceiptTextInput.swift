import Foundation

/// Pasted-receipt fallback for the receipt scan path (REQ-005 AC7), parity with the
/// Android fable `raw_text` route. Pure so Layer-0 tests can cover it.
/// Spec version: 1.0
enum ReceiptTextInput {
    /// Longest raw text the backend accepts in one scan request.
    static let maxCharacters = 8_000

    /// Trim each line, drop blank lines, normalise line endings, cap length.
    static func normalize(_ raw: String) -> String {
        let lines = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return String(lines.joined(separator: "\n").prefix(maxCharacters))
    }

    /// True when at least one line looks like a receipt entry (has a letter).
    static func isSubmittable(_ raw: String) -> Bool {
        normalize(raw)
            .split(separator: "\n")
            .contains { $0.contains(where: \.isLetter) }
    }

    /// Non-empty lines after normalisation; drives the "N lines" hint under the editor.
    static func lineCount(_ raw: String) -> Int {
        let text = normalize(raw)
        return text.isEmpty ? 0 : text.split(separator: "\n").count
    }
}
