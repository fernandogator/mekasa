package app.mekasa.android.voice

/**
 * Parses a spoken grocery phrase into quantity + product query (REQ-007).
 */
object VoicePhraseParser {
    data class Result(
        val quantity: Int,
        val productQuery: String,
        val displayName: String,
    )

    private val numberWords = mapOf(
        "a" to 1, "an" to 1, "one" to 1, "two" to 2, "three" to 3, "four" to 4,
        "five" to 5, "six" to 6, "seven" to 7, "eight" to 8, "nine" to 9,
        "ten" to 10, "eleven" to 11, "twelve" to 12,
    )

    private val fillers = setOf(
        "of", "pack", "packs", "bottle", "bottles", "box", "boxes", "bag", "bags",
    )

    fun parse(transcript: String): Result? {
        val cleaned = transcript.trim().replace(Regex("[.!?,;:]+$"), "")
        if (cleaned.isEmpty()) return null
        val tokens = cleaned.split(Regex("\\s+")).filter { it.isNotEmpty() }.toMutableList()
        if (tokens.isEmpty()) return null

        var quantity = 1
        val first = tokens.first().lowercase()
        val asInt = first.toIntOrNull()
        when {
            asInt != null && asInt > 0 -> {
                quantity = asInt.coerceAtMost(99)
                tokens.removeAt(0)
            }
            numberWords.containsKey(first) -> {
                quantity = numberWords.getValue(first)
                tokens.removeAt(0)
            }
        }

        while (tokens.isNotEmpty() && fillers.contains(tokens.first().lowercase())) {
            tokens.removeAt(0)
            if (tokens.isNotEmpty() && tokens.first().lowercase() == "of") {
                tokens.removeAt(0)
            }
        }

        if (tokens.isEmpty()) return null
        val productQuery = tokens.joinToString(" ")
        val displayName = productQuery.replaceFirstChar {
            if (it.isLowerCase()) it.titlecase() else it.toString()
        }
        return Result(quantity = quantity, productQuery = productQuery, displayName = displayName)
    }
}
