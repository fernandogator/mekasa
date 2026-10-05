import XCTest
@testable import Mekasa

/// Swiping between items in item detail: order, bounds, position and swipe rules.
/// Satisfies: REQ-INV-020 (Swipe Between Items in Item Detail)
/// Acceptance criteria: AC1, AC2, AC3, AC4, AC6
/// Spec version: 1.0
final class ItemPagerTests: XCTestCase {
    private let pager = ItemPager(ids: ["milk", "eggs", "bread"])

    func testNeighborsFollowListOrderWithoutWrapping() {
        XCTAssertEqual(pager.neighbor(of: "milk", .next), "eggs")
        XCTAssertEqual(pager.neighbor(of: "eggs", .previous), "milk")
        XCTAssertEqual(pager.neighbor(of: "eggs", .next), "bread")
        XCTAssertNil(pager.neighbor(of: "milk", .previous), "first item does not wrap")
        XCTAssertNil(pager.neighbor(of: "bread", .next), "last item does not wrap")
        XCTAssertNil(pager.neighbor(of: "unknown", .next))
    }

    func testPositionLabel() {
        XCTAssertEqual(pager.positionLabel(for: "milk"), "1 of 3")
        XCTAssertEqual(pager.positionLabel(for: "bread"), "3 of 3")
        XCTAssertNil(pager.positionLabel(for: "unknown"))
    }

    func testNoListMeansNoPaging() {
        let single = ItemPager(ids: ["milk"])
        XCTAssertFalse(single.isActive)
        XCTAssertNil(single.positionLabel(for: "milk"))
        XCTAssertNil(single.neighbor(of: "milk", .next))
        XCTAssertFalse(ItemPager(ids: []).isActive)
    }

    func testRemovedItemsAreSkipped() {
        let pruned = pager.keeping(["milk", "bread"])
        XCTAssertEqual(pruned.neighbor(of: "milk", .next), "bread")
        XCTAssertEqual(pruned.positionLabel(for: "bread"), "2 of 2")
    }

    func testSwipeDirection() {
        XCTAssertEqual(ItemPager.step(translation: CGSize(width: -80, height: 10), startX: 200), .next)
        XCTAssertEqual(ItemPager.step(translation: CGSize(width: 80, height: -10), startX: 200), .previous)
    }

    func testShortDiagonalAndBackEdgeSwipesAreIgnored() {
        XCTAssertNil(ItemPager.step(translation: CGSize(width: -40, height: 0), startX: 200), "too short")
        XCTAssertNil(ItemPager.step(translation: CGSize(width: -80, height: 70), startX: 200), "mostly vertical")
        XCTAssertNil(ItemPager.step(translation: CGSize(width: 120, height: 0), startX: 10), "system back gesture")
        XCTAssertEqual(
            ItemPager.step(translation: CGSize(width: -120, height: 0), startX: 10),
            .next,
            "a left swipe from the edge is not the back gesture"
        )
    }
}
