package app.mekasa.fable.diagnostics

import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * One on-device log entry; serialized in the shape the API's diagnostics and
 * error-report endpoints accept.
 *
 * Satisfies: NFR-007 (App Error Reports and Diagnostics) AC1
 * Spec version: 1.0
 */
@Serializable
data class LogEntry(
    val time: String,
    val level: String,
    val category: String,
    val message: String,
    @SerialName("request_id") val requestId: String? = null,
    @SerialName("correlation_id") val correlationId: String? = null,
    val fields: Map<String, String> = emptyMap(),
) {
    companion object {
        const val DEBUG = "debug"
        const val INFO = "info"
        const val WARNING = "warning"
        const val ERROR = "error"
    }
}

/** NFR-007 AC2: an error plus the entries that led up to it. */
@Serializable
data class ErrorReport(
    val id: String,
    val time: String,
    val where: String,
    @SerialName("error_type") val errorType: String,
    val message: String,
    val status: Int? = null,
    val path: String? = null,
    @SerialName("request_id") val requestId: String? = null,
    @SerialName("correlation_id") val correlationId: String? = null,
    val breadcrumbs: List<LogEntry> = emptyList(),
)

/** Which build sent a report (NFR-007 AC3). The API requires [platform], so it is always encoded. */
@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class ClientApp(
    @EncodeDefault val platform: String = "android",
    @SerialName("app_version") val appVersion: String = "",
    val build: String = "",
    @SerialName("os_version") val osVersion: String = "",
    @SerialName("device_model") val deviceModel: String = "",
)

@Serializable
data class ClientErrorBatch(val app: ClientApp, val reports: List<ErrorReport>)

@Serializable
data class ClientErrorBatchResponse(val accepted: Int = 0, val dropped: Int = 0)

@Serializable
data class ClientDiagnosticsUpload(val app: ClientApp, val note: String? = null, val entries: List<LogEntry>)

@Serializable
data class ClientDiagnosticsResponse(
    @SerialName("diagnostics_id") val diagnosticsId: String,
    val reference: String,
    val entries: Int = 0,
)
