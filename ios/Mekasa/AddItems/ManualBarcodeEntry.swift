import Foundation

/// Typed-UPC fallback for the trash station (REQ-008 / UI-005 AC4), parity with the
/// Android fable "Or type UPC" field. Pure so Layer-0 tests can cover it.
/// Spec version: 1.0
enum ManualBarcodeEntry {
    /// UPC-E is 6–8 digits once the number system / check digit are stripped.
    static let minLength = 6
    /// GTIN-14 is the longest code the backend lookup accepts.
    static let maxLength = 14

    static let placeholder = "049000028911"

    /// Keep ASCII digits only and cap at the longest valid GTIN.
    static func sanitize(_ raw: String) -> String {
        String(raw.filter { $0.isASCII && $0.isNumber }.prefix(maxLength))
    }

    /// True when the (sanitized) code is long enough to be worth looking up.
    static func isSubmittable(_ code: String) -> Bool {
        let clean = sanitize(code)
        return clean.count >= minLength && clean == code
    }
}
