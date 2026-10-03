package app.mekasa.fable.data.demo

import app.mekasa.fable.data.HouseholdBackend
import app.mekasa.fable.data.InventoryDraft
import app.mekasa.fable.data.model.BarcodeLookup
import app.mekasa.fable.data.model.ConsumeByBarcodeResult
import app.mekasa.fable.data.model.Household
import app.mekasa.fable.data.model.HouseholdInvite
import app.mekasa.fable.data.model.HouseholdMember
import app.mekasa.fable.data.model.InventoryItem
import app.mekasa.fable.data.model.ProductHit
import app.mekasa.fable.data.model.ReceiptLine
import app.mekasa.fable.data.model.ReceiptScanResponse
import app.mekasa.fable.data.model.ShoppingItem
import app.mekasa.fable.data.model.SpendingCategoryTotal
import app.mekasa.fable.data.model.SpendingReport
import app.mekasa.fable.data.model.Store
import app.mekasa.fable.data.model.UnknownBarcodeEvent
import app.mekasa.fable.data.model.UserProfile
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * In-memory [HouseholdBackend] behind the Welcome screen's "Browse UI offline"
 * button and the JVM unit tests. It mirrors the server rules that matter to the
 * UI: quantities never go negative, unknown trash scans are logged, low-stock
 * items sync onto the shopping list, and only the owner may upload a photo.
 */
