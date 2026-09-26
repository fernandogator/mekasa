import AuthenticationServices
import XCTest
@testable import Mekasa

/// ASAuthorization failure → AuthServiceError mapping (REQ-001 Apple sign-in surfacing).
final class AppleAuthorizationErrorTests: XCTestCase {

    private func asError(_ code: ASAuthorizationError.Code) -> NSError {
        NSError(domain: ASAuthorizationError.errorDomain, code: code.rawValue)
    }

    func testCanceled_mapsToCancelled() {
        XCTAssertEqual(AuthService.appleAuthorizationError(from: asError(.canceled)), .cancelled)
    }

    func testUnknown_mapsToUnavailable() {
        // Code 1000: missing entitlement (Debug builds) or no Apple ID on the device.
        XCTAssertEqual(AuthService.appleAuthorizationError(from: asError(.unknown)), .appleSignInUnavailable)
        XCTAssertEqual(AuthService.appleAuthorizationError(from: asError(.notInteractive)), .appleSignInUnavailable)
    }

    func testOtherASAuthorizationCodes_fallThroughToFormatter() {
        XCTAssertNil(AuthService.appleAuthorizationError(from: asError(.failed)))
        XCTAssertNil(AuthService.appleAuthorizationError(from: asError(.invalidResponse)))
    }

    func testNonASAuthorizationErrors_areIgnored() {
        let firebase = NSError(domain: "FIRAuthErrorDomain", code: 17004)
        XCTAssertNil(AuthService.appleAuthorizationError(from: firebase))
    }

    func testUnavailableMessage_pointsAtAnAlternative() {
        let text = AuthServiceError.appleSignInUnavailable.localizedDescription
        XCTAssertTrue(text.contains("Continue with Google"))
        #if DEBUG
        XCTAssertTrue(text.contains("Debug"), "Debug builds should explain the missing entitlement")
        #endif
    }
}
