package app.mekasa.android.data

import app.mekasa.android.BuildConfig
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.engine.android.Android
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.defaultRequest
import io.ktor.client.request.bearerAuth
import io.ktor.client.request.delete
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.patch
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

    suspend fun createInventoryItem(
        householdId: String,
        body: InventoryItemCreateRequest,
        token: String,
    ): InventoryItemDto = post("/v1/households/$householdId/inventory", token, body)

    suspend fun consumeInventoryItem(
        householdId: String,
        itemId: String,
        amount: Int = 1,
        token: String,
    ): InventoryItemDto = post(
        "/v1/households/$householdId/inventory/$itemId/consume",
        token,
        InventoryConsumeRequest(amount),
    )

    suspend fun consumeInventoryByBarcode(
        householdId: String,
        barcode: String,
        amount: Int = 1,
        token: String,
    ): ConsumeByBarcodeResultDto = post(
        "/v1/households/$householdId/inventory/consume-by-barcode",
        token,
        InventoryConsumeByBarcodeRequest(barcode, amount),
    )

    suspend fun listUnknownTrashScans(
        householdId: String,
        token: String,
    ): List<UnknownBarcodeEventDto> = get(
        "/v1/households/$householdId/trash-scans/unknown",
        token,
    )

    suspend fun listShoppingList(householdId: String, token: String): ShoppingListResponse =
        get("/v1/households/$householdId/shopping-list", token)

    suspend fun createShoppingListItem(
        householdId: String,
        body: ShoppingListItemCreateRequest,
        token: String,
    ): ShoppingListItemDto = post("/v1/households/$householdId/shopping-list", token, body)

    suspend fun updateShoppingListItem(
        householdId: String,
        itemId: String,
        body: ShoppingListItemUpdateRequest,
        token: String,
    ): ShoppingListItemDto = patch("/v1/households/$householdId/shopping-list/$itemId", token, body)

    suspend fun approveShoppingListItem(
        householdId: String,
        itemId: String,
        token: String,
    ): ShoppingListItemDto = postEmpty("/v1/households/$householdId/shopping-list/$itemId/approve", token)

    suspend fun rejectShoppingListItem(
        householdId: String,
        itemId: String,
        token: String,
    ): ShoppingListItemDto = postEmpty("/v1/households/$householdId/shopping-list/$itemId/reject", token)

    suspend fun deleteShoppingListItem(
        householdId: String,
        itemId: String,
        token: String,
    ) {
        val response = client.delete("v1/households/$householdId/shopping-list/$itemId") {
            bearerAuth(token)
        }
        if (!response.status.isSuccess()) {
            throw MekasaApiException(
                response.status.value,
                response.bodyAsText().ifBlank { "HTTP ${response.status.value}" },
            )
        }
    }

    suspend fun syncShoppingListFromInventory(householdId: String, token: String): ShoppingListSyncResponse =
        postEmpty("/v1/households/$householdId/shopping-list/sync-from-inventory", token)

    suspend fun spending(householdId: String, period: String, token: String): SpendingReportDto =
        get("/v1/households/$householdId/spending?period=$period", token)

    suspend fun listMembers(householdId: String, token: String): HouseholdMembersResponse =
        get("/v1/households/$householdId/members", token)

    suspend fun listInvites(householdId: String, token: String): HouseholdInvitesResponse =
        get("/v1/households/$householdId/invites", token)

    suspend fun createInvite(
        householdId: String,
        body: HouseholdInviteCreateRequest,
        token: String,
    ): HouseholdInviteDto = post("/v1/households/$householdId/invites", token, body)

    suspend fun acceptInvite(body: HouseholdInviteAcceptRequest, token: String): HouseholdMemberDto =
        post("/v1/invites/accept", token, body)

    suspend fun updateMemberRole(
        householdId: String,
        memberUid: String,
        role: String,
        token: String,
    ): HouseholdMemberDto = patch(
        "/v1/households/$householdId/members/$memberUid",
        token,
        HouseholdMemberRoleUpdateRequest(role),
    )

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

    private suspend inline fun <reified T> postEmpty(path: String, token: String): T {
        val response = client.post(path.trimStart('/')) {
            bearerAuth(token)
            header("Accept", "application/json")
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

    private suspend inline fun <reified T, reified B> patch(path: String, token: String, body: B): T {
        val response = client.patch(path.trimStart('/')) {
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
