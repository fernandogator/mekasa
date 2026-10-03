// Verifies: UI-005 (Trash Station Mode) · REQ-006 (consume by barcode), REQ-007 (unknown scans)
// Design: design/mockups/TrashStationMode.jsx
//
// 3-layer coverage:
//   Layer 1 — Tests/UI/Structure/UI005StructureTests.swift
//   Layer 2 — Tests/Snapshots/UI005SnapshotTests.swift
//   Layer 3 — Scripts/ui_vision_cases.json + Scripts/verify_ui_vision.py

import XCTest
@testable import Mekasa

/// Layer 0: `TrashStationView` state — kiosk routing, scan → consume, unknown barcode
/// logging, recent event feed.
final class TrashStationModeUITest: XCTestCase {

    @MainActor
    func testLayout_keyElementsExistAndVisible() {
        let session = AppSession()
        session.startUITesting()

        // Recent events feed + last scanned item come from fixtures.
        XCTAssertEqual(session.trashEvents.count, TestFixtures.standardTrashEvents.count)
        XCTAssertEqual(session.trashEvents.first?.itemName, "Eggs")
        XCTAssertTrue(session.trashEvents.allSatisfy { $0.quantityDelta <= 0 }, "Trash never adds stock")
        XCTAssertTrue(session.unknownTrashScans.isEmpty)
        // Manual pick list shows only rows with stock.
        XCTAssertEqual(session.inventory.filter { $0.quantity > 0 }.count, session.inventory.count)

        // Empty variant shows the no-items copy instead of the pick list.
        let empty = AppSession()
        empty.startUITesting(emptyInventory: true)
        XCTAssertTrue(empty.inventory.isEmpty)
        XCTAssertTrue(empty.trashEvents.isEmpty)
    }

    @MainActor
    func testInteraction_tapsInputsAndNavigationTriggers() async {
        let session = AppSession()
        session.startUITesting()

        // Known barcode → decrement (Frozen Peas has no barcode; Oat Milk qty 2 does).
        let oatMilk = session.inventory.first { $0.barcode == "012345678905" }!
        XCTAssertEqual(oatMilk.quantity, 2)
        let first = await session.consumeInventoryByBarcode(" 012345678905 ")
        guard case let .decremented(name, remaining) = first else {
            return XCTFail("expected decremented, got \(first)")
        }
        XCTAssertEqual(name, "Organic Oat Milk")
        XCTAssertEqual(remaining, 1)

        // Scanning again depletes to 0 — never negative (REQ-006).
        let second = await session.consumeInventoryByBarcode("012345678905")
        guard case let .depleted(depletedName) = second else {
            return XCTFail("expected depleted, got \(second)")
        }
        XCTAssertEqual(depletedName, "Organic Oat Milk")
        XCTAssertEqual(session.inventory.first { $0.id == oatMilk.id }?.quantity, 0)
        let third = await session.consumeInventoryByBarcode("012345678905")
        guard case .depleted = third else {
            return XCTFail("depleted item stays at 0, got \(third)")
        }
        XCTAssertEqual(session.inventory.first { $0.id == oatMilk.id }?.quantity, 0)

        // Depleted row auto-appears on the shopping list (REQ-011).
        XCTAssertTrue(session.shoppingList.contains { $0.inventoryItemID == oatMilk.id && !$0.isChecked })
    }

    @MainActor
    func testFlow_navigatesToNextScreen() async {
        let session = AppSession()
        session.startUITesting()
        let eventsBefore = session.trashEvents.count

        // Unknown barcode → logged as an Unknown event with zero delta (REQ-007), no inventory change.
        let quantitiesBefore = session.inventory.map(\.quantity)
        let result = await session.consumeInventoryByBarcode("000000000000")
        guard case .unknown = result else {
            return XCTFail("expected unknown, got \(result)")
        }
        XCTAssertEqual(session.trashEvents.count, eventsBefore + 1)
        XCTAssertEqual(session.trashEvents.first?.itemName, "Unknown (000000000000)")
        XCTAssertEqual(session.trashEvents.first?.quantityDelta, 0)
        XCTAssertEqual(session.inventory.map(\.quantity), quantitiesBefore)
        XCTAssertEqual(session.activity.first?.title, "Unknown trash scan 000000000000")

        // Blank scans are ignored entirely.
        let blank = await session.consumeInventoryByBarcode("   ")
        guard case .unknown = blank else { return XCTFail("blank should be unknown") }
        XCTAssertEqual(session.trashEvents.count, eventsBefore + 1, "Blank scan must not log an event")
    }

    @MainActor
    func testFlow_kioskModeRouting() {
        let session = AppSession()
        session.startUITesting()
        XCTAssertFalse(session.isTrashKioskMode)

        // Family → Open trash kiosk, or launch arg --trash-station / mekasa://trash.
        session.handleDeepLink(URL(string: "mekasa://trash")!)
        XCTAssertTrue(session.isTrashKioskMode)
        XCTAssertEqual(session.onboardingStep, .done, "RootView shows TrashStationView(kioskMode:) under .done")

        // Exit kiosk returns to the shell; sign out also clears kiosk mode.
        session.isTrashKioskMode = false
        XCTAssertFalse(session.isTrashKioskMode)
        session.isTrashKioskMode = true
        session.signOut()
        XCTAssertFalse(session.isTrashKioskMode)
        XCTAssertEqual(session.onboardingStep, .welcome)
    }
}
