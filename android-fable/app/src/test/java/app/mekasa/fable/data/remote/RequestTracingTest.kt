package app.mekasa.fable.data.remote

import app.mekasa.fable.data.InventoryDraft
import app.mekasa.fable.session.InMemoryEmailMemory
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.support.FakeApi
import app.mekasa.fable.support.FakeAuthGateway
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.http.HttpHeaders
import io.ktor.http.headersOf
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withContext
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Satisfies: NFR-006 (Request Tracing and Diagnostic Logs)
 * Acceptance criteria: AC1, AC7
 * Spec version: 1.0
 */
@OptIn(ExperimentalCoroutinesApi::class)
class RequestTracingTest {

    private val requests = mutableListOf<HttpRequestData>()

    private fun api(body: String): KtorMekasaApi {
        val engine = MockEngine { request ->
            requests += request
            respond(body, headers = headersOf(HttpHeaders.ContentType, "application/json"))
        }
        return KtorMekasaApi("https://api.test/", engine = engine)
    }

    @Before
    fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `new ids are 32 hex characters the backend accepts`() {
        val first = RequestTracing.newId()
        assertTrue(first, Regex("^[0-9a-f]{32}$").matches(first))
        assertNotEquals(first, RequestTracing.newId())
    }

    @Test
    fun `every call sends a new request id and no correlation outside a flow`() = runTest {
        val api = api("""{"status":"ok"}""")
        api.health()
        api.health()

        val ids = requests.map { it.headers[RequestTracing.REQUEST_ID_HEADER] }
        ids.forEach { assertNotNull(it) }
        assertEquals(2, ids.toSet().size)
        requests.forEach { assertNull(it.headers[RequestTracing.CORRELATION_ID_HEADER]) }
    }

    @Test
    fun `calls inside a receipt flow send its correlation id, multipart included`() = runTest {
        val api = api("""{"photo_id":"p1","image_url":"/v1/product-photos/p1"}""")
        withContext(CorrelationId("receipt-flow-0001")) {
            api.uploadProductPhoto("t", "hh-1", byteArrayOf(1, 2, 3))
        }

        val request = requests.single()
        assertEquals("receipt-flow-0001", request.headers[RequestTracing.CORRELATION_ID_HEADER])
        assertNotNull(request.headers[RequestTracing.REQUEST_ID_HEADER])
    }

    @Test
    fun `a receipt scan and its saves share one correlation id`() {
        val fake = FakeApi()
        val vm = SessionViewModel(api = fake, auth = FakeAuthGateway(), emailMemory = InMemoryEmailMemory())
        vm.signInWithEmail("ana@example.com", "secret", createAccount = false)

        vm.scanReceipt(rawText = "BANANAS 0.99") {}
        val flowId = vm.receiptFlowId
        assertNotNull(flowId)
        vm.addInventory(listOf(InventoryDraft(name = "Bananas", source = "receipt")))
        vm.addInventory(InventoryDraft(name = "Soap", source = "manual"))

        val byCall = fake.correlations.toMap()
        assertEquals(flowId, byCall["scanReceipt"])
        assertEquals(flowId, byCall["createInventory:Bananas:receipt"])
        assertNull(byCall["createInventory:Soap:manual"])
        assertNull(byCall.entries.first { it.key.startsWith("me:") }.value)

        vm.scanReceipt(rawText = "MILK 3.49") {}
        assertNotEquals(flowId, vm.receiptFlowId)
    }
}
