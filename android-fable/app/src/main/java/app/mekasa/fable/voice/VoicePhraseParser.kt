package app.mekasa.fable.voice

/**
 * Turns a spoken (or typed) grocery phrase into a quantity and a catalog query (REQ-007).
 *
 * Handles leading quantities as digits or words ("two", "a dozen"), trailing quantities
 * ("avocados x3", "milk, 2"), packaging fillers ("three packs of", "a bottle of"), and
 * the verbs people add when talking to a phone ("add", "buy", "we need").
 */
object VoicePhraseParser {

    data class Parsed(
        val quantity: Int,
        val query: String,
        val displayName: String,
    )

    private val leadingVerbs = setOf("add", "buy", "get", "grab", "need", "we", "please", "put", "i")
    private val articles = setOf("a", "an", "the", "some")

    private val numberWords = mapOf(
        "one" to 1, "two" to 2, "three" to 3, "four" to 4, "five" to 5, "six" to 6,
        "seven" to 7, "eight" to 8, "nine" to 9, "ten" to 10, "eleven" to 11, "twelve" to 12,
        "dozen" to 12, "couple" to 2, "few" to 3, "pair" to 2,
    )

    private val packaging = setOf(
        "pack", "packs", "package", "packages", "bottle", "bottles", "box", "boxes", "bag", "bags",
        "can", "cans", "carton", "cartons", "jar", "jars", "loaf", "loaves", "bunch", "bunches",
        "gallon", "gallons", "case", "cases", "units", "unit", "pieces", "piece",
    )

    private val trailingQty = Regex("""^(.*?)[\s,]*(?:x\s*|times\s*)?(\d{1,3})$""", RegexOption.IGNORE_CASE)

    fun parse(phrase: String): Parsed? {
        var text = phrase.trim()
            .replace(Regex("""[.!?;:]+$"""), "")
            .replace(Regex("""\s+"""), " ")
        if (text.isEmpty()) return null

        var quantity: Int? = null

        trailingQty.matchEntire(text)?.let { match ->
            val head = match.groupValues[1].trim().trimEnd(',')
            val n = match.groupValues[2].toIntOrNull()
            if (head.isNotEmpty() && n != null && n > 0) {
                quantity = n
                text = head
            }
        }

        val tokens = ArrayDeque(text.split(' ').filter { it.isNotBlank() })

        while (tokens.isNotEmpty() && tokens.first().lowercase() in leadingVerbs) tokens.removeFirst()

        if (quantity == null) {
            val first = tokens.firstOrNull()?.lowercase()
            val digits = first?.toIntOrNull()
            when {
                digits != null && digits > 0 -> {
                    quantity = digits
                    tokens.removeFirst()
                }
                first != null && first in numberWords -> {
                    quantity = numberWords.getValue(first)
                    tokens.removeFirst()
                }
                first != null && first in articles -> {
                    tokens.removeFirst()
                    val next = tokens.firstOrNull()?.lowercase()
                    if (next != null && next in numberWords) {
                        quantity = numberWords.getValue(next)
                        tokens.removeFirst()
                    }
                }
            }
        }

        while (tokens.isNotEmpty() && tokens.first().lowercase() in packaging) {
            tokens.removeFirst()
            if (tokens.firstOrNull()?.lowercase() == "of") tokens.removeFirst()
        }
        while (tokens.isNotEmpty() && tokens.first().lowercase() in articles) tokens.removeFirst()

        if (tokens.isEmpty()) return null
        val query = tokens.joinToString(" ")
        return Parsed(
            quantity = (quantity ?: 1).coerceIn(1, 999),
            query = query,
            displayName = query.split(' ').joinToString(" ") { word ->
                word.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
            },
        )
    }
}
