package app.mekasa.fable.diagnostics

import android.util.Log
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File
import java.time.Instant
import java.util.UUID
import java.util.concurrent.Executor
import java.util.concurrent.Executors

/** The call an error came from, when there was one (implemented by `ApiException`). */
interface FailedCall {
    val status: Int?
    /** The API's error code or text, e.g. `receipt_parse_failed`. */
    val detail: String?
    val path: String?
    val requestId: String?
    val correlationId: String?
}

/** Where log entries are kept between launches. */
interface LogStore {
    fun load(): List<LogEntry>
    fun append(entry: LogEntry)
    fun rewrite(entries: List<LogEntry>)
}

/** JSON lines in the app's private files; all writes happen off the caller's thread. */
class FileLogStore(
    private val file: File,
    private val io: Executor = Executors.newSingleThreadExecutor(),
) : LogStore {
    override fun load(): List<LogEntry> = runCatching {
        if (!file.exists()) return emptyList()
        file.readLines().mapNotNull { line -> runCatching { json.decodeFromString<LogEntry>(line) }.getOrNull() }
    }.getOrDefault(emptyList())

    override fun append(entry: LogEntry) = io.execute {
        runCatching {
            file.parentFile?.mkdirs()
            file.appendText(json.encodeToString(entry) + "\n")
        }
    }

    override fun rewrite(entries: List<LogEntry>) = io.execute {
        runCatching {
            file.parentFile?.mkdirs()
            val temp = File(file.parentFile, file.name + ".tmp")
            temp.writeText(entries.joinToString("") { json.encodeToString(it) + "\n" })
            temp.renameTo(file)
        }
    }

    private companion object {
        val json = Json { ignoreUnknownKeys = true; explicitNulls = false }
    }
}

/**
 * The app's log: the last [CAPACITY] entries in memory and on disk, mirrored to
 * Logcat (tag `Mekasa`) and any extra sinks such as Crashlytics. Every [error] also
 * becomes an [ErrorReport] for [ErrorReporter].
 *
 * Satisfies: NFR-007 (App Error Reports and Diagnostics) AC1, AC2, AC7
 * Spec version: 1.0
 */
object AppLog {
    const val CAPACITY = 500
    const val BREADCRUMBS = 20
    const val TAG = "Mekasa"

    private val lock = Any()
    private val entries = ArrayDeque<LogEntry>()
    private var appendsSinceRewrite = 0

    @Volatile private var store: LogStore? = null
    @Volatile var clock: () -> Instant = Instant::now
    @Volatile var logcat: Boolean = true
    private val sinks = mutableListOf<(LogEntry) -> Unit>()

    fun install(store: LogStore) {
        val loaded = store.load().takeLast(CAPACITY)
        synchronized(lock) {
            entries.clear()
            entries.addAll(loaded)
            this.store = store
        }
    }

    fun addSink(sink: (LogEntry) -> Unit) = synchronized(lock) { sinks += sink }

    fun debug(category: String, message: String, fields: Map<String, Any?> = emptyMap()) =
        write(LogEntry.DEBUG, category, message, fields)

    fun info(
        category: String,
        message: String,
        fields: Map<String, Any?> = emptyMap(),
        requestId: String? = null,
        correlationId: String? = null,
    ) = write(LogEntry.INFO, category, message, fields, requestId, correlationId)

    fun warning(
        category: String,
        message: String,
        fields: Map<String, Any?> = emptyMap(),
        requestId: String? = null,
        correlationId: String? = null,
    ) = write(LogEntry.WARNING, category, message, fields, requestId, correlationId)

    /**
     * An error the user saw or the app gave up on (AC1). [where] names the place,
     * e.g. `session.scanReceipt`. Queues a report with the entries before it (AC2).
     */
    fun error(
        where: String,
        error: Throwable? = null,
        message: String? = null,
        category: String = "app",
        correlationId: String? = null,
        fields: Map<String, Any?> = emptyMap(),
    ): LogEntry {
        val call = error as? FailedCall
        val type = error?.let { it::class.simpleName ?: "Throwable" } ?: "Error"
        val detail = message ?: call?.detail ?: error?.message ?: type
        val breadcrumbs = recent(BREADCRUMBS)
        val entry = write(
            LogEntry.ERROR,
            category,
            "$where failed: $detail",
            mapOf(
                "where" to where,
                "error_type" to type,
                "status" to call?.status,
                "path" to call?.path,
                "detail" to call?.detail?.takeIf { it != detail },
            ) + fields,
            call?.requestId,
            call?.correlationId ?: correlationId,
        )
        ErrorReporter.enqueue(
            ErrorReport(
                id = UUID.randomUUID().toString().replace("-", ""),
                time = entry.time,
                where = where,
                errorType = type,
                message = LogPrivacy.text(call?.detail?.takeIf { it != detail }?.let { "$detail [$it]" } ?: detail),
                status = call?.status,
                path = call?.path,
                requestId = entry.requestId,
                correlationId = entry.correlationId,
                breadcrumbs = breadcrumbs,
            ),
        )
        return entry
    }

    fun snapshot(): List<LogEntry> = synchronized(lock) { entries.toList() }

    fun recent(count: Int): List<LogEntry> = synchronized(lock) { entries.toList().takeLast(count) }

    /** Unit tests: forget everything and stop writing to disk. */
    fun reset() = synchronized(lock) {
        entries.clear()
        sinks.clear()
        store = null
        appendsSinceRewrite = 0
        clock = Instant::now
    }

    private fun write(
        level: String,
        category: String,
        message: String,
        fields: Map<String, Any?>,
        requestId: String? = null,
        correlationId: String? = null,
    ): LogEntry {
        val entry = LogEntry(
            time = clock().toString(),
            level = level,
            category = category,
            message = LogPrivacy.text(message),
            requestId = requestId,
            correlationId = correlationId,
            fields = LogPrivacy.fields(fields),
        )
        val listeners: List<(LogEntry) -> Unit>
        synchronized(lock) {
            entries.addLast(entry)
            while (entries.size > CAPACITY) entries.removeFirst()
            store?.let { store ->
                if (++appendsSinceRewrite >= CAPACITY) {
                    appendsSinceRewrite = 0
                    store.rewrite(entries.toList())
                } else {
                    store.append(entry)
                }
            }
            listeners = sinks.toList()
        }
        if (logcat) Log.println(priority(level), TAG, line(entry))
        listeners.forEach { sink -> runCatching { sink(entry) } }
        return entry
    }

    /** One readable line, used for Logcat and Crashlytics. */
    fun line(entry: LogEntry): String = buildString {
        append('[').append(entry.category).append("] ").append(entry.message)
        if (entry.fields.isNotEmpty()) append(' ').append(entry.fields)
        entry.correlationId?.let { append(" cid=").append(it) }
        entry.requestId?.let { append(" rid=").append(it) }
    }

    private fun priority(level: String) = when (level) {
        LogEntry.DEBUG -> Log.DEBUG
        LogEntry.WARNING -> Log.WARN
        LogEntry.ERROR -> Log.ERROR
        else -> Log.INFO
    }
}
