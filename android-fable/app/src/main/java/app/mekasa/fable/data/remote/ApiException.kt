package app.mekasa.fable.data.remote

import app.mekasa.fable.diagnostics.FailedCall

/** Non-2xx response from the Mekasa API. [detail] is the FastAPI `detail` when present. */
class ApiException(
    override val status: Int,
    override val detail: String,
    override val path: String? = null,
    override val requestId: String? = null,
    override val correlationId: String? = null,
) : Exception("HTTP $status: $detail"), FailedCall {
    val isUnauthorized: Boolean get() = status == 401
    val isForbidden: Boolean get() = status == 403
    val isNotFound: Boolean get() = status == 404

    /** Human-facing copy for dialogs; maps the backend's snake_case detail codes. */
    val userMessage: String
        get() = when (detail) {
            "Forbidden" -> "You don't have permission to do that in this household."
            "Not found" -> "That record no longer exists."
            "file_too_large" -> "Photo is too large (max 5 MB)."
            "empty_file" -> "The photo was empty."
            "image_required" -> "Please choose an image file."
            "image_or_text_required" -> "Provide a receipt photo or text."
            else -> detail.ifBlank { "Request failed (HTTP $status)" }
        }
}
