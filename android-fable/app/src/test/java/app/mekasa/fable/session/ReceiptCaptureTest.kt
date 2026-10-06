package app.mekasa.fable.session

import app.mekasa.fable.data.CatalogCapture
import app.mekasa.fable.data.CatalogCode
import app.mekasa.fable.data.LineCapture
import app.mekasa.fable.data.model.InventoryItem
import app.mekasa.fable.data.model.ReceiptLine
import app.mekasa.fable.data.remote.ApiException
import app.mekasa.fable.support.FakeApi
import app.mekasa.fable.support.FakeAuthGateway
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Photo-only receipt capture and adding a code later.
 * Satisfies: REQ-RCP-020 AC6, AC15
 * Spec version: 1.0
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ReceiptCaptureTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private val api = FakeApi()
    private val photo = ByteArray(16) { it.toByte() }
    private val line = ReceiptLine(name = "Mango salsa", category = "Pantry", quantity = 1, identified = false, receiptText = "PUB MANGO SALSA")

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun signedIn(): SessionViewModel =
        SessionViewModel(api = api, auth = FakeAuthGateway(), emailMemory = InMemoryEmailMemory()).also {
            it.signInWithEmail("ana@example.com", "secret", createAccount = false)
        }

    // ------------------------------------------------------------ pure rules

    @Test
    fun `codes parse by length`() {
        assertEquals(CatalogCode.Plu("4011"), CatalogCode.parse(" 4011 "))
        assertEquals(CatalogCode.Upc("012345678905"), CatalogCode.parse("012345678905"))
        assertNull(CatalogCode.parse("123"))
        assertNull(CatalogCode.parse("12a45"))
        assertNull(CatalogCode.parse(""))
    }

    @Test
    fun `photo with receipt text and no code is a photo-only capture`() {
        val capture = LineCapture(photoJpeg = photo, receiptText = "PUB MANGO SALSA", storeChainId = "publix")
        assertTrue(capture.isPhotoOnly)
        assertTrue(capture.sharesPhoto)

        val request = CatalogCapture.request(capture, photoId = "p1")!!
        assertNull(request.upc)
        assertNull(request.pluCode)
        assertEquals("p1", request.photoId)
        assertEquals("PUB MANGO SALSA", request.receiptText)
        assertEquals("publix", request.storeChainId)
    }

    @Test
    fun `no code and no receipt text sends nothing`() {
        val capture = LineCapture(photoJpeg = photo)
        assertFalse(capture.sharesPhoto)
        assertNull(CatalogCapture.request(capture, photoId = "p1"))
        assertNull(CatalogCapture.request(LineCapture(receiptText = "PUB MANGO SALSA"), photoId = null))
    }

    @Test
    fun `a typed code wins over photo-only`() {
        val capture = LineCapture(code = "4959", photoJpeg = photo, receiptText = "PUB MANGO")
        assertFalse(capture.isPhotoOnly)
        val request = CatalogCapture.request(capture, photoId = "p1")!!
        assertEquals("4959", request.pluCode)
        assertEquals("PUB MANGO", request.receiptText)
    }

    @Test
    fun `copy names the store and maps api errors`() {
        assertEquals("No barcode scanned — the photo and name are shared for Publix receipts", CatalogCapture.noCodeMessage("Publix"))
        assertEquals("No barcode scanned — the photo and name are shared for these receipts", CatalogCapture.noCodeMessage(null))
        assertTrue(CatalogCapture.errorMessage("{\"detail\":\"invalid_plu\"}").startsWith("That PLU"))
        assertTrue(CatalogCapture.errorMessage("invalid_upc").startsWith("That barcode"))
        assertEquals("Couldn't save the code. Try again.", CatalogCapture.errorMessage(null))
    }

    @Test
    fun `receipt draft keeps a capture only when it has a code or photo`() {
        assertNull(CatalogCapture.receiptDraft(line, null).capture)
        assertNull(CatalogCapture.receiptDraft(line, LineCapture(receiptText = "PUB MANGO SALSA")).capture)
        val capture = LineCapture(photoJpeg = photo, receiptText = "PUB MANGO SALSA")
        val draft = CatalogCapture.receiptDraft(line, capture)
        assertEquals(capture, draft.capture)
        assertEquals("receipt", draft.source)
        assertEquals("Mango salsa", draft.name)
    }

    @Test
    fun `only items without a code or with an llm product can add one`() {
        val base = InventoryItem(id = "x", householdId = "hh-1", name = "Salsa")
        assertTrue(base.canAddCode)
        assertTrue(base.copy(productId = "llm:abc").canAddCode)
        assertFalse(base.copy(productId = "plu:4011").canAddCode)
        assertFalse(base.copy(barcode = "012345678905").canAddCode)
    }

    // ------------------------------------------------------------ session

    @Test
    fun `saving a photo-only line uploads a shared photo and captures with receipt text`() {
        val vm = signedIn()
        val capture = LineCapture(photoJpeg = photo, receiptText = "PUB MANGO SALSA", storeChainId = "publix")
        var done = false

        vm.addInventory(listOf(CatalogCapture.receiptDraft(line, capture))) { done = true }

        assertTrue(done)
        assertTrue(api.calls.contains("uploadProductPhoto:${photo.size}"))
        val request = api.captures.single()
        assertNull(request.upc)
        assertNull(request.pluCode)
        assertEquals("PUB MANGO SALSA", request.receiptText)
        assertEquals("publix", request.storeChainId)
        val saved = vm.state.value.data.inventory.first { it.name == "Mango salsa" }
        assertTrue(saved.productId!!.startsWith("llm:"))
        assertTrue(saved.imageUrl!!.startsWith("/v1/product-photos/"))
        assertNull(vm.state.value.error)
    }

    @Test
    fun `a capture failure keeps the item and says so`() {
        val failing = object : FakeApi() {
            override suspend fun captureInventoryItem(
                token: String,
                householdId: String,
                itemId: String,
                body: app.mekasa.fable.data.model.ProductCaptureRequest,
            ): app.mekasa.fable.data.model.ProductCaptureResponse = throw ApiException(500, "boom")
        }
        val vm = SessionViewModel(api = failing, auth = FakeAuthGateway(), emailMemory = InMemoryEmailMemory()).also {
            it.signInWithEmail("ana@example.com", "secret", createAccount = false)
        }
        val capture = LineCapture(photoJpeg = photo, receiptText = "PUB MANGO SALSA")

        vm.addInventory(listOf(CatalogCapture.receiptDraft(line, capture)))

        assertTrue(vm.state.value.data.inventory.any { it.name == "Mango salsa" })
        assertEquals("Saved Mango salsa, but couldn't add it to the shared catalog.", vm.state.value.error)
    }

    @Test
    fun `adding a UPC later captures it and refreshes health`() {
        api.inventory += InventoryItem(id = "i2", householdId = "hh-1", name = "Mango salsa", productId = "llm:${"b".repeat(40)}")
        val vm = signedIn()
        var result: String? = "pending"

        vm.addCode("i2", "012345678905") { result = it }

        assertNull(result)
        assertEquals("012345678905", api.captures.single().upc)
        assertTrue(api.calls.contains("refreshHealth:i2"))
        assertEquals("012345678905", vm.state.value.data.inventory.first { it.id == "i2" }.barcode)
    }

    @Test
    fun `adding a PLU later captures it without a health refresh`() {
        api.inventory += InventoryItem(id = "i2", householdId = "hh-1", name = "Mango", productId = "llm:${"b".repeat(40)}")
        val vm = signedIn()
        var result: String? = "pending"

        vm.addCode("i2", "4959") { result = it }

        assertNull(result)
        assertEquals("4959", api.captures.single().pluCode)
        assertFalse(api.calls.any { it.startsWith("refreshHealth") })
        assertEquals("plu:4959", vm.state.value.data.inventory.first { it.id == "i2" }.productId)
    }

    @Test
    fun `an invalid code is refused before calling the api`() {
        val vm = signedIn()
        var result: String? = null

        vm.addCode("i1", "123") { result = it }

        assertTrue(result!!.startsWith("That barcode"))
        assertTrue(api.captures.isEmpty())
    }
}
