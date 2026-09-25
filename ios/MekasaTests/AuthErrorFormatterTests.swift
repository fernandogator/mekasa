import XCTest
@testable import Mekasa

/// Firebase Auth error → user-facing detail (REQ-001 sign-in error surfacing).
final class AuthErrorFormatterTests: XCTestCase {

    private func firebaseError(code: Int, name: String, message: String) -> NSError {
        NSError(
            domain: "FIRAuthErrorDomain",
            code: code,
            userInfo: [
                NSLocalizedDescriptionKey: message,
                "FIRAuthErrorUserInfoNameKey": name,
            ]
        )
    }

    func testInvalidCredential_explainsProviderOnlyAccounts() {
        // With email-enumeration protection Firebase reports wrong password / no such user /
        // Google-only account all as 17004, so the hint must cover the provider case.
        let wrapped = AuthErrorFormatter.wrap(
            firebaseError(
                code: 17004,
                name: "ERROR_INVALID_CREDENTIAL",
                message: "The supplied auth credential is malformed or has expired."
            )
        )
        let text = wrapped.localizedDescription
        XCTAssertTrue(text.contains("code=17004"))
        XCTAssertTrue(text.contains("ERROR_INVALID_CREDENTIAL"))
        XCTAssertTrue(text.contains("Google/Apple"), "should point at provider sign-in: \(text)")
        XCTAssertTrue(text.contains("Forgot password?"), "should point at the reset action: \(text)")
    }

    func testWrongPasswordAndUserNotFound_shareTheHint() {
        for code in [17009, 17011] {
            let text = AuthErrorFormatter.wrap(firebaseError(code: code, name: "X", message: "m")).localizedDescription
            XCTAssertTrue(text.contains("Forgot password?"), "code \(code): \(text)")
        }
    }

    func testEmailAlreadyInUse_keepsExistingHint() {
        let text = AuthErrorFormatter.wrap(
            firebaseError(code: 17007, name: "ERROR_EMAIL_ALREADY_IN_USE", message: "in use")
        ).localizedDescription
        XCTAssertTrue(text.contains("try Sign in instead"))
    }
}
