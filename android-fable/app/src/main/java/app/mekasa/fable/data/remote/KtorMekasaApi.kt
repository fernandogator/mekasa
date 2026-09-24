package app.mekasa.fable.data.remote

import app.mekasa.fable.data.model.AddressUpdateRequest
import app.mekasa.fable.data.model.BarcodeLookup
import app.mekasa.fable.data.model.ConsumeByBarcodeRequest
import app.mekasa.fable.data.model.ConsumeByBarcodeResult
import app.mekasa.fable.data.model.ConsumeRequest
import app.mekasa.fable.data.model.HealthResponse
import app.mekasa.fable.data.model.Household
import app.mekasa.fable.data.model.HouseholdCreateRequest
import app.mekasa.fable.data.model.HouseholdInvite
import app.mekasa.fable.data.model.HouseholdInvitesResponse
import app.mekasa.fable.data.model.HouseholdMember
import app.mekasa.fable.data.model.HouseholdMembersResponse
import app.mekasa.fable.data.model.HouseholdNameUpdateRequest
import app.mekasa.fable.data.model.InventoryItem
import app.mekasa.fable.data.model.InventoryItemCreateRequest
import app.mekasa.fable.data.model.InventoryItemPatch
import app.mekasa.fable.data.model.InventoryListResponse
import app.mekasa.fable.data.model.InviteAcceptRequest
import app.mekasa.fable.data.model.InviteCreateRequest
import app.mekasa.fable.data.model.MemberRoleUpdateRequest
import app.mekasa.fable.data.model.ProductSearchResponse
import app.mekasa.fable.data.model.ReceiptScanRequest
import app.mekasa.fable.data.model.ReceiptScanResponse
import app.mekasa.fable.data.model.ShoppingItem
import app.mekasa.fable.data.model.ShoppingItemCreateRequest
import app.mekasa.fable.data.model.ShoppingItemPatch
import app.mekasa.fable.data.model.ShoppingListResponse
import app.mekasa.fable.data.model.ShoppingSyncResponse
import app.mekasa.fable.data.model.SpendingReport
import app.mekasa.fable.data.model.StoreSearchResponse
import app.mekasa.fable.data.model.StoreSelectionRequest
import app.mekasa.fable.data.model.UnknownBarcodeEvent
import app.mekasa.fable.data.model.UserProfile
import io.ktor.client.HttpClient
import io.ktor.client.HttpClientConfig
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.engine.okhttp.OkHttp
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.logging.LogLevel
import io.ktor.client.plugins.logging.Logging
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.bearerAuth
import io.ktor.client.request.forms.MultiPartFormDataContent
import io.ktor.client.request.forms.formData
import io.ktor.client.request.parameter
import io.ktor.client.request.request
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * Ktor/OkHttp implementation of [MekasaApi]. [engine] is injectable so unit
 * tests can drive the client with `MockEngine`.
 */
