package app.mekasa.fable.data

import android.content.SharedPreferences
import app.mekasa.fable.data.model.DuplicateGroup
import app.mekasa.fable.data.model.DuplicateReason
import app.mekasa.fable.data.model.InventoryItem
import java.text.Normalizer
import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.temporal.ChronoUnit
import java.util.Locale

/**
 * Grouping, survivor choice and merge rules shared with the backend, so the offline
 * preview finds and merges duplicates the same way the API does.
 * Satisfies: REQ-INV-021 AC1–AC3, AC5, AC6
 * Spec version: 1.0
 */
object InventoryDuplicates {
    const val EMPTY_TITLE = "No duplicates found"
    const val EMPTY_SUBTITLE = "Your inventory is tidy."
    const val KEEPS_PHOTO = "Keeps this photo"

    private val marks = Regex("\\p{M}+")

    // ---------------------------------------------------------------- names (AC1)

    fun dedupeName(name: String): String {
        val folded = Normalizer.normalize(name.lowercase(Locale.ROOT), Normalizer.Form.NFKD).replace(marks, "")
        val cleaned = buildString { folded.forEach { append(if (it in 'a'..'z' || it in '0'..'9') it else ' ') } }
        return cleaned.split(' ').filter { it.isNotEmpty() }.joinToString(" ") { singular(it) }
    }

    private fun singular(word: String): String = when {
        word.length <= 3 -> word
        word.endsWith("ies") -> word.dropLast(3) + "y"
        listOf("xes", "ches", "shes", "sses", "zes", "oes").any { word.endsWith(it) } -> word.dropLast(2)
        word.endsWith("s") && listOf("ss", "us", "is").none { word.endsWith(it) } -> word.dropLast(1)
        else -> word
    }

    private fun keys(item: InventoryItem): List<Pair<DuplicateReason, String>> = buildList {
        item.barcode?.trim()?.takeIf { it.isNotEmpty() }?.let { add(DuplicateReason.SameBarcode to it) }
        item.productId?.trim()?.takeIf { it.isNotEmpty() }?.let { add(DuplicateReason.SameProduct to it) }
        val name = dedupeName(item.name)
        if (name.isNotEmpty()) add(DuplicateReason.SameName to "${item.category.trim().lowercase(Locale.ROOT)}|$name")
    }

    // ---------------------------------------------------------------- survivor (AC2)

    fun hasRealImage(item: InventoryItem): Boolean {
        val url = item.imageUrl?.trim().orEmpty()
        return url.isNotEmpty() && !url.contains("placehold.co/")
    }

    fun parseTime(value: String?): Instant? {
        if (value.isNullOrBlank()) return null
        return runCatching { OffsetDateTime.parse(value).toInstant() }.getOrNull()
            ?: runCatching { LocalDateTime.parse(value).toInstant(ZoneOffset.UTC) }.getOrNull()
    }

    private fun updatedTime(item: InventoryItem): Instant = parseTime(item.updatedAt) ?: Instant.EPOCH

    fun imageTime(item: InventoryItem): Instant? = parseTime(item.imageUpdatedAt) ?: parseTime(item.updatedAt)

    fun pickSurvivor(items: List<InventoryItem>): InventoryItem? {
        val withImage = items.filter(::hasRealImage)
        if (withImage.isNotEmpty()) {
            return withImage.maxWithOrNull(
                compareBy<InventoryItem> { imageTime(it) ?: Instant.EPOCH }.thenBy { updatedTime(it) }.thenBy { it.id },
            )
        }
        return items.maxWithOrNull(compareBy<InventoryItem> { updatedTime(it) }.thenBy { it.id })
    }

    // ---------------------------------------------------------------- groups (AC1)

    fun findGroups(items: List<InventoryItem>): List<DuplicateGroup> {
        val parent = IntArray(items.size) { it }
        fun root(index: Int): Int {
            var current = index
            while (parent[current] != current) {
                parent[current] = parent[parent[current]]
                current = parent[current]
            }
            return current
        }

        val firstByKey = HashMap<String, Int>()
        val links = mutableListOf<Pair<DuplicateReason, Int>>()
        items.forEachIndexed { index, item ->
            keys(item).forEach { (reason, value) ->
                val key = "${reason.name}#$value"
                val first = firstByKey[key]
                if (first == null) {
                    firstByKey[key] = index
                } else {
                    parent[root(index)] = root(first)
                    links += reason to first
                }
            }
        }

        return items.indices
            .groupBy(::root)
            .filterValues { it.size > 1 }
            .mapNotNull { (groupRoot, indexes) ->
                val reason = links.filter { root(it.second) == groupRoot }.minOfOrNull { it.first } ?: DuplicateReason.SameName
                val groupItems = indexes.map { items[it] }.sortedByDescending { updatedTime(it) }
                pickSurvivor(groupItems)?.let { DuplicateGroup(reason, it.id, groupItems) }
            }
            .sortedWith(compareBy<DuplicateGroup> { it.reason }.thenBy { dedupeName(it.items.first().name) })
    }

