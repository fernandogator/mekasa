package app.mekasa.fable.ui

import app.mekasa.fable.ui.inventory.ItemPager
import app.mekasa.fable.ui.inventory.ItemPager.Step
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Satisfies: REQ-INV-020 (Swipe Between Items in Item Detail) AC1, AC2, AC3, AC4, AC6
 * Spec version: 1.0
 */
class ItemPagerTest {
    private val pager = ItemPager(listOf("a", "b", "c"))

    @Test
    fun neighborsFollowListOrderWithoutWrapping() {
        assertEquals("b", pager.neighbor("a", Step.NEXT))
        assertEquals("a", pager.neighbor("b", Step.PREVIOUS))
        assertNull(pager.neighbor("a", Step.PREVIOUS))
        assertNull(pager.neighbor("c", Step.NEXT))
        assertNull(pager.neighbor("missing", Step.NEXT))
    }

    @Test
    fun positionLabelCountsFromOne() {
        assertEquals("1 of 3", pager.positionLabel("a"))
        assertEquals("3 of 3", pager.positionLabel("c"))
        assertNull(pager.positionLabel("missing"))
    }

    @Test
    fun singleOrEmptyListDisablesPaging() {
        assertFalse(ItemPager().isActive)
        assertFalse(ItemPager(listOf("a")).isActive)
        assertNull(ItemPager(listOf("a")).positionLabel("a"))
        assertNull(ItemPager(listOf("a")).neighbor("a", Step.NEXT))
        assertTrue(pager.isActive)
    }

    @Test
    fun keepingSkipsRemovedItems() {
        val pruned = pager.keeping(setOf("a", "c"))
        assertEquals("c", pruned.neighbor("a", Step.NEXT))
        assertEquals("2 of 2", pruned.positionLabel("c"))
    }

    @Test
    fun swipeDirectionMapsToStep() {
        assertEquals(Step.NEXT, ItemPager.step(dx = -80f, dy = 10f, minDistancePx = 60f))
        assertEquals(Step.PREVIOUS, ItemPager.step(dx = 80f, dy = -10f, minDistancePx = 60f))
    }

    @Test
    fun shortOrDiagonalSwipesAreIgnored() {
        assertNull(ItemPager.step(dx = -40f, dy = 0f, minDistancePx = 60f))
        assertNull(ItemPager.step(dx = -80f, dy = 70f, minDistancePx = 60f))
    }
}
