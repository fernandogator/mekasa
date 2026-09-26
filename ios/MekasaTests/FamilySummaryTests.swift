import XCTest
@testable import Mekasa

/// Family tab account / household / member copy (REQ-019 parity with Android).
final class FamilySummaryTests: XCTestCase {

    func testAccountTitle_prefersDisplayNameThenEmail() {
        XCTAssertEqual(FamilySummary.accountTitle(displayName: "Alex Owner", email: "alex@mekasa.local"), "Alex Owner")
        XCTAssertEqual(FamilySummary.accountTitle(displayName: "  ", email: "alex@mekasa.local"), "alex@mekasa.local")
        XCTAssertEqual(FamilySummary.accountTitle(displayName: nil, email: nil), "Signed in")
    }

    func testAccountSubtitle_hidesEmailWhenItIsTheTitle() {
        XCTAssertEqual(
            FamilySummary.accountSubtitle(displayName: "Alex Owner", email: "alex@mekasa.local"),
            "alex@mekasa.local"
        )
        XCTAssertNil(FamilySummary.accountSubtitle(displayName: nil, email: "alex@mekasa.local"))
        XCTAssertNil(FamilySummary.accountSubtitle(displayName: "Alex", email: ""))
    }

    func testHouseholdTitleAndAddress() {
        XCTAssertEqual(FamilySummary.householdTitle(TestFixtures.previewHousehold), "The Test House")
        XCTAssertEqual(FamilySummary.householdAddress(TestFixtures.previewHousehold), "100 Test St")
        XCTAssertEqual(FamilySummary.householdTitle(nil), "No household")
        XCTAssertEqual(FamilySummary.householdAddress(nil), "Address not set")

        var unnamed = TestFixtures.previewHousehold
        unnamed.name = ""
        unnamed.address = nil
        XCTAssertEqual(FamilySummary.householdTitle(unnamed), "Your house")
        XCTAssertEqual(FamilySummary.householdAddress(unnamed), "Address not set")
    }

    func testMemberSubtitle_joinsRoleAndStatus() {
        XCTAssertEqual(FamilySummary.memberSubtitle(role: "owner", status: "active"), "Owner · active")
        XCTAssertEqual(FamilySummary.memberSubtitle(role: "member", status: "Invited"), "Member · invited")
        XCTAssertEqual(FamilySummary.memberSubtitle(role: "member", status: ""), "Member")
        XCTAssertEqual(FamilySummary.memberSubtitle(role: "", status: "active"), "Member · active")
    }

    func testOfflinePreviewNoticeCopy() {
        XCTAssertEqual(FamilySummary.offlinePreviewNotice, "Offline preview mode")
    }
}