    /** True when [items] are exactly one duplicate group (REQ-INV-021 AC4). */
    fun isOneGroup(items: List<InventoryItem>): Boolean =
        items.size >= 2 && findGroups(items).singleOrNull()?.items?.size == items.size

    // ---------------------------------------------------------------- merge (AC3)

    /**
     * The survivor after a merge: higher quantity and threshold (not a sum), and barcode,
     * product and price filled from the most recently updated other item.
     */
    fun merged(group: DuplicateGroup): InventoryItem? {
        val survivor = group.survivor ?: return null
        val newestFirst = group.others.sortedByDescending { updatedTime(it) }
        return survivor.copy(
            quantity = group.items.maxOf { it.quantity },
            lowStockThreshold = group.items.maxOf { it.lowStockThreshold },
            barcode = survivor.barcode?.takeIf { it.isNotBlank() } ?: newestFirst.firstNotNullOfOrNull { it.barcode?.takeIf(String::isNotBlank) },
            productId = survivor.productId?.takeIf { it.isNotBlank() } ?: newestFirst.firstNotNullOfOrNull { it.productId?.takeIf(String::isNotBlank) },
            pricePaid = survivor.pricePaid ?: newestFirst.firstNotNullOfOrNull { it.pricePaid },
        )
    }

    // ---------------------------------------------------------------- copy (AC5)

    fun headline(groupCount: Int): String =
        if (groupCount == 1) "1 group found · review before merging" else "$groupCount groups found · review before merging"

    /** "keeps qty 3 (higher) · newest photo", shown after "Merges into {name}". */
    fun resultDetail(group: DuplicateGroup): String {
        val parts = mutableListOf("keeps qty ${group.items.maxOf { it.quantity }} (higher)")
        if (group.survivor?.let(::hasRealImage) == true) parts += "newest photo"
        return parts.joinToString(" · ")
    }

    fun photoAge(item: InventoryItem, now: Instant = Instant.now(), zone: ZoneId = ZoneId.systemDefault()): String {
        if (!hasRealImage(item)) return "No photo"
        val changed = imageTime(item) ?: return "Has a photo"
        val days = ChronoUnit.DAYS.between(changed.atZone(zone).toLocalDate(), now.atZone(zone).toLocalDate())
        return when {
            days < 1 -> "Photo updated today"
            days == 1L -> "Photo updated yesterday"
            else -> "Photo updated $days days ago"
        }
    }

    fun confirmation(count: Int, name: String): String = "Merged $count items into $name"

    /** "Merge all": one group reads like a single merge; several name the item count. */
    fun bulkConfirmation(merged: List<DuplicateGroup>): String? {
        val first = merged.firstOrNull() ?: return null
        val count = merged.sumOf { it.items.size }
        val name = if (merged.size == 1) first.survivor?.name ?: first.items.first().name else "${merged.size} items"
        return confirmation(count, name)
    }
}

/** "Not duplicates" choices, per device and household, until the items change (REQ-INV-021 AC5). */
class DismissedDuplicates(private val prefs: SharedPreferences, householdId: String?) {
    private val key = "dismissed.${householdId ?: "local"}"

    private fun saved(): Set<String> = prefs.getStringSet(key, emptySet()).orEmpty()

    fun contains(group: DuplicateGroup): Boolean = group.signature in saved()

    fun dismiss(group: DuplicateGroup) {
        prefs.edit().putStringSet(key, (saved() + group.signature).toList().takeLast(MAX_SAVED).toSet()).apply()
    }

    fun visible(groups: List<DuplicateGroup>): List<DuplicateGroup> = groups.filterNot(::contains)

    companion object {
        const val PREFS = "mekasa_fable_duplicates"
        private const val MAX_SAVED = 200
    }
}
