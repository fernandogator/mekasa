package app.mekasa.fable.diagnostics

import app.mekasa.fable.data.remote.ApiException
import app.mekasa.fable.data.remote.KtorMekasaApi
import app.mekasa.fable.data.remote.RequestTracing
import app.mekasa.fable.session.InMemoryEmailMemory
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.support.FakeApi
import app.mekasa.fable.support.FakeAuthGateway
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.OutgoingContent
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Satisfies: NFR-007 (App Error Reports and Diagnostics)
 * Acceptance criteria: AC1, AC2, AC5, AC6, AC7
 * Spec version: 1.0
 */
@OptIn(ExperimentalCoroutinesApi::class)
class AppDiagnosticsTest {

    @Before
    fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        AppLog.reset()
        AppLog.logcat = false
        ErrorReporter.reset()
        // Nothing runs on this scope unless a test advances it, so flushes are explicit.
        ErrorReporter.scope = CoroutineScope(StandardTestDispatcher())
    }

    @After
    fun tearDown() {
        AppLog.reset()
        ErrorReporter.reset()
        Dispatchers.resetMain()
    }

    private fun report(id: String) = ErrorReport(id = id, time = "t", where = "test", errorType = "Error", message = "m")

    // ------------------------------------------------------------ AC1 / AC7

    @Test
    fun `entries mask emails and bearer tokens, redact secret fields and cap length`() {
        AppLog.info(
            "auth",
            "Signed in as ana@example.com with Bearer abc.def-123",
            mapOf("email" to "ana@example.com", "token" to "abc", "item" to "Diet Coke", "skip" to null),
        )

        val entry = AppLog.snapshot().single()
        assertFalse(entry.message, "ana@example.com" in entry.message)
        assertFalse(entry.message, "abc.def-123" in entry.message)
        assertEquals(LogPrivacy.REDACTED, entry.fields["email"])
        assertEquals(LogPrivacy.REDACTED, entry.fields["token"])
        assertEquals("Diet Coke", entry.fields["item"])
        assertFalse("skip" in entry.fields)

        AppLog.info("app", "x".repeat(2_000))
        assertTrue(AppLog.snapshot().last().message.length <= LogPrivacy.MAX_TEXT + 1)
    }

    @Test
    fun `the log keeps only the last 500 entries`() {
        repeat(AppLog.CAPACITY + 25) { AppLog.debug("app", "entry $it") }

        val entries = AppLog.snapshot()
        assertEquals(AppLog.CAPACITY, entries.size)
        assertEquals("entry 25", entries.first().message)
        assertEquals("entry ${AppLog.CAPACITY + 24}", entries.last().message)
    }

    @Test
    fun `the log survives a relaunch through its store`() {
        val store = object : LogStore {
            val saved = mutableListOf<LogEntry>()
            override fun load() = saved.toList()
            override fun append(entry: LogEntry) { saved += entry }
            override fun rewrite(entries: List<LogEntry>) { saved.clear(); saved += entries }
        }
        AppLog.install(store)
        AppLog.info("app", "before relaunch")
        AppLog.reset()
        AppLog.install(store)

        assertEquals("before relaunch", AppLog.snapshot().single().message)
    }

    // ------------------------------------------------------------ AC2

    @Test
    fun `an error queues a report with the failed call and the 20 entries before it`() {
        ErrorReporter.enabled = true
        repeat(30) { AppLog.info("app", "step $it") }
        val failure = ApiException(500, "boom", path = "/v1/households/hh-1/inventory", requestId = "r1", correlationId = "c1")

        val entry = AppLog.error("session.consume", failure, category = "scanner")

        assertEquals(LogEntry.ERROR, entry.level)
        assertEquals("session.consume failed: boom", entry.message)
        val report = ErrorReporter.queued().single()
        assertEquals("session.consume", report.where)
        assertEquals("ApiException", report.errorType)
        assertEquals(500, report.status)
        assertEquals("/v1/households/hh-1/inventory", report.path)
        assertEquals("r1", report.requestId)
        assertEquals("c1", report.correlationId)
        assertEquals(AppLog.BREADCRUMBS, report.breadcrumbs.size)
        assertEquals("step 10", report.breadcrumbs.first().message)
        assertEquals("step 29", report.breadcrumbs.last().message)
    }

    @Test
    fun `nothing is queued while reporting is off`() {
        AppLog.error("session.consume", IllegalStateException("boom"))
        assertTrue(ErrorReporter.queued().isEmpty())
    }

    @Test
    fun `the queue keeps the newest 50 reports`() {
        ErrorReporter.enabled = true
        repeat(ErrorReporter.MAX_QUEUED + 5) { ErrorReporter.enqueue(report("r$it")) }

        val queued = ErrorReporter.queued()
        assertEquals(ErrorReporter.MAX_QUEUED, queued.size)
        assertEquals("r5", queued.first().id)
    }

    @Test
    fun `flush sends batches of 20 and empties the queue`() = runTest {
        ErrorReporter.enabled = true
        val batches = mutableListOf<ClientErrorBatch>()
        ErrorReporter.setUploader { batches += it }
        repeat(45) { ErrorReporter.enqueue(report("r$it")) }

        assertEquals(45, ErrorReporter.flush())

        assertEquals(listOf(20, 20, 5), batches.map { it.reports.size })
        assertTrue(ErrorReporter.queued().isEmpty())
    }

    @Test
    fun `a failed upload keeps the reports and never creates a report itself`() = runTest {
        ErrorReporter.enabled = true
        ErrorReporter.setUploader { throw ApiException(503, "unavailable") }
        repeat(3) { ErrorReporter.enqueue(report("r$it")) }

        assertEquals(0, ErrorReporter.flush())

        assertEquals(3, ErrorReporter.queued().size)
        val last = AppLog.snapshot().last()
        assertEquals(LogEntry.WARNING, last.level)
        assertEquals("Error report upload failed", last.message)
    }

    @Test
    fun `nothing is sent without an uploader`() = runTest {
        ErrorReporter.enabled = true
        ErrorReporter.enqueue(report("r1"))

        assertEquals(0, ErrorReporter.flush())
        assertEquals(1, ErrorReporter.queued().size)
    }

    // ------------------------------------------------------------ session wiring

    private fun signedIn(api: FakeApi): SessionViewModel =
        SessionViewModel(api = api, auth = FakeAuthGateway(), emailMemory = InMemoryEmailMemory()).also {
            it.signInWithEmail("ana@example.com", "secret", createAccount = false)
        }

    @Test
    fun `a failed action is logged where it happened and its report reaches the API`() = runTest {
        ErrorReporter.enabled = true
        val api = FakeApi()
        val vm = signedIn(api)
        assertTrue(AppLog.snapshot().any { it.category == "auth" && it.message == "Signed in" })

        api.failWith = ApiException(500, "boom", path = "/v1/households/hh-1/inventory/i1/consume")
        vm.consume("i1")

        val report = ErrorReporter.queued().single()
        assertEquals("session.consume", report.where)
        assertEquals(500, report.status)
        assertEquals(1, ErrorReporter.flush())
        assertEquals("session.consume", api.errorBatches.single().reports.single().where)
        assertTrue(ErrorReporter.queued().isEmpty())
    }

    @Test
    fun `a receipt scan leaves started and finished breadcrumbs in its flow`() {
        val vm = signedIn(FakeApi())
        vm.scanReceipt(rawText = "BANANAS 0.99") {}

        val flowId = vm.receiptFlowId
        val receipt = AppLog.snapshot().filter { it.category == "receipt" }
        assertEquals(listOf("Receipt scan started", "Receipt scan finished"), receipt.map { it.message })
        receipt.forEach { assertEquals(flowId, it.correlationId) }
    }

    @Test
    fun `a failed receipt scan is reported as receipt scan with its flow id`() {
        ErrorReporter.enabled = true
        val api = FakeApi()
        val vm = signedIn(api)
        api.failWith = ApiException(502, "receipt_parse_failed")
        vm.scanReceipt(rawText = "BANANAS 0.99") {}

        val report = ErrorReporter.queued().single()
        assertEquals("receipt.scan", report.where)
        assertEquals(vm.receiptFlowId, report.correlationId)
    }

    @Test
    fun `an error shown without a call is still logged with its action`() {
        ErrorReporter.enabled = true
        val vm = signedIn(FakeApi())
        vm.replaceItemPhoto("i1", ByteArray(0))

        assertEquals("session.replaceItemPhoto", ErrorReporter.queued().single().where)
        assertEquals("The photo was empty.", vm.state.value.error)
    }

    @Test
    fun `sign out stops uploads`() = runTest {
        ErrorReporter.enabled = true
        val api = FakeApi()
        val vm = signedIn(api)
        vm.signOut()
        ErrorReporter.enqueue(report("r1"))

        assertEquals(0, ErrorReporter.flush())
        assertTrue(api.errorBatches.isEmpty())
        assertTrue(AppLog.snapshot().any { it.message == "Signed out" })
    }

    // ------------------------------------------------------------ AC5

    @Test
    fun `send diagnostics uploads the log and returns the reference`() {
        val api = FakeApi()
        val vm = signedIn(api)
        var result: String? = null
        vm.sendDiagnostics { result = it }

        assertEquals("Sent. Reference 3F9A12C7", result)
        val upload = api.diagnosticsUploads.single()
        assertTrue(upload.entries.any { it.message == "Signed in" })
    }

    @Test
    fun `send diagnostics failure shows the retry line`() {
        val api = FakeApi()
        val vm = signedIn(api)
        api.failWith = ApiException(429, "diagnostics_rate_limited")
        var result: String? = null
        vm.sendDiagnostics { result = it }

        assertEquals(SessionViewModel.DIAGNOSTICS_FAILED, result)
    }

    @Test
    fun `send diagnostics never uploads from the offline preview`() {
        val api = FakeApi()
        val vm = SessionViewModel(api = api, auth = FakeAuthGateway(), emailMemory = InMemoryEmailMemory())
        vm.browseOffline()
        var result: String? = null
        vm.sendDiagnostics { result = it }

        assertEquals(SessionViewModel.DIAGNOSTICS_FAILED, result)
        assertTrue(api.diagnosticsUploads.isEmpty())
    }

    // ------------------------------------------------------------ AC1 API entries, AC6

    private val requests = mutableListOf<HttpRequestData>()

    private fun ktor(status: HttpStatusCode, body: String) = KtorMekasaApi(
        "https://api.test/",
        engine = MockEngine { request ->
            requests += request
            respond(body, status, headersOf(HttpHeaders.ContentType, "application/json"))
        },
    )

    @Test
    fun `each API call leaves one entry with method, path, status and request id`() = runTest {
        ktor(HttpStatusCode.OK, """{"status":"ok"}""").health()

        val entry = AppLog.snapshot().single()
        assertEquals("api", entry.category)
        assertEquals(LogEntry.INFO, entry.level)
        assertEquals("GET", entry.fields["method"])
        assertEquals("/health", entry.fields["path"])
        assertEquals("200", entry.fields["status"])
        assertNotNull(entry.fields["duration_ms"])
        assertEquals(requests.single().headers[RequestTracing.REQUEST_ID_HEADER], entry.requestId)
    }

    @Test
    fun `a failed call is a warning and its exception names the call`() = runTest {
        val api = ktor(HttpStatusCode.InternalServerError, """{"detail":"boom"}""")
        val error = runCatching { api.listInventory("t", "hh-1") }.exceptionOrNull() as ApiException

        val entry = AppLog.snapshot().single()
        assertEquals(LogEntry.WARNING, entry.level)
        assertEquals("500", entry.fields["status"])
        assertEquals("/v1/households/hh-1/inventory", error.path)
        assertEquals(entry.requestId, error.requestId)
        assertEquals(500, error.status)
    }

    @Test
    fun `reports and diagnostics post to their endpoints`() = runTest {
        ktor(HttpStatusCode.Accepted, """{"accepted":1,"dropped":0}""")
            .reportClientErrors("t", ClientErrorBatch(ClientApp(), listOf(report("r1"))))
        val response = ktor(HttpStatusCode.Created, """{"diagnostics_id":"abcd1234ef","reference":"ABCD1234","entries":0}""")
            .uploadDiagnostics("t", ClientDiagnosticsUpload(ClientApp(), entries = emptyList()))

        assertEquals(listOf("/v1/client-errors", "/v1/client-diagnostics"), requests.map { it.url.encodedPath })
        val body = (requests.first().body as OutgoingContent.ByteArrayContent).bytes().decodeToString()
        assertTrue(body, "\"platform\":\"android\"" in body)
        assertTrue(body, "\"error_type\":\"Error\"" in body)
        assertEquals("ABCD1234", response.reference)
    }

    @Test
    fun `crash reports identify the user only by the API's user ref`() {
        assertEquals("4a49acf8a6bd", userRef("uid-1"))
        assertFalse(CrashReporting.isActive)
    }
}
