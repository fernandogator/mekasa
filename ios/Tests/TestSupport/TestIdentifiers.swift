import Foundation

/// Shared accessibility identifiers for SwiftUI views and XCUITests.
/// Satisfies: UI-001–UI-005 (traceability / structural tests)
/// Spec version: 1.0
enum TestIdentifiers {
    // MARK: - Item List
    static let itemList = "ItemList"
    static let addItemButton = "AddItemButton"
    static let scanButton = "ScanButton"
    static let itemCell = "ItemCell"
    static let itemThumbnail = "ItemThumbnail"
    static let itemTitle = "ItemTitle"
    static let itemSubtitle = "ItemSubtitle"
    static let emptyStateView = "EmptyStateView"

    // MARK: - Item Detail
    static let itemDetailView = "ItemDetailView"
    static let itemImage = "ItemImage"
    static let itemNameLabel = "ItemNameLabel"
    static let editButton = "EditButton"
    static let deleteButton = "DeleteButton"
    static let quantityControl = "QuantityControl"

    // MARK: - Add / Edit Item
    static let addItemForm = "AddItemForm"
    static let nameField = "NameField"
    static let categoryPicker = "CategoryPicker"
    static let quantityField = "QuantityField"
    static let locationField = "LocationField"
    static let saveButton = "SaveButton"
    static let cancelButton = "CancelButton"

    // MARK: - Request Queue
    static let requestQueue = "RequestQueue"
    static let requestCell = "RequestCell"
    static let approveButton = "ApproveButton"
    static let rejectButton = "RejectButton"
    static let requestorLabel = "RequestorLabel"
    static let requestedItemLabel = "RequestedItemLabel"

    // MARK: - Trash Station
    static let trashStationView = "TrashStationView"
    static let scanPromptLabel = "ScanPromptLabel"
    static let lastScannedItem = "LastScannedItem"
    static let trashEventList = "TrashEventList"

    // MARK: - Shell / onboarding / dashboard (UI-002–UI-004)
    static let rootView = "RootView"
    static let welcomeView = "WelcomeView"
    static let mainShellView = "MainShellView"
    static let dashboardView = "DashboardView"
    static let shoppingListView = "ShoppingListView"
    static let addItemsHub = "AddItemsHub"
    static let bottomNavBar = "BottomNavBar"
    static let homeTab = "HomeTab"
    static let listTab = "ListTab"
}
