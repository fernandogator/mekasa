package app.mekasa.fable

import app.mekasa.fable.data.remote.KtorMekasaApi
import app.mekasa.fable.data.remote.PrivateItemPhoto
import app.mekasa.fable.ui.components.PrivateImageModel
import app.mekasa.fable.ui.components.imageModelFor
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Household-private item photos.
 *
 * Satisfies: REQ-INV-019 (Replace an Item Picture With a Private Photo)
 * Acceptance criteria: AC1, AC3, AC8
 * Spec version: 1.0
 */
class ItemPhotoTest {

    private val api = "https://mekasa-api.example.run.app"
    private val photoId = "0b5c7e4e-7f3e-4d0c-9c1e-6d2b8a9f1c22"
    private val mine = "$api/v1/households/h-1/item-photos/$photoId"

    @Test
    fun `recognises only our household-scoped photo urls`() {
        assertTrue(PrivateItemPhoto.isPrivate(mine, api))
        assertTrue(PrivateItemPhoto.isPrivate(mine, "$api/"))
        assertTrue("host compare is case-insensitive", PrivateItemPhoto.isPrivate(mine.replace("mekasa-api", "MEKASA-API"), api))
        assertTrue(PrivateItemPhoto.isPrivate("$mine?v=2", api))

        assertFalse(PrivateItemPhoto.isPrivate(null, api))
        assertFalse(PrivateItemPhoto.isPrivate("", api))
        assertFalse(PrivateItemPhoto.isPrivate(mine, null))
        assertFalse(PrivateItemPhoto.isPrivate("https://images.openfoodfacts.org/x.jpg", api))
        assertFalse(PrivateItemPhoto.isPrivate("https://placehold.co/400x400/png?text=Dairy", api))
        assertFalse("other host", PrivateItemPhoto.isPrivate("https://evil.example.com/v1/households/h-1/item-photos/$photoId", api))
        assertFalse("legacy public path", PrivateItemPhoto.isPrivate("$api/v1/photos/$photoId", api))
        assertFalse(PrivateItemPhoto.isPrivate("$api/v1/households/h-1/item-photos/not-a-uuid", api))
        assertFalse(PrivateItemPhoto.isPrivate("data:image/jpeg;base64,/9j/4AAQ", api))
    }

    @Test
    fun `headers carry the bearer token and are empty when signed out`() {
        assertEquals(mapOf("Authorization" to "Bearer tok-1"), PrivateItemPhoto.headers("tok-1"))
        assertTrue(PrivateItemPhoto.headers(null).isEmpty())
        assertTrue(PrivateItemPhoto.headers("").isEmpty())
    }

    @Test
    fun `image model attaches the token only to private urls`() {
        val model = imageModelFor(mine, api, "tok-1")
        assertEquals(PrivateImageModel(mine, mapOf("Authorization" to "Bearer tok-1")), model)

        assertNull("signed out: do not try to load a private photo", imageModelFor(mine, api, null))
        assertEquals("https://images.openfoodfacts.org/x.jpg", imageModelFor("https://images.openfoodfacts.org/x.jpg", api, "tok-1"))
        assertNull(imageModelFor("", api, "tok-1"))
    }

    @Test
    fun `upload posts multipart to item-photos and decodes the private url`() = runTest {
        val requests = mutableListOf<HttpRequestData>()
        val engine = MockEngine { request ->
            requests += request
            respond(
                """{"photo_id":"$photoId","url":"$mine"}""",
                HttpStatusCode.Created,
                headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val client = KtorMekasaApi("$api/", engine = engine)

        val uploaded = client.uploadItemPhoto("tok-1", "h-1", byteArrayOf(1, 2, 3), "image/jpeg", "item.jpg")

        assertEquals(photoId, uploaded.photoId)
        assertEquals(mine, uploaded.url)
        val request = requests.single()
        assertEquals(HttpMethod.Post, request.method)
        assertEquals("$api/v1/households/h-1/item-photos", request.url.toString())
        assertEquals("Bearer tok-1", request.headers[HttpHeaders.Authorization])
        val contentType = request.body.contentType?.toString().orEmpty()
        assertTrue(contentType, contentType.startsWith("multipart/form-data"))
    }
}