class KtorMekasaApi(
    baseUrl: String,
    enableLogging: Boolean = false,
    engine: HttpClientEngine? = null,
) : MekasaApi {

    private val root = baseUrl.trimEnd('/')

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        explicitNulls = false
        coerceInputValues = true
    }

    private val client: HttpClient = run {
        val configure: HttpClientConfig<*>.() -> Unit = {
            expectSuccess = false
            install(ContentNegotiation) { json(json) }
            install(HttpTimeout) {
                connectTimeoutMillis = 15_000
                requestTimeoutMillis = 45_000
                socketTimeoutMillis = 45_000
            }
            if (enableLogging) {
                install(Logging) { level = LogLevel.INFO }
            }
        }
        if (engine != null) HttpClient(engine, configure) else HttpClient(OkHttp, configure)
    }

    override suspend fun health(): HealthResponse = call(HttpMethod.Get, "/health")

    override suspend fun me(token: String): UserProfile = call(HttpMethod.Get, "/v1/me", token)

    override suspend fun createHousehold(token: String, name: String?): Household =
        call(HttpMethod.Post, "/v1/households", token, HouseholdCreateRequest(name = name))

    override suspend fun currentHousehold(token: String): Household =
        call(HttpMethod.Get, "/v1/households/current", token)

    override suspend fun updateAddress(token: String, householdId: String, address: String): Household =
        call(HttpMethod.Put, "/v1/households/$householdId/address", token, AddressUpdateRequest(address))

    override suspend fun renameHousehold(token: String, householdId: String, name: String?): Household =
        call(HttpMethod.Put, "/v1/households/$householdId/name", token, HouseholdNameUpdateRequest(name))

    override suspend fun uploadHouseholdPhoto(
        token: String,
        householdId: String,
        bytes: ByteArray,
        mimeType: String,
        filename: String,
    ): Household {
        val response = client.request("$root/v1/households/$householdId/photo") {
            method = HttpMethod.Post
            bearerAuth(token)
            setBody(
                MultiPartFormDataContent(
                    formData {
                        append(
                            key = "file",
                            value = bytes,
                            headers = Headers.build {
                                append(HttpHeaders.ContentType, mimeType)
                                append(HttpHeaders.ContentDisposition, "filename=\"$filename\"")
                            },
                        )
                    },
                ),
            )
        }
        return unwrap(response)
    }

    override suspend fun nearbyStores(token: String, householdId: String): StoreSearchResponse =
        call(HttpMethod.Get, "/v1/households/$householdId/stores/nearby", token)

    override suspend fun selectStores(token: String, householdId: String, storeIds: List<String>): Household =
        call(HttpMethod.Put, "/v1/households/$householdId/stores", token, StoreSelectionRequest(storeIds))

    override suspend fun listInventory(token: String, householdId: String): InventoryListResponse =
        call(HttpMethod.Get, "/v1/households/$householdId/inventory", token)

    override suspend fun createInventoryItem(
        token: String,
        householdId: String,
        body: InventoryItemCreateRequest,
    ): InventoryItem = call(HttpMethod.Post, "/v1/households/$householdId/inventory", token, body)

    override suspend fun patchInventoryItem(
        token: String,
        householdId: String,
        itemId: String,
        patch: InventoryItemPatch,
    ): InventoryItem = call(HttpMethod.Patch, "/v1/households/$householdId/inventory/$itemId", token, patch)

    override suspend fun refreshInventoryImage(token: String, householdId: String, itemId: String): InventoryItem =
        call(HttpMethod.Post, "/v1/households/$householdId/inventory/$itemId/refresh-image", token)

    override suspend fun consumeInventoryItem(
        token: String,
        householdId: String,
        itemId: String,
        amount: Int,
    ): InventoryItem = call(
        HttpMethod.Post,
        "/v1/households/$householdId/inventory/$itemId/consume",
        token,
        ConsumeRequest(amount),
    )

    override suspend fun consumeByBarcode(
        token: String,
        householdId: String,
        barcode: String,
        amount: Int,
    ): ConsumeByBarcodeResult = call(
        HttpMethod.Post,
        "/v1/households/$householdId/inventory/consume-by-barcode",
        token,
        ConsumeByBarcodeRequest(barcode, amount),
    )

    override suspend fun listUnknownScans(token: String, householdId: String): List<UnknownBarcodeEvent> =
        call(HttpMethod.Get, "/v1/households/$householdId/trash-scans/unknown", token)

    override suspend fun listShopping(token: String, householdId: String): ShoppingListResponse =
        call(HttpMethod.Get, "/v1/households/$householdId/shopping-list", token)

    override suspend fun createShoppingItem(
        token: String,
        householdId: String,
        body: ShoppingItemCreateRequest,
    ): ShoppingItem = call(HttpMethod.Post, "/v1/households/$householdId/shopping-list", token, body)

    override suspend fun patchShoppingItem(
        token: String,
        householdId: String,
        itemId: String,
        patch: ShoppingItemPatch,
    ): ShoppingItem = call(HttpMethod.Patch, "/v1/households/$householdId/shopping-list/$itemId", token, patch)

    override suspend fun deleteShoppingItem(token: String, householdId: String, itemId: String) {
        val response = client.request("$root/v1/households/$householdId/shopping-list/$itemId") {
            method = HttpMethod.Delete
            bearerAuth(token)
        }
        if (!response.status.isSuccess()) throw response.toApiException()
    }

    override suspend fun approveShoppingItem(token: String, householdId: String, itemId: String): ShoppingItem =
        call(HttpMethod.Post, "/v1/households/$householdId/shopping-list/$itemId/approve", token)

    override suspend fun rejectShoppingItem(token: String, householdId: String, itemId: String): ShoppingItem =
        call(HttpMethod.Post, "/v1/households/$householdId/shopping-list/$itemId/reject", token)

    override suspend fun syncShoppingFromInventory(token: String, householdId: String): ShoppingSyncResponse =
        call(HttpMethod.Post, "/v1/households/$householdId/shopping-list/sync-from-inventory", token)

    override suspend fun spending(token: String, householdId: String, period: String): SpendingReport =
        call(HttpMethod.Get, "/v1/households/$householdId/spending", token) {
            parameter("period", period)
        }

    override suspend fun listMembers(token: String, householdId: String): HouseholdMembersResponse =
        call(HttpMethod.Get, "/v1/households/$householdId/members", token)

    override suspend fun listInvites(token: String, householdId: String): HouseholdInvitesResponse =
        call(HttpMethod.Get, "/v1/households/$householdId/invites", token)

    override suspend fun createInvite(token: String, householdId: String, body: InviteCreateRequest): HouseholdInvite =
        call(HttpMethod.Post, "/v1/households/$householdId/invites", token, body)

    override suspend fun acceptInvite(token: String, inviteToken: String): HouseholdMember =
        call(HttpMethod.Post, "/v1/invites/accept", token, InviteAcceptRequest(inviteToken))

    override suspend fun updateMemberRole(
        token: String,
        householdId: String,
        memberUid: String,
        role: String,
    ): HouseholdMember = call(
        HttpMethod.Patch,
        "/v1/households/$householdId/members/$memberUid",
        token,
        MemberRoleUpdateRequest(role),
    )

    override suspend fun lookupBarcode(token: String, code: String): BarcodeLookup =
        call(HttpMethod.Get, "/v1/barcode/${code.trim()}", token)

    override suspend fun searchProducts(token: String, query: String, limit: Int): ProductSearchResponse =
        call(HttpMethod.Get, "/v1/products/search", token) {
            parameter("q", query.trim())
            parameter("limit", limit)
        }

    override suspend fun scanReceipt(
        token: String,
        householdId: String,
        rawText: String?,
        imageBase64: String?,
    ): ReceiptScanResponse = call(
        HttpMethod.Post,
        "/v1/households/$householdId/receipts/scan",
        token,
        ReceiptScanRequest(imageBase64 = imageBase64, rawText = rawText),
    )

    override fun close() {
        runCatching { client.close() }
    }

    // ------------------------------------------------------------ plumbing

    private suspend inline fun <reified T> call(
        method: HttpMethod,
        path: String,
        token: String? = null,
        body: Any? = null,
        noinline extra: HttpRequestBuilder.() -> Unit = {},
    ): T {
        val response = client.request(root + path) {
            this.method = method
            if (token != null) bearerAuth(token)
            if (body != null) {
                contentType(ContentType.Application.Json)
                setBody(body)
            }
            extra()
        }
        return unwrap(response)
    }

    private suspend inline fun <reified T> unwrap(response: HttpResponse): T {
        if (!response.status.isSuccess()) throw response.toApiException()
        val text = response.bodyAsText()
        return json.decodeFromString(text)
    }

    private suspend fun HttpResponse.toApiException(): ApiException {
        val text = runCatching { bodyAsText() }.getOrDefault("")
        return ApiException(status.value, extractDetail(text) ?: text.ifBlank { status.description })
    }

    /** FastAPI reports errors as `{"detail": "..."}` or `{"detail": [validation...]}`. */
    private fun extractDetail(text: String): String? = runCatching {
        val detail = (json.parseToJsonElement(text) as? JsonObject)?.get("detail") ?: return null
        if (detail is JsonPrimitive) detail.content else detail.toString()
    }.getOrNull()?.takeIf { it.isNotBlank() }
}
