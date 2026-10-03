package app.mekasa.fable.session

import app.mekasa.fable.data.model.Household
import app.mekasa.fable.data.model.HouseholdMember
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StageTest {

    private val base = Household(id = "h", ownerUid = "owner")

    @Test
    fun `no household means name it first`() {
        assertEquals(Stage.NameHousehold, Stage.forHousehold(null))
    }

    @Test
    fun `household without address goes to address step`() {
        assertEquals(Stage.ConfirmAddress, Stage.forHousehold(base))
        assertEquals(Stage.ConfirmAddress, Stage.forHousehold(base.copy(address = "  ")))
    }

    @Test
    fun `address but no stores goes to store picker`() {
        assertEquals(Stage.PickStores, Stage.forHousehold(base.copy(address = "1 Main")))
    }

    @Test
    fun `fully onboarded lands on home`() {
        assertEquals(Stage.Home, Stage.forHousehold(base.copy(address = "1 Main", storeIds = listOf("s"))))
    }

    @Test
    fun `progress increases monotonically`() {
        val values = Stage.entries.map { it.progress }
        assertEquals(values.sorted(), values)
        assertTrue(Stage.ConfirmAddress.isOnboarding)
        assertFalse(Stage.Home.isOnboarding)
    }

    @Test
    fun `owner is derived from household record or member role`() {
        val account = Account(uid = "me", email = null, displayName = null)
        val byRecord = SessionState(stage = Stage.Home, account = account, household = base.copy(ownerUid = "me"))
        assertTrue(byRecord.isOwner)
        assertTrue(byRecord.canMarkPurchased)

        val member = SessionState(stage = Stage.Home, account = account, household = base)
        assertFalse(member.isOwner)
        assertFalse(member.canMarkPurchased)

        val promoted = member.copy(
            data = HouseholdData(members = listOf(HouseholdMember(uid = "me", householdId = "h", role = "owner"))),
        )
        assertTrue(promoted.isOwner)

        val buyer = member.copy(
            data = HouseholdData(members = listOf(HouseholdMember(uid = "me", householdId = "h", permissions = listOf("buyer")))),
        )
        assertFalse(buyer.isOwner)
        assertTrue(buyer.canMarkPurchased)
    }
}
