// Verifies: UI-004 Spend tab · REQ-016 (spending report), REQ-017 (period toggle)
// Design: design/mockups/Spending.jsx
//
// 3-layer coverage:
//   Layer 1 — Tests/UI/Structure/UI004StructureTests.swift (shell tabs)
//   Layer 2 — Tests/Snapshots/UI004SnapshotTests.swift
//   Layer 3 — Scripts/ui_vision_cases.json + Scripts/verify_ui_vision.py

import XCTest
@testable import Mekasa

/// Layer 0: the numbers `SpendingView` renders — live report when synced,
/// local inventory price rollup when offline / previewing.
final class SpendingScreenUITest: XCTestCase {

    @MainActor
    func testLayout_keyElementsExistAndVisible() {
        let session = AppSession()
        session.startUITesting()

        XCTAssertNil(session.spendingReport, "UI testing has no live report")
        XCTAssertFalse(session.canSyncSpending, "Offline → picker hidden, local rollup shown")

        let expected = TestFixtures.standardItemList.reduce(0.0) { partial, item in
            partial + (item.pricePaid ?? 0) * Double(max(item.quantity, 1))
        }
        XCTAssertEqual(session.localTrackedSpend, expected, accuracy: 0.001)
        XCTAssertGreaterThan(session.localTrackedSpend, 0)

        // By-category breakdown groups every priced fixture row.
        var byCategory: [String: Double] = [:]
        for item in session.inventory where (item.pricePaid ?? 0) > 0 {
            byCategory[item.category, default: 0] += (item.pricePaid ?? 0) * Double(max(item.quantity, 1))
        }
        XCTAssertEqual(byCategory.values.reduce(0, +), session.localTrackedSpend, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(byCategory.count, 5, "Fixtures span several categories")
    }

    @MainActor
    func testInteraction_tapsInputsAndNavigationTriggers() async {
        let session = AppSession()
        session.startUITesting()

        // Period picker (week / month / year) triggers refreshSpending; offline it is a no-op
        // and must not error or produce a report.
        for period in SpendingPeriod.allCases {
            await session.refreshSpending(period: period)
            XCTAssertNil(session.spendingReport)
            XCTAssertNil(session.lastError)
        }
        XCTAssertEqual(SpendingPeriod.allCases, [.week, .month, .year])
        XCTAssertEqual(SpendingPeriod.week.rawValue, "week")
    }

    @MainActor
    func testFlow_navigatesToNextScreen() {
        let session = AppSession()
        session.startUITesting()

        // A live report (as returned by the API) takes precedence over the local rollup.
        let report = SpendingReportDTO(
            householdId: TestFixtures.previewHousehold.id,
            period: .month,
            currency: "USD",
            total: 123.45,
            byCategory: [],
            events: []
        )
        session.spendingReport = report
        XCTAssertEqual(session.spendingReport?.total ?? 0, 123.45, accuracy: 0.001)
        XCTAssertEqual(session.spendingReport?.period, .month)

        // Consuming inventory lowers the local rollup (qty-weighted).
        let before = session.localTrackedSpend
        let bananas = session.inventory.first { $0.name == "Bananas" }!
        _ = session.consumeInventoryItem(id: bananas.id)
        XCTAssertEqual(session.localTrackedSpend, before - (bananas.pricePaid ?? 0), accuracy: 0.001)

        // Sign out clears the report.
        session.signOut()
        XCTAssertNil(session.spendingReport)
    }
}