class DemoBackend(
    val uid: String = DEMO_UID,
    private val clock: () -> Long = System::currentTimeMillis,
) : HouseholdBackend {

    override val isDemo: Boolean = true

    private val lock = Mutex()
    private var household: Household? = null
    private val inventoryRows = mutableListOf<InventoryItem>()
    private val shoppingRows = mutableListOf<ShoppingItem>()
    private val memberRows = mutableListOf<HouseholdMember>()
    private val inviteRows = mutableListOf<HouseholdInvite>()
    private val unknownRows = mutableListOf<UnknownBarcodeEvent>()
    private var seq = 100

    init {
        seedSampleHousehold()
    }

    private fun nextId(prefix: String): String = "$prefix-${seq++}"

    private fun seedSampleHousehold() {
        household = Household(
            id = HOUSEHOLD_ID,
            name = "The Guerrero Home",
            ownerUid = uid,
            address = "123 Peachtree St, Atlanta, GA",
            storeIds = listOf("publix-midtown", "kroger-ponce"),
        )
        inventoryRows += listOf(
            InventoryItem(
                id = nextId("inv"), householdId = HOUSEHOLD_ID, name = "Diet Coke", category = "Beverages",
                quantity = 2, lowStockThreshold = 3, barcode = DIET_COKE_UPC, source = "barcode",
                imageUrl = "https://images.openfoodfacts.org/images/products/004/900/002/8911/front_en.jpg",
            ),
            InventoryItem(
                id = nextId("inv"), householdId = HOUSEHOLD_ID, name = "Whole Milk", category = "Dairy",
                quantity = 1, lowStockThreshold = 2, barcode = "041900076543", pricePaid = 3.49,
            ),
            InventoryItem(
                id = nextId("inv"), householdId = HOUSEHOLD_ID, name = "Sourdough Bread", category = "Bakery",
                quantity = 4, lowStockThreshold = 1, pricePaid = 4.99,
            ),
            InventoryItem(
                id = nextId("inv"), householdId = HOUSEHOLD_ID, name = "Paper Towels", category = "Household",
                quantity = 6, lowStockThreshold = 2, barcode = "030772034828",
            ),
        )
        shoppingRows += listOf(
            ShoppingItem(
                id = nextId("shop"), householdId = HOUSEHOLD_ID, name = "Diet Coke", quantity = 1,
                kind = "auto", inventoryItemId = inventoryRows.first().id,
            ),
            ShoppingItem(
                id = nextId("shop"), householdId = HOUSEHOLD_ID, name = "Avocados", quantity = 3,
                kind = "request", needsApproval = true, requestedBy = "Mateo",
            ),
        )
        memberRows += HouseholdMember(
            uid = uid, householdId = HOUSEHOLD_ID, name = "Preview", email = DEMO_EMAIL, role = "owner",
        )
        memberRows += HouseholdMember(
            uid = "demo-kid", householdId = HOUSEHOLD_ID, name = "Mateo", role = "member",
        )
    }

    // ---------------------------------------------------------- household

    override suspend fun profile(): UserProfile = UserProfile(uid = uid, email = DEMO_EMAIL, name = "Preview")

    override suspend fun currentHousehold(): Household? = lock.withLock { household }

    override suspend fun createHousehold(name: String?): Household = lock.withLock {
        Household(id = HOUSEHOLD_ID, name = name, ownerUid = uid).also { household = it }
    }

    override suspend fun updateAddress(householdId: String, address: String): Household = mutateHousehold {
        it.copy(address = address, latitude = 33.78, longitude = -84.38)
    }

    override suspend fun nearbyStores(householdId: String): List<Store> = SAMPLE_STORES

    override suspend fun selectStores(householdId: String, storeIds: List<String>): Household = mutateHousehold {
        it.copy(storeIds = storeIds)
    }

    override suspend fun renameHousehold(householdId: String, name: String?): Household = mutateHousehold {
        it.copy(name = name)
    }

    override suspend fun uploadHomePhoto(householdId: String, jpeg: ByteArray): Household {
        require(jpeg.isNotEmpty()) { "Empty photo" }
        val encoded = java.util.Base64.getEncoder().encodeToString(jpeg)
        return mutateHousehold { it.copy(photoUrl = "data:image/jpeg;base64,$encoded") }
    }

    private suspend fun mutateHousehold(transform: (Household) -> Household): Household = lock.withLock {
        val current = household ?: error("No household yet")
        transform(current).also { household = it }
    }

    // ---------------------------------------------------------- inventory

    override suspend fun inventory(householdId: String): List<InventoryItem> = lock.withLock { inventoryRows.filterNot { it.deleted } }

    override suspend fun addInventory(householdId: String, draft: InventoryDraft): InventoryItem = lock.withLock {
        InventoryItem(
            id = nextId("inv"),
            householdId = householdId,
            name = draft.name,
            category = draft.category,
            quantity = draft.quantity.coerceAtLeast(0),
            barcode = draft.barcode,
            imageUrl = draft.imageUrl,
            source = draft.source,
            pricePaid = draft.pricePaid,
        ).also { inventoryRows.add(0, it) }
    }

    override suspend fun updateInventory(
        householdId: String,
        itemId: String,
        quantity: Int?,
        threshold: Int?,
    ): InventoryItem = replaceInventory(itemId) {
        it.copy(
            quantity = quantity?.coerceAtLeast(0) ?: it.quantity,
            lowStockThreshold = threshold?.coerceAtLeast(0) ?: it.lowStockThreshold,
        )
    }

    override suspend fun consume(householdId: String, itemId: String, amount: Int): InventoryItem =
        replaceInventory(itemId) { it.copy(quantity = (it.quantity - amount).coerceAtLeast(0)) }

    override suspend fun consumeByBarcode(householdId: String, barcode: String, amount: Int): ConsumeByBarcodeResult =
        lock.withLock {
            val index = inventoryRows.indexOfFirst { it.barcode == barcode && it.quantity > 0 }
            if (index < 0) {
                val event = UnknownBarcodeEvent(
                    id = nextId("unk"),
                    householdId = householdId,
                    barcode = barcode,
                    scannedByUid = uid,
                    createdAt = "just now",
                )
                unknownRows.add(0, event)
                ConsumeByBarcodeResult(found = false, unknownEvent = event)
            } else {
                val updated = inventoryRows[index].let {
                    it.copy(quantity = (it.quantity - amount).coerceAtLeast(0))
                }
                inventoryRows[index] = updated
                ConsumeByBarcodeResult(found = true, item = updated)
            }
        }

    override suspend fun refreshImage(householdId: String, itemId: String): InventoryItem = replaceInventory(itemId) {
        if (it.hasImage) it else it.copy(imageUrl = CATALOG.firstOrNull { c -> c.barcode == it.barcode }?.imageUrl)
    }

    override suspend fun unknownScans(householdId: String): List<UnknownBarcodeEvent> = lock.withLock { unknownRows.toList() }

    override suspend fun softDeleteInventory(householdId: String, itemId: String) {
        replaceInventory(itemId) { it.copy(deleted = true) }
    }

    override suspend fun restoreInventory(householdId: String, itemId: String): InventoryItem =
        replaceInventory(itemId) { it.copy(deleted = false) }

    override suspend fun purgeInventory(householdId: String, itemId: String) {
        lock.withLock { inventoryRows.removeAll { it.id == itemId } }
    }

    private suspend fun replaceInventory(itemId: String, transform: (InventoryItem) -> InventoryItem): InventoryItem =
        lock.withLock {
            val index = inventoryRows.indexOfFirst { it.id == itemId }
            require(index >= 0) { "Item not found" }
            transform(inventoryRows[index]).also { inventoryRows[index] = it }
        }

    // ------------------------------------------------------ shopping list

    override suspend fun shoppingList(householdId: String): List<ShoppingItem> = lock.withLock { shoppingRows.toList() }

    override suspend fun addShoppingItem(householdId: String, name: String, quantity: Int): ShoppingItem = lock.withLock {
        ShoppingItem(id = nextId("shop"), householdId = householdId, name = name, quantity = quantity.coerceAtLeast(1))
            .also { shoppingRows.add(0, it) }
    }

    override suspend fun setShoppingChecked(householdId: String, itemId: String, checked: Boolean): ShoppingItem =
        replaceShopping(itemId) { it.copy(isChecked = checked) }

    override suspend fun deleteShoppingItem(householdId: String, itemId: String) {
        lock.withLock { shoppingRows.removeAll { it.id == itemId } }
    }

    override suspend fun approveShoppingItem(householdId: String, itemId: String): ShoppingItem =
        replaceShopping(itemId) { it.copy(needsApproval = false, kind = "custom") }

    override suspend fun rejectShoppingItem(householdId: String, itemId: String): ShoppingItem = lock.withLock {
        val row = shoppingRows.first { it.id == itemId }
        shoppingRows.remove(row)
        row.copy(needsApproval = false)
    }

    override suspend fun syncShoppingFromInventory(householdId: String): List<ShoppingItem> = lock.withLock {
        val existing = shoppingRows.mapNotNull { it.inventoryItemId }.toSet()
        inventoryRows.filter { it.isLowStock && it.id !in existing }.forEach { low ->
            shoppingRows.add(
                0,
                ShoppingItem(
                    id = nextId("shop"), householdId = householdId, name = low.name, quantity = 1,
                    kind = "auto", inventoryItemId = low.id,
                ),
            )
        }
        shoppingRows.toList()
    }

    private suspend fun replaceShopping(itemId: String, transform: (ShoppingItem) -> ShoppingItem): ShoppingItem =
        lock.withLock {
            val index = shoppingRows.indexOfFirst { it.id == itemId }
            require(index >= 0) { "Shopping item not found" }
            transform(shoppingRows[index]).also { shoppingRows[index] = it }
        }

    // ----------------------------------------------------------- spending

    override suspend fun spending(householdId: String, period: String): SpendingReport {
        val multiplier = when (period) {
            "month" -> 4.2
            "year" -> 49.0
            else -> 1.0
        }
        val categories = listOf(
            SpendingCategoryTotal("Groceries", 54.10 * multiplier),
            SpendingCategoryTotal("Beverages", 18.20 * multiplier),
            SpendingCategoryTotal("Household", 14.12 * multiplier),
        )
        return SpendingReport(
            period = period,
            total = categories.sumOf { it.total },
            byCategory = categories,
            householdId = householdId,
        )
    }

    // ------------------------------------------------------------ members

    override suspend fun members(householdId: String): List<HouseholdMember> = lock.withLock { memberRows.toList() }

    override suspend fun invites(householdId: String): List<HouseholdInvite> = lock.withLock { inviteRows.toList() }

    override suspend fun createInvite(householdId: String, name: String, email: String?, role: String): HouseholdInvite =
        lock.withLock {
            val token = "demo-${clock()}"
            HouseholdInvite(
                id = nextId("inv"), householdId = householdId, name = name, email = email, role = role,
                token = token, invitedByUid = uid, inviteLink = "mekasa://invite?token=$token",
            ).also { inviteRows.add(0, it) }
        }

    override suspend fun acceptInvite(inviteToken: String): HouseholdMember = lock.withLock {
        memberRows.first { it.uid == uid }
    }

    override suspend fun updateMemberRole(householdId: String, memberUid: String, role: String): HouseholdMember =
        lock.withLock {
            val index = memberRows.indexOfFirst { it.uid == memberUid }
            require(index >= 0) { "Member not found" }
            memberRows[index].copy(role = role).also { memberRows[index] = it }
        }

    // ------------------------------------------------------------ catalog

    override suspend fun lookupBarcode(code: String): BarcodeLookup {
        val hit = CATALOG.firstOrNull { it.barcode == code }
        return if (hit == null) {
            BarcodeLookup(barcode = code, found = false)
        } else {
            BarcodeLookup(
                barcode = code, found = true, name = hit.name, brand = hit.brand,
                category = hit.category, imageUrl = hit.imageUrl, source = "openfoodfacts",
            )
        }
    }

    override suspend fun searchProducts(query: String): List<ProductHit> {
        val needle = query.trim().lowercase()
        if (needle.isEmpty()) return emptyList()
        return CATALOG.filter { hit ->
            hit.name.lowercase().contains(needle) || hit.brand?.lowercase()?.contains(needle) == true
        }
    }

    override suspend fun scanReceipt(householdId: String, rawText: String?, imageBase64: String?): ReceiptScanResponse =
        ReceiptScanResponse(householdId = householdId, engine = "demo", items = DEMO_RECEIPT)

    companion object {
        const val DEMO_UID = "demo-owner"
        const val DEMO_EMAIL = "preview@mekasa.local"
        const val HOUSEHOLD_ID = "demo-home"
        const val DIET_COKE_UPC = "049000028911"

        val SAMPLE_STORES = listOf(
            Store("publix-midtown", "Publix", "950 W Peachtree St NW, Atlanta", distanceMiles = 0.8),
            Store("kroger-ponce", "Kroger", "725 Ponce De Leon Ave NE, Atlanta", distanceMiles = 1.6),
            Store("costco-brookhaven", "Costco", "500 Brookhaven Ave NE, Atlanta", distanceMiles = 5.2),
            Store("walmart-howell", "Walmart Supercenter", "1801 Howell Mill Rd NW, Atlanta", distanceMiles = 3.1),
        )

        val CATALOG = listOf(
            ProductHit(
                barcode = DIET_COKE_UPC, name = "Diet Coke", brand = "Coca-Cola", category = "Beverages",
                imageUrl = "https://images.openfoodfacts.org/images/products/004/900/002/8911/front_en.jpg",
            ),
            ProductHit(barcode = "049000042566", name = "Coca-Cola Classic", brand = "Coca-Cola", category = "Beverages"),
            ProductHit(barcode = "044000032029", name = "Oreo Cookies", brand = "Nabisco", category = "Snacks"),
            ProductHit(barcode = "025293001718", name = "Oat Milk", brand = "Oatly", category = "Dairy"),
            ProductHit(barcode = "041900076543", name = "Whole Milk", brand = "Kroger", category = "Dairy"),
            ProductHit(barcode = null, name = "Avocados", brand = null, category = "Produce"),
            ProductHit(barcode = null, name = "Bananas", brand = null, category = "Produce"),
        )

        const val DEMO_RECEIPT_TEXT = """PUBLIX SUPER MARKETS
BANANAS            1.29
WHOLE MILK         3.49
SOURDOUGH LOAF     4.99
SUBTOTAL           9.77
TOTAL              9.77"""

        val DEMO_RECEIPT = listOf(
            ReceiptLine("Bananas", "Produce", 1, 1.29, identified = true),
            ReceiptLine("Whole Milk", "Dairy", 1, 3.49, barcode = "041900076543", identified = true),
            ReceiptLine("Sourdough Loaf", "Bakery", 1, 4.99, identified = false),
        )
    }
}
