package app.mekasa.fable.ui.inventory

import kotlin.math.abs

/**
 * Previous / next item within the list an item detail was opened from.
 *
 * Satisfies: REQ-INV-020 (Swipe Between Items in Item Detail) AC1, AC2, AC3, AC4, AC6
 * Spec version: 1.0
 */
data class ItemPager(val ids: List<String> = emptyList()) {
    enum class Step(val delta: Int) { PREVIOUS(-1), NEXT(1) }

    /** Paging only makes sense with a list of at least two items (AC6). */
    val isActive: Boolean get() = ids.size > 1

    fun neighbor(id: String, step: Step): String? {
        if (!isActive) return null
        val index = ids.indexOf(id)
        if (index < 0) return null
        return ids.getOrNull(index + step.delta)
    }

    /** "3 of 24"; null when paging is off or the item is not in the list. */
    fun positionLabel(id: String): String? {
        if (!isActive) return null
        val index = ids.indexOf(id)
        return if (index < 0) null else "${index + 1} of ${ids.size}"
    }

    /** Drops items that no longer exist (removed while the detail is open, AC1). */
    fun keeping(existing: Set<String>): ItemPager = ItemPager(ids.filter { it in existing })

    companion object {
        /** Left swipe → next, right swipe → previous; null for short or mostly vertical drags (AC2). */
        fun step(dx: Float, dy: Float, minDistancePx: Float): Step? {
            if (abs(dx) < minDistancePx || abs(dx) <= abs(dy) * 1.5f) return null
            return if (dx < 0) Step.NEXT else Step.PREVIOUS
        }
    }
}
