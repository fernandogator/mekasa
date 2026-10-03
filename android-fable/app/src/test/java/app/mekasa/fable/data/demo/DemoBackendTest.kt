package app.mekasa.fable.data.demo

import app.mekasa.fable.data.InventoryDraft
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DemoBackendTest {

    private val backend = DemoBackend()
    private val id = DemoBackend.HOUSEHOLD_ID

    @Test
    fun `seeded household is fully onboarded`() = runTest {
        val household = backend.currentHousehold()
        assertNotNull(household)
        assertTrue(household!!.hasAddress)
        assertTrue(household.hasStores)
        assertEquals(DemoBackend.DEMO_UID, household.ownerUid)
        assertEquals(4, backend.inventory(id).size)
    }

    @Test
    fun `consume never goes below zero`() = runTest {
        val milk = backend.inventory(id).first { it.name == "Whole Milk" }
        assertEquals(1, milk.quantity)
        val once = backend.consume(id, milk.id, 1)
        assertEquals(0, once.quantity)
        val twice = backend.consume(id, milk.id, 1)
        assertEquals(0, twice.quantity)
    }

    @Test
    fun `barcode consume finds stocked item and logs unknown codes`() = runTest {
        val hit = backend.consumeByBarcode(id, DemoBackend.DIET_COKE_UPC, 1)
        assertTrue(hit.found)
        assertEquals(1, hit.item?.quantity)
        assertNull(hit.unknownEvent)

        val miss = backend.consumeByBarcode(id, "000000000000", 1)
        assertFalse(miss.found)
        assertNotNull(miss.unknownEvent)
        assertEquals("000000000000", backend.unknownScans(id).single().barcode)
    }

    @Test
    fun `depleted items are not matched by barcode again`() = runTest {
        backend.consumeByBarcode(id, DemoBackend.DIET_COKE_UPC, 2)
        val again = backend.consumeByBarcode(id, DemoBackend.DIET_COKE_UPC, 1)
        assertFalse(again.found)
    }

    @Test
    fun `adding inventory prepends and keeps draft fields`() = runTest {
        val created = backend.addInventory(
            id,
            InventoryDraft(name = "Oat Milk", category = "Dairy", quantity = 2, barcode = "123", source = "voice", pricePaid = 4.5),
        )
        assertEquals("Oat Milk", created.name)
        assertEquals("voice", created.source)
        assertEquals(4.5, created.pricePaid)
        assertEquals(created.id, backend.inventory(id).first().id)
    }

    @Test
    fun `sync from inventory adds low stock items once`() = runTest {
        val before = backend.shoppingList(id)
        val synced = backend.syncShoppingFromInventory(id)
        val autoNames = synced.filter { it.kind == "auto" }.map { it.name }
        assertTrue(autoNames.contains("Diet Coke"))
        assertTrue(autoNames.contains("Whole Milk"))
        assertEquals(1, autoNames.count { it == "Diet Coke" })
        assertTrue(synced.size > before.size)

        val second = backend.syncShoppingFromInventory(id)
        assertEquals(synced.size, second.size)
    }

    @Test
    fun `approve and reject requests`() = runTest {
        val request = backend.shoppingList(id).first { it.needsApproval }
        val approved = backend.approveShoppingItem(id, request.id)
        assertFalse(approved.needsApproval)

        backend.rejectShoppingItem(id, approved.id)
        assertTrue(backend.shoppingList(id).none { it.id == request.id })
    }

    @Test
    fun `photo upload becomes a data url`() = runTest {
        val household = backend.uploadHomePhoto(id, byteArrayOf(0xFF.toByte(), 0xD8.toByte()))
        assertTrue(household.photoUrl!!.startsWith("data:image/jpeg;base64,"))
    }

    @Test
    fun `spending scales by period`() = runTest {
        val week = backend.spending(id, "week").total
        val month = backend.spending(id, "month").total
        val year = backend.spending(id, "year").total
        assertTrue(week < month && month < year)
        assertEquals(3, backend.spending(id, "week").byCategory.size)
    }

    @Test
    fun `catalog lookup and search`() = runTest {
        val found = backend.lookupBarcode(DemoBackend.DIET_COKE_UPC)
        assertTrue(found.found)
        assertEquals("Diet Coke", found.name)

        val missing = backend.lookupBarcode("999")
        assertFalse(missing.found)

        assertTrue(backend.searchProducts("coke").any { it.name == "Diet Coke" })
        assertTrue(backend.searchProducts("").isEmpty())
    }

    @Test
    fun `invites and role changes`() = runTest {
        val invite = backend.createInvite(id, "Grandma", "g@example.com", "member")
        assertTrue(invite.shareLink.startsWith("mekasa://invite?token="))
        assertEquals(invite.id, backend.invites(id).first().id)

        val promoted = backend.updateMemberRole(id, "demo-kid", "owner")
        assertTrue(promoted.isOwner)
    }

    @Test
    fun `receipt scan returns the sample haul`() = runTest {
        val scan = backend.scanReceipt(id, DemoBackend.DEMO_RECEIPT_TEXT, null)
        assertEquals(3, scan.items.size)
        assertEquals(1, scan.items.count { !it.identified })
    }
}
