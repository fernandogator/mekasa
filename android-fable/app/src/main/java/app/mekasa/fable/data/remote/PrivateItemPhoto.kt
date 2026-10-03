package app.mekasa.fable.data.remote

import java.util.UUID

/**
 * Household-private item photos (REQ-INV-019 AC3/AC8).
 *
 * `…/v1/households/{hid}/item-photos/{photo_id}` on the API host only loads with the
 * member's bearer token; plain image loaders get a 401. [ImageAuth] mirrors the
 * session token so Coil requests can carry it.
 *
 * Satisfies: REQ-INV-019 (Replace an Item Picture With a Private Photo)
 * Acceptance criteria: AC3, AC8
 * Spec version: 1.0
 */
object PrivateItemPhoto {
    fun isPrivate(url: String?, apiBaseUrl: String?): Boolean {
        if (url.isNullOrBlank() || apiBaseUrl.isNullOrBlank()) return false
        val apiHost = hostOf(apiBaseUrl) ?: return false
        val host = hostOf(url) ?: return false
        if (!host.equals(apiHost, ignoreCase = true)) return false
        val path = url.substringAfter("://").substringAfter('/', "").substringBefore('?').substringBefore('#')
        val parts = path.split('/').filter { it.isNotEmpty() }
        if (parts.size != 5) return false
        if (parts[0] != "v1" || parts[1] != "households" || parts[3] != "item-photos") return false
        return runCatching { UUID.fromString(parts[4]) }.isSuccess
    }

    /** Headers for a private photo request; empty when signed out. */
    fun headers(token: String?): Map<String, String> =
        if (token.isNullOrBlank()) emptyMap() else mapOf("Authorization" to "Bearer $token")

    private fun hostOf(url: String): String? {
        if (!url.contains("://")) return null
        val authority = url.substringAfter("://").substringBefore('/').substringBefore('?')
        val withoutUser = authority.substringAfterLast('@')
        return withoutUser.lowercase().takeIf { it.isNotEmpty() }
    }
}

/** Process-wide bearer token + API root for image loads, set by the session layer. */
object ImageAuth {
    @Volatile var apiBaseUrl: String? = null
    @Volatile var token: String? = null
}
