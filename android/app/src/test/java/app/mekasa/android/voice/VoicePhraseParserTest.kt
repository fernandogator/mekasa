package app.mekasa.android.voice

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class VoicePhraseParserTest {
    @Test
    fun parse_twoAvocados() {
        val result = VoicePhraseParser.parse("two avocados")!!
        assertEquals(2, result.quantity)
        assertEquals("avocados", result.productQuery)
        assertEquals("Avocados", result.displayName)
    }

    @Test
    fun parse_bareName_defaultsQtyOne() {
        val result = VoicePhraseParser.parse("Oreos")!!
        assertEquals(1, result.quantity)
        assertEquals("Oreos", result.productQuery)
    }

    @Test
    fun parse_packsOfFiller() {
        val result = VoicePhraseParser.parse("three packs of oat milk")!!
        assertEquals(3, result.quantity)
        assertEquals("oat milk", result.productQuery)
    }

    @Test
    fun parse_digitQuantity() {
        val result = VoicePhraseParser.parse("4 bananas!")!!
        assertEquals(4, result.quantity)
        assertEquals("bananas", result.productQuery)
    }

    @Test
    fun parse_emptyOrQuantityOnly_returnsNull() {
        assertNull(VoicePhraseParser.parse("   "))
        assertNull(VoicePhraseParser.parse("two"))
    }
}
