package app.mekasa.fable.ui.components

import org.junit.Assert.assertEquals
import org.junit.Test

class FormatTest {

    @Test
    fun `money uses currency symbol and grouping`() {
        assertEquals("$1,234.50", money(1234.5))
        assertEquals("€3.00", money(3.0, "EUR"))
        assertEquals("CAD 3.00", money(3.0, "CAD"))
    }

    @Test
    fun `compact money drops cents above a thousand`() {
        assertEquals("$1,235", moneyCompact(1234.6))
        assertEquals("$12.34", moneyCompact(12.34))
    }

    @Test
    fun `plural picks the right form`() {
        assertEquals("1 item", plural(1, "item"))
        assertEquals("0 items", plural(0, "item"))
        assertEquals("2 loaves", plural(2, "loaf", "loaves"))
    }

    @Test
    fun `miles has one decimal`() {
        assertEquals("0.8 mi", miles(0.84))
    }
}
