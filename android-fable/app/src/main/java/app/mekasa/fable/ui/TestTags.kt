package app.mekasa.fable.ui

/**
 * Stable `Modifier.testTag` values shared by the screens and the JVM UI tests
 * (Layer 1 structural, Layer 2 snapshots). Names mirror
 * `ios/Tests/TestSupport/TestIdentifiers.swift` where a counterpart exists so the
 * two platforms' structural tests read the same way.
 *
 * Satisfies: UI-001, UI-003–UI-006 (traceability / structural tests). Spec version: 1.0
 */
object TestTags {
    // Root / shell (UI-001)
    const val ERROR_DIALOG = "ErrorDialog"
    const val MAIN_SHELL_VIEW = "MainShellView"
    const val BOTTOM_NAV_BAR = "BottomNavBar"
    const val ADD_ITEM_BUTTON = "AddItemButton"
    const val HOME_TAB = "HomeTab"
    const val LIST_TAB = "ListTab"
    const val SPEND_TAB = "SpendTab"
    const val FAMILY_TAB = "FamilyTab"
    const val BACK_BUTTON = "BackButton"

    fun tab(label: String) = "${label}Tab"

    // Welcome / onboarding (UI-003)
    const val WELCOME_VIEW = "WelcomeView"
    const val SESSION_NOTICE = "SessionNotice"
    const val EMAIL_FIELD = "EmailField"
    const val PASSWORD_FIELD = "PasswordField"
    const val TOGGLE_CREATE_ACCOUNT = "ToggleCreateAccount"
    const val CONTINUE_WITH_EMAIL = "ContinueWithEmail"
    const val BROWSE_OFFLINE = "BrowseOffline"
    const val SUBMIT_EMAIL = "SubmitEmail"
    const val HOUSEHOLD_NAME_VIEW = "HouseholdNameView"
    const val HOUSEHOLD_NAME_FIELD = "HouseholdNameField"
    const val HOUSEHOLD_CONTINUE = "HouseholdContinue"
    const val HOUSEHOLD_SKIP = "HouseholdSkip"
    const val ADDRESS_VIEW = "AddressView"
    const val ADDRESS_FIELD = "AddressField"
    const val ADDRESS_CONTINUE = "AddressContinue"
    const val STORE_SELECTION_VIEW = "StoreSelectionView"
    const val STORES_CONTINUE = "StoresContinue"

    fun storeRow(id: String) = "StoreRow-$id"

    // Dashboard (UI-004)
    const val DASHBOARD_VIEW = "DashboardView"
    const val HOME_PHOTO_HERO = "HomePhotoHero"
    const val EDIT_HOME_BUTTON = "EditHomeButton"
    const val LOW_STOCK_STAT_BUTTON = "LowStockStatButton"
    const val SPEND_STAT_BUTTON = "SpendStatButton"
    const val ALL_INVENTORY_BUTTON = "AllInventoryButton"
    const val OPEN_LIST_BUTTON = "OpenListButton"

    // Home photo (REQ-002 / UI-004 AC3)
    const val HOME_PHOTO_VIEW = "HomePhotoView"
    const val HOME_PHOTO_PREVIEW = "HomePhotoPreview"
    const val HOME_PHOTO_CAMERA_BUTTON = "HomePhotoCameraButton"
    const val HOME_PHOTO_LIBRARY_BUTTON = "HomePhotoLibraryButton"
    const val HOME_PHOTO_NAME_FIELD = "HomePhotoNameField"
    const val HOME_PHOTO_SAVE_BUTTON = "HomePhotoSaveButton"
    const val HOME_PHOTO_SAVE_BOTTOM_BUTTON = "HomePhotoSaveBottomButton"

    // Inventory list / swipe (UI-006 · REQ-INV-014–018)
    const val INVENTORY_LIST_VIEW = "InventoryListView"
    const val ITEM_LIST = "ItemList"
    const val EMPTY_STATE_VIEW = "EmptyStateView"
    const val INVENTORY_SEARCH = "InventorySearch"
    const val INVENTORY_ADD_BUTTON = "InventoryAddButton"
    const val INVENTORY_USE_ONE_ACTION = "InventoryUseOneAction"
    const val INVENTORY_REMOVE_ACTION = "InventoryRemoveAction"
    const val INVENTORY_UNDO_TOAST = "InventoryUndoToast"
    const val INVENTORY_UNDO_BUTTON = "InventoryUndoButton"

    fun itemCell(id: String) = "ItemCell-$id"
    fun useOne(id: String) = "UseOne-$id"

