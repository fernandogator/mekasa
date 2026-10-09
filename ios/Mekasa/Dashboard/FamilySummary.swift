import Foundation

/// Copy for the Family tab's account / household cards and member rows (REQ-019),
/// parity with the Android fable Family screen. Pure so Layer-0 tests can cover it.
/// Spec version: 1.0
enum FamilySummary {
    static let offlinePreviewNotice = "Offline preview mode"

    /// Signed-in identity: display name first, then email, then a neutral fallback.
    static func accountTitle(displayName: String?, email: String?) -> String {
        if let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        if let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            return email
        }
        return "Signed in"
    }

    /// Email line under the title; hidden when it would just repeat the title.
    static func accountSubtitle(displayName: String?, email: String?) -> String? {
        guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
            return nil
        }
        return accountTitle(displayName: displayName, email: email) == email ? nil : email
    }

    static func householdTitle(_ household: Household?) -> String {
        if let name = household?.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return household == nil ? "No household" : "Your house"
    }

    static func householdAddress(_ household: Household?) -> String {
        if let address = household?.address?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty {
            return address
        }
        return "Address not set"
    }

    /// "Owner", "Teen", "Member". Unknown roles fall back to a capitalized label.
    static func roleLabel(_ role: String) -> String {
        switch role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "owner": return "Owner"
        case "teen": return "Teen"
        case "member", "": return "Member"
        default: return role.capitalized
        }
    }

    /// The household stores one home photo. Only owners (admins) can replace it.
    static func canChangeHomePhoto(role: String?, isDocumentOwner: Bool) -> Bool {
        if isDocumentOwner { return true }
        return role == "owner"
    }

    /// "Owner · active", "Teen · invited"; status omitted when blank.
    static func memberSubtitle(role: String, status: String) -> String {
        let label = roleLabel(role)
        let statusLabel = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return statusLabel.isEmpty ? label : "\(label) · \(statusLabel)"
    }
}
