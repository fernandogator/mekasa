package app.mekasa.fable.data.remote

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.content.TextContent
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class KtorMekasaApiTest {

    private val requests = mutableListOf<HttpRequestData>()

    private fun api(status: HttpStatusCode = HttpStatusCode.OK, body: String): KtorMekasaApi {
        val engine = MockEngine { request ->
            requests += request
            respond(body, status, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        return KtorMekasaApi("https://api.test/", engine = engine)
    }

    @Test
    fun `sends bearer token and decodes snake_case household`() = runTest {
        val api = api(
            body = """{"id":"hh-1","owner_uid":"u1","photo_url":"https://x/y.jpg","store_ids":["a","b"],"extra":"ignored"}""",
        )
        val household = api.currentHousehold("tok-123")

        assertEquals("hh-1", household.id)
        assertEquals("u1", household.ownerUid)
        assertEquals(listOf("a", "b"), household.storeIds)
        assertEquals("https://x/y.jpg", household.photoUrl)
        assertTrue(household.hasStores)
        assertFalse(household.hasAddress)

        val request = requests.single()
        assertEquals(HttpMethod.Get, request.method)
        assertEquals("https://api.test/v1/households/current", request.url.toString())
        assertEquals("Bearer tok-123", request.headers[HttpHeaders.Authorization])
    }

    @Test
    fun `json body uses server field names`() = runTest {
        val api = api(body = """{"id":"i1","household_id":"hh-1","name":"Milk","quantity":3}""")
        api.consumeByBarcode("t", "hh-1", "049000028911", 2)

        val request = requests.single()
        assertEquals(HttpMethod.Post, request.method)
        assertTrue(request.url.encodedPath.endsWith("/inventory/consume-by-barcode"))
        val sent = (request.body as TextContent).text
        assertTrue(sent, sent.contains("\"barcode\":\"049000028911\""))
        assertTrue(sent, sent.contains("\"amount\":2"))
    }

    @Test
    fun `patch omits nulls so the server keeps untouched fields`() = runTest {
        val api = api(body = """{"id":"i1","household_id":"hh-1","name":"Milk","quantity":3}""")
        api.patchInventoryItem("t", "hh-1", "i1", app.mekasa.fable.data.model.InventoryItemPatch(quantity = 3))

        val sent = (requests.single().body as TextContent).text
        assertEquals("""{"quantity":3}""", sent)
        assertEquals(HttpMethod.Patch, requests.single().method)
    }

    @Test
    fun `spending and search pass query parameters`() = runTest {
        val api = api(body = """{"period":"month","total":1.5}""")
        val report = api.spending("t", "hh-1", "month")
        assertEquals("month", report.period)
        assertEquals("month", requests.single().url.parameters["period"])
    }

    @Test
    fun `fastapi detail string becomes ApiException`() = runTest {
        val api = api(HttpStatusCode.Forbidden, """{"detail":"Forbidden"}""")
        try {
            api.listInventory("t", "hh-1")
            fail("expected ApiException")
        } catch (e: ApiException) {
            assertEquals(403, e.status)
            assertTrue(e.isForbidden)
            assertEquals("Forbidden", e.detail)
            assertTrue(e.userMessage.contains("permission"))
        }
    }

    @Test
    fun `validation detail arrays are preserved as text`() = runTest {
        val api = api(HttpStatusCode.UnprocessableEntity, """{"detail":[{"loc":["body","name"],"msg":"required"}]}""")
        try {
            api.createHousehold("t", null)
            fail("expected ApiException")
        } catch (e: ApiException) {
            assertEquals(422, e.status)
            assertTrue(e.detail.contains("required"))
        }
    }

    @Test
    fun `unauthorized is flagged for session expiry`() = runTest {
        val api = api(HttpStatusCode.Unauthorized, """{"detail":"invalid_token"}""")
        try {
            api.me("expired")
            fail("expected ApiException")
        } catch (e: ApiException) {
            assertTrue(e.isUnauthorized)
        }
    }

    @Test
    fun `404 on current household surfaces as not found`() = runTest {
        val api = api(HttpStatusCode.NotFound, """{"detail":"Not found"}""")
        try {
            api.currentHousehold("t")
            fail("expected ApiException")
        } catch (e: ApiException) {
            assertTrue(e.isNotFound)
        }
    }

    @Test
    fun `photo upload is multipart with file part`() = runTest {
        val api = api(body = """{"id":"hh-1","owner_uid":"u1","photo_url":"https://cdn/p.jpg"}""")
        val result = api.uploadHouseholdPhoto("t", "hh-1", byteArrayOf(1, 2, 3), "image/jpeg", "home.jpg")

        assertEquals("https://cdn/p.jpg", result.photoUrl)
        val request = requests.single()
        assertEquals(HttpMethod.Post, request.method)
        assertTrue(request.url.encodedPath.endsWith("/households/hh-1/photo"))
        val contentType = request.body.contentType?.toString()
        assertNotNull(contentType)
        assertTrue(contentType!!, contentType.startsWith("multipart/form-data"))
    }

    @Test
    fun `delete tolerates empty body`() = runTest {
        val api = api(HttpStatusCode.NoContent, "")
        api.deleteShoppingItem("t", "hh-1", "s1")
        assertEquals(HttpMethod.Delete, requests.single().method)
    }
}
