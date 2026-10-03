package app.mekasa.fable.voice

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class VoicePhraseParserTest {

    private fun parse(phrase: String) = VoicePhraseParser.parse(phrase) ?: error("expected a parse for '$phrase'")

    @Test
    fun `plain item defaults to quantity one`() {
        val parsed = parse("milk")
        assertEquals(1, parsed.quantity)
        assertEquals("milk", parsed.query)
        assertEquals("Milk", parsed.displayName)
    }

    @Test
    fun `leading digit sets quantity`() {
        val parsed = parse("3 avocados")
        assertEquals(3, parsed.quantity)
        assertEquals("avocados", parsed.query)
    }

    @Test
    fun `number words and packaging fillers are stripped`() {
        val parsed = parse("two gallons of whole milk")
        assertEquals(2, parsed.quantity)
        assertEquals("whole milk", parsed.query)
        assertEquals("Whole Milk", parsed.displayName)
    }

    @Test
    fun `leading verbs are ignored`() {
        val parsed = parse("add three cans of black beans")
        assertEquals(3, parsed.quantity)
        assertEquals("black beans", parsed.query)
    }

    @Test
    fun `we need phrasing`() {
        val parsed = parse("we need a dozen eggs")
        assertEquals(12, parsed.quantity)
        assertEquals("eggs", parsed.query)
    }

    @Test
    fun `trailing x quantity`() {
        val parsed = parse("paper towels x4")
        assertEquals(4, parsed.quantity)
        assertEquals("paper towels", parsed.query)
    }

    @Test
    fun `trailing comma quantity`() {
        val parsed = parse("Diet Coke, 6")
        assertEquals(6, parsed.quantity)
        assertEquals("Diet Coke", parsed.query)
    }

    @Test
    fun `article without a number keeps quantity one`() {
        val parsed = parse("a bottle of olive oil")
        assertEquals(1, parsed.quantity)
        assertEquals("olive oil", parsed.query)
    }

    @Test
    fun `punctuation and whitespace are normalised`() {
        val parsed = parse("  Buy   two   loaves of  sourdough!  ")
        assertEquals(2, parsed.quantity)
        assertEquals("sourdough", parsed.query)
    }

    @Test
    fun `quantity is clamped to a sane range`() {
        assertEquals(999, parse("1000 napkins").quantity)
    }

    @Test
    fun `phrase with nothing left returns null`() {
        assertNull(VoicePhraseParser.parse("add two"))
        assertNull(VoicePhraseParser.parse(""))
        assertNull(VoicePhraseParser.parse("   "))
    }

    @Test
    fun `a bare number is not an item`() {
        assertNull(VoicePhraseParser.parse("5"))
    }
}
