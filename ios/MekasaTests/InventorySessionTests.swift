import XCTest
@testable import Mekasa

/// Unit coverage for local inventory staging (REQ-004–008 client path).
final class InventorySessionTests: XCTestCase {

    @MainActor
    func testAddInventoryItem_insertsAndLogsActivity() {
        let session = AppSession()
        session.activity = []
        session.addInventoryItem(
            InventoryItem(name: "Avocados", category: "Produce", quantity: 2, source: .manual)
        )
        XCTAssertEqual(session.inventory.count, 1)
        XCTAssertEqual(session.inventory[0].name, "Avocados")
        XCTAssertEqual(session.inventory[0].quantity, 2)
        XCTAssertEqual(session.activity.first?.title, "Added Avocados")
    }

    @MainActor
    func testAddInventoryItem_mergesSameNameAndCategory() {
        let session = AppSession()
        session.addInventoryItem(
            InventoryItem(name: "Milk", category: "Dairy", quantity: 1, source: .manual)
        )
        session.addInventoryItem(
            InventoryItem(name: "milk", category: "Dairy", quantity: 2, price: .barcode)
        )
        XCTAssertEqual(session.inventory.count, 1)
        XCTAssertEqual(session.inventory[0].quantity, 3)
    }

    @MainActor
    func testConsumeInventoryItem_decrementsThenDepletes() {
        let session = AppSession()
        let item = InventoryItem(name: "Eggs", category: "Dairy", quantity: 2, source: .manual)
        session.addInventoryItem(item)
        let id = session.inventory[0].id

        if case let .decremented(name, remaining) = session.consumeInventoryItem(id: id) {
            XCTAssertEqual(name, "Eggs")
            XCTAssertEqual(remaining, 1)
        } else {
            XCTFail("Expected decremented")
        }

        if case let .depleted(name) = session.consumeInventoryItem(id: id) {
            XCTAssertEqual(name, "Eggs")
        } else {
            XCTFail("Expected depleted")
        }
        XCTAssertEqual(session.inventory[0].quantity, 0)
    }

    @MainActor
    func testLowStockCount_usesLiveInventoryWhenPresent() {
        let session = AppSession()
        XCTAssertEqual(session.lowStockCount, DashboardFixtures.lowStockCount)
        session.addInventoryItem(
            InventoryItem(name: "Pasta", category: "Pantry", quantity: 1, lowStockThreshold: 1, source: .manual)
        )
        session.addInventoryItem(
            InventoryItem(name: "Rice", category: "Pantry", quantity: 5, lowStockThreshold: 1, source: .manual)
        )
        XCTAssertEqual(session.lowStockCount, 1)
    }

    @MainActor
    func testAddInventoryItem_skipsAPIWithoutHousehold() {
        let session = AppSession()
        session.idToken = "preview"
        session.isUIPreview = true
        XCTAssertFalse(session.canSyncInventory)
        session.addInventoryItem(
            InventoryItem(name: "Local Only", category: "Other", quantity: 1, source: .manual)
        )
        XCTAssertEqual(session.inventory.count, 1)
    }

    func testDemoCatalog_knownBarcodeLookup() {
        let item = InventoryDemoCatalog.lookup(barcode: InventoryDemoCatalog.sampleBarcode)
        XCTAssertEqual(item?.name, "Organic Oat Milk")
        XCTAssertNil(InventoryDemoCatalog.lookup(barcode: "000000000000"))
    }
}
