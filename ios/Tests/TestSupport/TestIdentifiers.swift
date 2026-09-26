import Foundation

/// Shared accessibility identifiers for SwiftUI views and XCUITests.
/// Satisfies: UI-001–UI-006 (traceability / structural tests)
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

    // MARK: - Inventory list / swipe (UI-006 · REQ-INV-014–018)
    static let inventoryListView = "InventoryListView"
    static let inventoryUseOneAction = "InventoryUseOneAction"
    static let inventoryRemoveAction = "InventoryRemoveAction"
    static let inventoryUndoToast = "InventoryUndoToast"
    static let inventoryUndoButton = "InventoryUndoButton"
    static let allInventoryButton = "AllInventoryButton"
    static let lowStockStatButton = "LowStockStatButton"

    // MARK: - Item Detail
    static let itemDetailView = "ItemDetailView"
    static let itemImage = "ItemImage"
    static let itemNameLabel = "ItemNameLabel"
    static let itemBarcodeLabel = "ItemBarcodeLabel"
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
    static let scanCooldownOverlay = "ScanCooldownOverlay"

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

    // MARK: - Home photo (REQ-002 / UI-004 AC3)
    static let homePhotoHero = "HomePhotoHero"
    static let homePhotoView = "HomePhotoView"
    static let homePhotoPreview = "HomePhotoPreview"
    static let homePhotoCameraButton = "HomePhotoCameraButton"
    static let homePhotoLibraryButton = "HomePhotoLibraryButton"
    static let homePhotoNameField = "HomePhotoNameField"
    static let homePhotoSaveBottomButton = "HomePhotoSaveBottomButton"

    // MARK: - Health grade + avoidances (REQ-021)
    static let healthGradeBadge = "HealthGradeBadge"
    static let healthSummaryCard = "HealthSummaryCard"
    static let memberWarningBanner = "MemberWarningBanner"
    static let avoidEditorView = "AvoidEditorView"
    static let avoidCustomField = "AvoidCustomField"
    static let avoidSaveButton = "AvoidSaveButton"
    static let memberAvoidLabel = "MemberAvoidLabel"
    static let memberAvoidEditButton = "MemberAvoidEditButton"
}
