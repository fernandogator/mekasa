package app.mekasa.fable.diagnostics

/**
 * What may be written to the on-device log (NFR-007 AC7, NFR-006 AC6): no tokens,
 * passwords, emails, street addresses, phone numbers, household or person names.
 * Item names, receipt line text and barcodes are fine.
 *
 * Satisfies: NFR-007 (App Error Reports and Diagnostics) AC7; NFR-002 AC3
 * Spec version: 1.0
 */
object LogPrivacy {
    const val REDACTED = "[redacted]"
    const val MAX_TEXT = 500

    private val email = Regex("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}")
    private val bearer = Regex("(?i)bearer\\s+[A-Za-z0-9._:\\-]+")
    private val secretKeys = setOf(
        "authorization", "token", "id_token", "fcm_token", "invite_token", "password",
        "email", "address", "street", "phone", "display_name", "household_name", "member_name",
    )

    fun text(value: String): String {
        val masked = bearer.replace(email.replace(value, REDACTED), "Bearer $REDACTED")
        return if (masked.length <= MAX_TEXT) masked else masked.take(MAX_TEXT) + "…"
    }

    fun fields(values: Map<String, Any?>): Map<String, String> = buildMap {
        for ((key, value) in values) {
            if (value == null) continue
            put(key, if (key.lowercase() in secretKeys) REDACTED else text(value.toString()))
        }
    }
}
