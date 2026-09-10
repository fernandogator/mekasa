import XCTest
@testable import Mekasa

/// Satisfies: REQ-022
/// Spec version: 1.0
final class SessionExpiryTests: XCTestCase {
    func testAPIError_fromStatus401_isUnauthorized() {
        let error = APIError.from(status: 401, detail: "Invalid or expired Firebase ID token")
        XCTAssertTrue(error.isUnauthorized)
        XCTAssertTrue(SessionExpiry.isUnauthorized(error))
        guard case let .unauthorized(detail) = error else {
            return XCTFail("Expected unauthorized case")
        }
        XCTAssertTrue(detail.lowercased().contains("expired") || detail.lowercased().contains("invalid"))
    }

    func testAPIError_fromStatus403_isNotUnauthorized() {
        let error = APIError.from(status: 403, detail: "Forbidden")
        XCTAssertFalse(error.isUnauthorized)
        XCTAssertFalse(SessionExpiry.isUnauthorized(error))
    }

    @MainActor
    func testEndSessionBecauseExpired_returnsToWelcomeWithMessage() {
        let session = AppSession()
        session.idToken = "stale-token"
        session.displayName = "Alex"
        session.email = "alex@mekasa.local"
        session.onboardingStep = .done
        session.household = TestFixtures.previewHousehold

        session.endSessionBecauseExpired()

        XCTAssertNil(session.idToken)
        XCTAssertEqual(session.onboardingStep, .welcome)
        XCTAssertEqual(session.lastError, SessionExpiry.userMessage)
        XCTAssertTrue(SessionExpiry.userMessage.localizedCaseInsensitiveContains("session expired"))
        // REQ-022 AC5: username survives sign-out for Welcome prefill.
        XCTAssertEqual(session.lastSignedInEmail, "alex@mekasa.local")
        XCTAssertNil(session.email)
    }

    @MainActor
    func testHandleUnauthorizedAPIResponse_withoutFirebaseUser_signsOutToWelcome() async {
        let session = AppSession()
        session.idToken = "stale-token"
        session.email = "alex@mekasa.local"
        session.onboardingStep = .done
        session.household = TestFixtures.previewHousehold

        await session.handleUnauthorizedAPIResponse()

        XCTAssertEqual(session.onboardingStep, .welcome)
        XCTAssertNil(session.idToken)
        XCTAssertEqual(session.lastError, SessionExpiry.userMessage)
        XCTAssertEqual(session.lastSignedInEmail, "alex@mekasa.local")
    }

    @MainActor
    func testRememberSignedInEmail_persistsAcrossSignOut() {
        let key = "mekasa.lastSignedInEmail"
        UserDefaults.standard.removeObject(forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let session = AppSession()
        session.rememberSignedInEmail("maya@mekasa.local")
        session.idToken = "token"
        session.email = "maya@mekasa.local"
        session.onboardingStep = .done

        session.signOut()

        XCTAssertEqual(session.lastSignedInEmail, "maya@mekasa.local")
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), "maya@mekasa.local")
        XCTAssertEqual(session.onboardingStep, .welcome)
        XCTAssertNil(session.email)
    }
}
