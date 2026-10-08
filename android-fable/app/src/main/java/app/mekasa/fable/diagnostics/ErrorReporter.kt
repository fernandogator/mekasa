package app.mekasa.fable.diagnostics

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.io.File
import java.util.concurrent.Executor
import java.util.concurrent.Executors

/** Where queued reports wait between launches. */
interface ReportStore {
    fun load(): List<ErrorReport>
    fun save(reports: List<ErrorReport>)
}

class FileReportStore(
    private val file: File,
    private val io: Executor = Executors.newSingleThreadExecutor(),
) : ReportStore {
    private val serializer = ListSerializer(ErrorReport.serializer())

    override fun load(): List<ErrorReport> = runCatching {
        if (file.exists()) json.decodeFromString(serializer, file.readText()) else emptyList()
    }.getOrDefault(emptyList())

    override fun save(reports: List<ErrorReport>) = io.execute {
        runCatching {
            file.parentFile?.mkdirs()
            val temp = File(file.parentFile, file.name + ".tmp")
            temp.writeText(json.encodeToString(serializer, reports))
            temp.renameTo(file)
        }
    }

    private companion object {
        val json = Json { ignoreUnknownKeys = true; explicitNulls = false }
    }
}

/**
 * Queues error reports on disk and sends them to `POST /v1/client-errors` while
 * signed in: shortly after an error and when the app comes back to the foreground.
 * Off unless [enabled] (the app turns it on; tests and previews leave it off).
 *
 * Satisfies: NFR-007 (App Error Reports and Diagnostics) AC2
 * Spec version: 1.0
 */
object ErrorReporter {
    const val MAX_QUEUED = 50
    const val BATCH_SIZE = 20
    const val FLUSH_DELAY_MILLIS = 3_000L

    @Volatile var enabled: Boolean = false
    @Volatile var app: ClientApp = ClientApp()

    private val lock = Any()
    private val queue = ArrayDeque<ErrorReport>()
    private val flushing = Mutex()
    @Volatile private var store: ReportStore? = null
    @Volatile private var uploader: (suspend (ClientErrorBatch) -> Unit)? = null
    @Volatile var scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var scheduled: Job? = null

    fun install(store: ReportStore, app: ClientApp) {
        val loaded = store.load().takeLast(MAX_QUEUED)
        synchronized(lock) {
            queue.clear()
            queue.addAll(loaded)
            this.store = store
        }
        this.app = app
    }

    /** Set while signed in to a real household; null when signed out or in the preview. */
    fun setUploader(upload: (suspend (ClientErrorBatch) -> Unit)?) {
        uploader = upload
        if (upload != null) flushSoon(0)
    }

    fun enqueue(report: ErrorReport) {
        if (!enabled) return
        synchronized(lock) {
            queue.addLast(report)
            while (queue.size > MAX_QUEUED) queue.removeFirst()
            store?.save(queue.toList())
        }
        flushSoon()
    }

    fun queued(): List<ErrorReport> = synchronized(lock) { queue.toList() }

    fun flushSoon(delayMillis: Long = FLUSH_DELAY_MILLIS) {
        if (!enabled || uploader == null) return
        synchronized(lock) {
            if (scheduled?.isActive == true) return
            scheduled = scope.launch {
                delay(delayMillis)
                flush()
            }
        }
    }

    /**
     * Sends queued reports in batches; stops at the first failure and keeps the rest
     * for later. A failed upload is only a warning, so it never queues a report itself.
     */
    suspend fun flush(): Int = flushing.withLock {
        var sent = 0
        while (true) {
            val upload = uploader ?: break
            val batch = synchronized(lock) { queue.take(BATCH_SIZE) }
            if (batch.isEmpty()) break
            try {
                upload(ClientErrorBatch(app, batch))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                AppLog.warning("app", "Error report upload failed", mapOf("queued" to queued().size, "error_type" to e::class.simpleName))
                break
            }
            val ids = batch.map { it.id }.toSet()
            synchronized(lock) {
                queue.removeAll { it.id in ids }
                store?.save(queue.toList())
            }
            sent += batch.size
        }
        sent
    }

    /** Unit tests: empty queue, no disk, no uploader. */
    fun reset() {
        synchronized(lock) {
            queue.clear()
            scheduled?.cancel()
            scheduled = null
            store = null
        }
        uploader = null
        enabled = false
        app = ClientApp()
        scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    }
}
