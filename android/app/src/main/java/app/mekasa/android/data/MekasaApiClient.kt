package app.mekasa.android.data

import app.mekasa.android.BuildConfig
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.engine.android.Android
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.defaultRequest
import io.ktor.client.request.bearerAuth
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.put
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpStatusCode
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

class MekasaApiException(
    val status: Int,
    override val message: String,
) : Exception(message) {
    val isUnauthorized: Boolean get() = status == 401
}

class MekasaApiClient(
    baseUrl: String = BuildConfig.API_BASE_URL,
) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        encodeDefaults = true
    }

    private val client = HttpClient(Android) {
        expectSuccess = false
        install(ContentNegotiation) { json(json) }
        defaultRequest {
            url(baseUrl.trimEnd('/') + "/")
        }
    }

    suspend fun health(): HealthResponse = get("/health")

    suspend fun me(token: String): UserProfile = get("/v1/me", token)

    suspend fun createHousehold(name: String?, token: String): Household {
        @Serializable
        data class Body(val name: String?, val photo_url: String? = null)
        return post("/v1/households", token, Body(name))
    }

    suspend fun currentHousehold(token: String): Household = get("/v1/households/current", token)

    suspend fun updateAddress(
        householdId: String,
        address: String,
        latitude: Double?,
        longitude: Double?,
        token: String,
    ): Household {
        @Serializable
        data class Body(val address: String, val latitude: Double?, val longitude: Double?)
        return put("/v1/households/$householdId/address", token, Body(address, latitude, longitude))
    }

    suspend fun updateHouseholdName(householdId: String, name: String?, token: String): Household {
        @Serializable
        data class Body(val name: String?)
        return put("/v1/households/$householdId/name", token, Body(name))
    }

    suspend fun nearbyStores(householdId: String, token: String): StoreSearchResponse =
        get("/v1/households/$householdId/stores/nearby", token)

    suspend fun selectStores(householdId: String, storeIds: List<String>, token: String): Household {
        @Serializable
        data class Body(val store_ids: List<String>)
        return put("/v1/households/$householdId/stores", token, Body(storeIds))
    }

    suspend fun listInventory(householdId: String, token: String): InventoryListResponse =
        get("/v1/households/$householdId/inventory", token)

    suspend fun listShoppingList(householdId: String, token: String): ShoppingListResponse =
        get("/v1/households/$householdId/shopping-list", token)

    suspend fun spending(householdId: String, period: String, token: String): SpendingReportDto =
        get("/v1/households/$householdId/spending?period=$period", token)

    suspend fun searchProducts(query: String, limit: Int = 8, token: String): ProductSearchResponse =
        get("/v1/products/search?q=${query.encodeURLParam()}&limit=$limit", token)

    suspend fun lookupBarcode(code: String, token: String): BarcodeLookupResponse =
        get("/v1/barcode/$code", token)

    private suspend inline fun <reified T> get(path: String, token: String? = null): T {
        val response = client.get(path.trimStart('/')) {
            if (token != null) bearerAuth(token)
            header("Accept", "application/json")
        }
        return decode(response.status, response.bodyAsText())
    }

    private suspend inline fun <reified T, reified B> post(path: String, token: String, body: B): T {
        val response = client.post(path.trimStart('/')) {
            bearerAuth(token)
            contentType(ContentType.Application.Json)
            setBody(body)
        }
        return decode(response.status, response.bodyAsText())
    }

    private suspend inline fun <reified T, reified B> put(path: String, token: String, body: B): T {
        val response = client.put(path.trimStart('/')) {
            bearerAuth(token)
            contentType(ContentType.Application.Json)
            setBody(body)
        }
        return decode(response.status, response.bodyAsText())
    }

    private inline fun <reified T> decode(status: HttpStatusCode, text: String): T {
        if (!status.isSuccess()) {
            throw MekasaApiException(status.value, text.ifBlank { "HTTP ${status.value}" })
        }
        return json.decodeFromString(text)
    }

    fun close() = client.close()
}

private fun String.encodeURLParam(): String =
    java.net.URLEncoder.encode(this, Charsets.UTF_8.name())
