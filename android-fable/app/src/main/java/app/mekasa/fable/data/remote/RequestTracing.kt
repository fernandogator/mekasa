package app.mekasa.fable.data.remote

import java.util.UUID
import kotlin.coroutines.AbstractCoroutineContextElement
import kotlin.coroutines.CoroutineContext

/**
 * Request and correlation ids for backend logs. Every call carries a new
 * `X-Request-ID`; calls made inside `withContext(CorrelationId(...))` also
 * carry that receipt flow's `X-Correlation-ID`.
 *
 * Satisfies: NFR-006 (Request Tracing and Diagnostic Logs)
 * Acceptance criteria: AC1, AC7
 * Spec version: 1.0
 */
object RequestTracing {
    const val REQUEST_ID_HEADER = "X-Request-ID"
    const val CORRELATION_ID_HEADER = "X-Correlation-ID"

    /** 32 lowercase hex characters, matching the backend's generated ids. */
    fun newId(): String = UUID.randomUUID().toString().replace("-", "")

    fun headers(correlationId: String?): Map<String, String> = buildMap {
        put(REQUEST_ID_HEADER, newId())
        if (!correlationId.isNullOrBlank()) put(CORRELATION_ID_HEADER, correlationId)
    }
}

/** The receipt flow a coroutine's API calls belong to. */
data class CorrelationId(val value: String) : AbstractCoroutineContextElement(Key) {
    companion object Key : CoroutineContext.Key<CorrelationId>
}