    // Item detail (UI-006)
    const val ITEM_DETAIL_VIEW = "ItemDetailView"
    const val ITEM_IMAGE = "ItemImage"
    const val ITEM_LIGHTBOX = "ItemLightbox"
    const val QUANTITY_CONTROL = "QuantityControl"
    const val THRESHOLD_CONTROL = "ThresholdControl"

    // Shopping list (REQ-011–014)
    const val SHOPPING_LIST_VIEW = "ShoppingListView"
    const val SYNC_LOW_STOCK = "SyncLowStock"
    const val SHOPPING_ADD_TOGGLE = "ShoppingAddToggle"
    const val ADD_SHOPPING_CARD = "AddShoppingCard"
    const val SHOPPING_NAME_FIELD = "ShoppingNameField"
    const val SHOPPING_ADD_SUBMIT = "ShoppingAddSubmit"
    const val SHOPPING_EMPTY = "ShoppingEmpty"
    const val PURCHASE_LOCK_NOTICE = "PurchaseLockNotice"

    fun shoppingRow(id: String) = "ShoppingRow-$id"
    fun shoppingToggle(id: String) = "Toggle-$id"
    fun shoppingRemove(id: String) = "Remove-$id"
    fun approve(id: String) = "ApproveButton-$id"
    fun reject(id: String) = "RejectButton-$id"

    // Spending (REQ-018)
    const val SPENDING_VIEW = "SpendingView"
    const val PERIOD_TOGGLE = "PeriodToggle"
    const val SPENDING_TOTAL = "SpendingTotal"
    const val SPENDING_EMPTY = "SpendingEmpty"

    fun period(key: String) = "Period-$key"

    // Family / settings (REQ-019)
    const val FAMILY_VIEW = "FamilyView"
    const val INVITE_NAME = "InviteName"
    const val INVITE_EMAIL = "InviteEmail"
    const val CREATE_INVITE = "CreateInvite"
    const val OPEN_KIOSK = "OpenKiosk"
    const val OPEN_TRASH = "OpenTrash"
    const val SIGN_OUT = "SignOut"

    fun member(uid: String) = "Member-$uid"

    // Trash station (UI-005 · REQ-008)
    const val TRASH_STATION_VIEW = "TrashStationView"
    const val TRASH_KIOSK_VIEW = "TrashKioskView"
    const val EXIT_KIOSK = "ExitKiosk"
    const val SCAN_FLASH = "ScanFlash"
    const val SCAN_COOLDOWN = "ScanCooldown"
    const val MANUAL_BARCODE = "ManualBarcode"
    const val MANUAL_CONSUME = "ManualConsume"
    const val BARCODE_SCANNER = "BarcodeScanner"
    const val ALLOW_CAMERA = "AllowCamera"

    fun trashUse(id: String) = "TrashUse-$id"

    // Add items hub (REQ-004–007)
    const val ADD_ITEMS_HUB = "AddItemsHub"
    const val ADD_BACK = "AddBack"
    const val ADD_BARCODE = "Add-Barcode"
    const val ADD_SEARCH = "Add-Search"
    const val ADD_VOICE = "Add-Voice"
    const val ADD_RECEIPT = "Add-Receipt"
    const val ADD_TRASH = "Add-Trash"
    const val ADD_UNKNOWN_BARCODE = "AddUnknownBarcode"
    const val LOOKUP_BARCODE = "LookupBarcode"
    const val SEARCH_QUERY = "SearchQuery"
    const val SEARCH_PRODUCTS = "SearchProducts"
    const val ADD_WITHOUT_MATCH = "AddWithoutMatch"
    const val VOICE_MIC = "VoiceMic"
    const val VOICE_PHRASE = "VoicePhrase"
    const val INTERPRET_PHRASE = "InterpretPhrase"
    const val VOICE_PARSED = "VoiceParsed"
    const val RECEIPT_CAMERA = "ReceiptCamera"
    const val RECEIPT_GALLERY = "ReceiptGallery"
    const val RECEIPT_TEXT = "ReceiptText"
    const val SAMPLE_RECEIPT = "SampleReceipt"
    const val SCAN_RECEIPT = "ScanReceipt"
    const val SAVE_RECEIPT = "SaveReceipt"
    const val CONFIRM_NAME = "ConfirmName"
    const val CONFIRM_CATEGORY = "ConfirmCategory"
    const val CONFIRM_PRICE = "ConfirmPrice"
    const val QTY_MINUS = "QtyMinus"
    const val QTY_VALUE = "QtyValue"
    const val QTY_PLUS = "QtyPlus"
    const val SAVE_ITEM = "SaveItem"

    fun result(name: String) = "Result-$name"
    fun receiptLine(index: Int) = "ReceiptLine-$index"
}
