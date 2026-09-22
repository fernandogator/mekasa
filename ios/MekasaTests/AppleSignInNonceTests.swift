import XCTest
@testable import Mekasa

final class AppleSignInNonceTests: XCTestCase {
    func testRandomNonce_isHexAndExpectedLength() {
        let nonce = AppleSignInNonce.random(length: 32)
        XCTAssertEqual(nonce.count, 64)
        XCTAssertTrue(nonce.allSatisfy { $0.isHexDigit })
    }

    func testSHA256_isDeterministicHexDigest() {
        let digest = AppleSignInNonce.sha256("mekasa-nonce")
        XCTAssertEqual(digest.count, 64)
        XCTAssertEqual(digest, AppleSignInNonce.sha256("mekasa-nonce"))
        XCTAssertNotEqual(digest, AppleSignInNonce.sha256("other"))
        XCTAssertTrue(digest.allSatisfy { $0.isHexDigit })
    }
}
