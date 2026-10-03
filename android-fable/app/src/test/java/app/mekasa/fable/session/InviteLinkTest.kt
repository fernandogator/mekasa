package app.mekasa.fable.session

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class InviteLinkTest {

    @Test
    fun `query token`() {
        assertEquals("abc123", InviteLink.tokenFrom("mekasa://invite?token=abc123"))
    }

    @Test
    fun `query token among other params and mixed case scheme`() {
        assertEquals("t-9", InviteLink.tokenFrom("MEKASA://invite?utm=x&token=t-9"))
    }

    @Test
    fun `path token`() {
        assertEquals("path-token", InviteLink.tokenFrom("mekasa://invite/path-token"))
    }

    @Test
    fun `url encoded token is decoded`() {
        assertEquals("a b", InviteLink.tokenFrom("mekasa://invite?token=a%20b"))
    }

    @Test
    fun `other hosts and schemes are rejected`() {
        assertNull(InviteLink.tokenFrom("https://mekasa.app/invite?token=x"))
        assertNull(InviteLink.tokenFrom("mekasa://something?token=x"))
        assertNull(InviteLink.tokenFrom(null))
        assertNull(InviteLink.tokenFrom("mekasa://invite"))
    }
}
