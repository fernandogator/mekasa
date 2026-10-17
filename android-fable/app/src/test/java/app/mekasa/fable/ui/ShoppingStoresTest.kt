package app.mekasa.fable.ui

import app.mekasa.fable.data.model.Household
import app.mekasa.fable.data.model.SavedStore
import app.mekasa.fable.data.model.ShoppingItem
import app.mekasa.fable.data.model.ShoppingItemCreateRequest
import app.mekasa.fable.data.model.ShoppingStoreMove
import app.mekasa.fable.data.model.Store
import app.mekasa.fable.data.model.StoreSearchResponse
import app.mekasa.fable.data.remote.ApiException
import app.mekasa.fable.data.remote.ApiJson
import app.mekasa.fable.data.remote.KtorMekasaApi
import app.mekasa.fable.session.SessionState
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.session.StorePickerResult
import app.mekasa.fable.support.FakeApi
import app.mekasa.fable.support.FakeAuthGateway
import app.mekasa.fable.ui.shopping.ShoppingStores
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.content.TextContent
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.serialization.encodeToString
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Verifies: REQ-024 AC5, AC7; REQ-003 AC6, AC11
 *
 * Per-store shopping lists (which list a row is on, filtering, counts, store names),
 * store picker preselection, the wire format for `stores` / `store_id`, and the session
 * paths that save stores and move rows.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ShoppingStoresTest {

    private val costco = SavedStore("costco", "Costco Wholesale", "1 Warehouse Way", 4.2)
    private val heb = SavedStore("heb", "H-E-B", "2 Main St", 1.4)
    private val saved = listOf(costco, heb)

    private fun row(id: String, storeId: String? = null, checked: Boolean = false) =
        ShoppingItem(id = id, householdId = "hh-1", name = id, storeId = storeId, isChecked = checked)

    private val rows = listOf(
        row("milk", "costco"),
        row("eggs", "costco", checked = true),
        row("tortillas", "heb"),
        row("batteries"),
        row("old", "kroger"),
    )

    private val dispatcher = UnconfinedTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    // ------------------------------------------------------------ list rules

    @Test
    fun `a row with a saved store is on that store's list`() {
        assertEquals("costco", ShoppingStores.listKey("costco", saved))
        assertEquals("heb", ShoppingStores.listKey("heb", saved))
    }

    @Test
    fun `a row with no store or a removed store is on Any store`() {
        assertEquals(ShoppingStores.ANY, ShoppingStores.listKey(null, saved))
        assertEquals(ShoppingStores.ANY, ShoppingStores.listKey("kroger", saved))
        assertEquals(ShoppingStores.ANY, ShoppingStores.listKey("costco", emptyList()))
    }

    @Test
    fun `picking a store shows only its rows and All shows every row`() {
        assertEquals(listOf("milk", "eggs"), ShoppingStores.filter(rows, "costco", saved).map { it.id })
        assertEquals(listOf("tortillas"), ShoppingStores.filter(rows, "heb", saved).map { it.id })
        assertEquals(listOf("batteries", "old"), ShoppingStores.filter(rows, ShoppingStores.ANY, saved).map { it.id })
        assertEquals(rows, ShoppingStores.filter(rows, ShoppingStores.ALL, saved))
    }

    @Test
    fun `tabs list All, each saved store, then Any with rows still to buy`() {
        val tabs = ShoppingStores.tabs(rows, saved)
        assertEquals(listOf("all", "costco", "heb", "any"), tabs.map { it.key })
        assertEquals(listOf("All stores", "Costco Wholesale", "H-E-B", "Any store"), tabs.map { it.label })
        assertEquals(listOf(4, 1, 1, 2), tabs.map { it.toBuy })
    }

    @Test
    fun `store name follows the list the row is on`() {
        assertEquals("Costco Wholesale", ShoppingStores.storeName("costco", saved))
        assertEquals("Any store", ShoppingStores.storeName(null, saved))
        assertEquals("Any store", ShoppingStores.storeName("kroger", saved))
    }

    @Test
    fun `adds go to the selected store and to Any store from All`() {
        assertEquals("heb", ShoppingStores.storeIdForAdd("heb", saved))
        assertNull(ShoppingStores.storeIdForAdd(ShoppingStores.ALL, saved))
        assertNull(ShoppingStores.storeIdForAdd(ShoppingStores.ANY, saved))
        // A store removed while selected falls back to All stores.
        assertEquals(ShoppingStores.ALL, ShoppingStores.normalizedSelection("kroger", saved))
        assertNull(ShoppingStores.storeIdForAdd("kroger", saved))
    }

    // ------------------------------------------------------------ picker

    @Test
    fun `picker preselects only stores saved with details, not bare ids`() {
        val household = Household(id = "hh-1", ownerUid = "u1", storeIds = listOf("costco", "placeholder-1"), stores = listOf(costco))
        assertEquals(setOf("costco"), ShoppingStores.pickerSelection(household))

        val bareOnly = Household(id = "hh-1", ownerUid = "u1", storeIds = listOf("placeholder-1"))
        assertTrue(ShoppingStores.pickerSelection(bareOnly).isEmpty())
        assertTrue(ShoppingStores.pickerSelection(null).isEmpty())
    }

    @Test
    fun `picker keeps saved stores the search did not return and searches name or address`() {
        val nearby = listOf(Store("heb", "H-E-B", "2 Main St", distanceMiles = 1.4), Store("aldi", "Aldi", "9 Elm Ave", distanceMiles = 2.0))
        val candidates = ShoppingStores.pickerCandidates(nearby, saved)
        assertEquals(listOf("heb", "aldi", "costco"), candidates.map { it.id })
        assertEquals(listOf("aldi"), ShoppingStores.search(candidates, "elm").map { it.id })
        assertEquals(listOf("heb"), ShoppingStores.search(candidates, "h-e-b").map { it.id })
        assertEquals(candidates, ShoppingStores.search(candidates, "  "))
    }

    @Test
    fun `saving sends details in id order and keeps ids without details`() {
        val candidates = listOf(Store("heb", "H-E-B", "2 Main St", distanceMiles = 1.4), Store("aldi", "Aldi"))
        val selection = ShoppingStores.selectionToSave(setOf("aldi", "heb", "bare"), candidates)
        assertEquals(listOf("heb", "aldi", "bare"), selection.storeIds)
        assertEquals(listOf("heb", "aldi"), selection.stores.map { it.id })
        assertEquals(1.4, selection.stores.first().distanceMiles!!, 0.0)
        assertNull(selection.stores.last().distanceMiles)
    }

    // ------------------------------------------------------------ wire format

    @Test
    fun `household decodes saved stores and defaults to none`() {
        val withStores = ApiJson.decodeFromString<Household>(
            """{"id":"hh-1","owner_uid":"u1","store_ids":["costco"],
               "stores":[{"id":"costco","name":"Costco Wholesale","address":"1 Warehouse Way","distance_miles":4.2}]}""",
        )
        assertEquals(listOf(costco), withStores.stores)

        val older = ApiJson.decodeFromString<Household>("""{"id":"hh-1","owner_uid":"u1","store_ids":["costco"]}""")
        assertEquals(listOf("costco"), older.storeIds)
        assertTrue(older.stores.isEmpty())

        val noDistance = ApiJson.decodeFromString<SavedStore>("""{"id":"a","name":"Aldi"}""")
        assertEquals("", noDistance.address)
        assertNull(noDistance.distanceMiles)
    }

    @Test
    fun `store search decodes needs_location`() {
        assertTrue(ApiJson.decodeFromString<StoreSearchResponse>("""{"stores":[],"needs_location":true}""").needsLocation)
        assertFalse(ApiJson.decodeFromString<StoreSearchResponse>("""{"stores":[]}""").needsLocation)
    }

    @Test
    fun `shopping rows decode store_id and create sends it only when set`() {
        val onStore = ApiJson.decodeFromString<ShoppingItem>("""{"id":"s1","household_id":"hh-1","name":"Milk","store_id":"costco"}""")
        assertEquals("costco", onStore.storeId)
        val anyStore = ApiJson.decodeFromString<ShoppingItem>("""{"id":"s1","household_id":"hh-1","name":"Milk"}""")
        assertNull(anyStore.storeId)

        assertTrue(ApiJson.encodeToString(ShoppingItemCreateRequest(name = "Milk", storeId = "heb")).contains("\"store_id\":\"heb\""))
        assertFalse(ApiJson.encodeToString(ShoppingItemCreateRequest(name = "Milk")).contains("store_id"))
    }

    @Test
    fun `move body sends store_id as JSON null to clear it`() {
        assertEquals("""{"store_id":null}""", ApiJson.encodeToString(ShoppingStoreMove.body(null)))
        assertEquals("""{"store_id":"heb"}""", ApiJson.encodeToString(ShoppingStoreMove.body("heb")))
    }

    @Test
    fun `move request on the wire includes store_id null`() = runTest {
        val requests = mutableListOf<HttpRequestData>()
        val engine = MockEngine { request ->
            requests += request
            respond("""{"id":"s1","household_id":"hh-1","name":"Milk"}""", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val api = KtorMekasaApi("https://api.test/", engine = engine)

        val moved = api.moveShoppingItem("t", "hh-1", "s1", null)

        assertNull(moved.storeId)
        val request = requests.single()
        assertEquals(HttpMethod.Patch, request.method)
        assertEquals("/v1/households/hh-1/shopping-list/s1", request.url.encodedPath)
        assertEquals("""{"store_id":null}""", (request.body as TextContent).text)
    }

    @Test
    fun `select stores request sends ids with details`() = runTest {
        val requests = mutableListOf<HttpRequestData>()
        val engine = MockEngine { request ->
            requests += request
            respond("""{"id":"hh-1","owner_uid":"u1","store_ids":["heb"]}""", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        KtorMekasaApi("https://api.test/", engine = engine).selectStores("t", "hh-1", listOf("heb"), listOf(heb))

        val sent = (requests.single().body as TextContent).text
        assertEquals(HttpMethod.Put, requests.single().method)
        assertEquals(
            """{"store_ids":["heb"],"stores":[{"id":"heb","name":"H-E-B","address":"2 Main St","distance_miles":1.4}]}""",
            sent,
        )
    }

    // ------------------------------------------------------------ session

    private fun signedIn(api: FakeApi): SessionViewModel =
        SessionViewModel(api = api, auth = FakeAuthGateway()).also {
            it.signInWithEmail("ana@example.com", "secret", createAccount = false)
        }

    private val SessionViewModel.s: SessionState get() = state.value

    @Test
    fun `adding from a store list saves the row on that store`() {
        val api = FakeApi().apply { household = household!!.copy(storeIds = listOf("heb"), stores = listOf(heb)) }
        val vm = signedIn(api)

        vm.addShoppingItem("Tortillas", 2, storeId = "heb")

        assertEquals("heb", vm.s.data.shopping.first { it.name == "Tortillas" }.storeId)
        assertEquals("heb", api.shopping.last().storeId)
    }

    @Test
    fun `move updates the row and reverts with an error when the API fails`() {
        val api = FakeApi().apply { household = household!!.copy(storeIds = listOf("heb"), stores = listOf(heb)) }
        val vm = signedIn(api)

        vm.moveShoppingItem("s1", "heb")
        assertEquals("heb", vm.s.data.shopping.single().storeId)
        assertTrue(api.calls.contains("moveShopping:s1:heb"))

        api.failWith = ApiException(422, "unknown_store")
        vm.moveShoppingItem("s1", null)
        assertEquals("heb", vm.s.data.shopping.single().storeId)
        assertTrue(vm.s.error != null)
    }

    @Test
    fun `settings picker asks for the address when the household has no coordinates`() {
        val api = FakeApi()
        val vm = signedIn(api)
        var result: StorePickerResult? = null

        vm.loadStorePicker { result = it }
        assertEquals(StorePickerResult.NeedsAddress, result)

        // The fake API saves the address without coordinates, as a failed geocode would.
        vm.findStoresNear("nowhere") { result = it }
        assertEquals(StorePickerResult.Failed(SessionViewModel.ADDRESS_NOT_FOUND), result)
        assertEquals("nowhere", vm.s.household?.address)
    }

    @Test
    fun `confirm saves the checked stores with details and updates the household`() {
        val api = FakeApi()
        val vm = signedIn(api)
        var error: String? = "pending"

        vm.saveStores(setOf("heb"), listOf(Store("heb", "H-E-B", "2 Main St", distanceMiles = 1.4), Store("aldi", "Aldi"))) { error = it }

        assertNull(error)
        assertEquals(listOf(heb), api.savedStoreDetails)
        assertEquals(listOf(heb), vm.s.household?.stores)
        assertEquals(listOf("heb"), vm.s.household?.storeIds)
    }

    @Test
    fun `onboarding saves the picked stores with their details`() {
        val api = object : FakeApi() {
            override suspend fun nearbyStores(token: String, householdId: String) = StoreSearchResponse(
                stores = listOf(Store("heb", "H-E-B", "2 Main St", distanceMiles = 1.4), Store("aldi", "Aldi", distanceMiles = 2.0)),
            )
        }
        api.household = null
        val vm = signedIn(api)
        vm.createHousehold("Casa Ana")
        vm.saveAddress("2 Main St")
        vm.toggleStore("aldi")

        vm.finishStoreSelection()

        assertEquals(listOf("heb"), vm.s.household?.storeIds)
        assertEquals(listOf(heb), api.savedStoreDetails)
    }
}
