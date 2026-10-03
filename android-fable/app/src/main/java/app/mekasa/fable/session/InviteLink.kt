package app.mekasa.fable.session

/**
 * Extracts the invite token from `mekasa://invite?token=…` (or `mekasa://invite/<token>`).
 * Pure Kotlin so it is testable without Android's `Uri`.
 */
object InviteLink {
    private const val SCHEME = "mekasa://"

    fun tokenFrom(link: String?): String? {
        val raw = link?.trim().orEmpty()
        if (!raw.startsWith(SCHEME, ignoreCase = true)) return null
        val rest = raw.substring(SCHEME.length)
        val pathAndQuery = rest.split('?', limit = 2)
        val path = pathAndQuery[0].trim('/')
        if (!path.startsWith("invite", ignoreCase = true)) return null

        val fromQuery = pathAndQuery.getOrNull(1)
            ?.split('&')
            ?.map { it.split('=', limit = 2) }
            ?.firstOrNull { it.size == 2 && it[0].equals("token", ignoreCase = true) }
            ?.get(1)
            ?.let(::decode)
        if (!fromQuery.isNullOrBlank()) return fromQuery

        return path.split('/').drop(1).firstOrNull { it.isNotBlank() }?.let(::decode)
    }

    private fun decode(value: String): String =
        runCatching { java.net.URLDecoder.decode(value, "UTF-8") }.getOrDefault(value)
}
