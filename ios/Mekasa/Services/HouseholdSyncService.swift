import Foundation
import FirebaseCore
import FirebaseFirestore

/// Client Firestore listeners for inventory + shopping list (REQ-020).
/// Mutations stay on Cloud Run; this layer only mirrors server truth.
/// Spec version: 1.0
@MainActor
final class HouseholdSyncService: ObservableObject {
    static let shared = HouseholdSyncService()

    /// Named DB must match Cloud Run (`mekasa-db`).
    static let databaseID = "mekasa-db"

    @Published private(set) var isListening = false
    @Published private(set) var lastError: String?

    private var inventoryListener: ListenerRegistration?
    private var shoppingListener: ListenerRegistration?
    private var activeHouseholdID: String?

    private var db: Firestore? {
        guard FirebaseBootstrap.isConfigured else { return nil }
        let firestore = Firestore.firestore(database: Self.databaseID)
        // FirestoreSettings is a class, so the binding never changes — only the object.
        let settings = firestore.settings
        settings.cacheSettings = PersistentCacheSettings()
        firestore.settings = settings
        return firestore
    }

    func start(
        householdID: String,
        onInventory: @escaping ([InventoryItem]) -> Void,
        onShoppingList: @escaping ([ShoppingListItem]) -> Void
    ) {
        guard activeHouseholdID != householdID || !isListening else { return }
        stop()
        guard let db else {
            lastError = "Firebase not configured — realtime sync paused."
            return
        }

        activeHouseholdID = householdID
        lastError = nil

        let inventoryPath = db.collection("households").document(householdID)
            .collection("inventory_items")
        inventoryListener = inventoryPath.addSnapshotListener { snapshot, error in
            Task { @MainActor in
                if let error {
                    self.lastError = error.localizedDescription
                    return
                }
                guard let docs = snapshot?.documents else { return }
                let items = docs.compactMap { doc -> InventoryItem? in
                    FirestoreDocumentMapper.inventoryItem(id: doc.documentID, data: doc.data())
                }
                .sorted { $0.updatedAt > $1.updatedAt }
                onInventory(items)
            }
        }

        let shoppingPath = db.collection("households").document(householdID)
            .collection("shopping_list_items")
        shoppingListener = shoppingPath.addSnapshotListener { snapshot, error in
            Task { @MainActor in
                if let error {
                    self.lastError = error.localizedDescription
                    return
                }
                guard let docs = snapshot?.documents else { return }
                let items = docs.compactMap { doc -> ShoppingListItem? in
                    FirestoreDocumentMapper.shoppingListItem(id: doc.documentID, data: doc.data())
                }
                onShoppingList(items)
            }
        }

        isListening = true
    }

    func stop() {
        inventoryListener?.remove()
        shoppingListener?.remove()
        inventoryListener = nil
        shoppingListener = nil
        activeHouseholdID = nil
        isListening = false
    }
}
