package app.mekasa.fable.session

import app.mekasa.fable.data.InventoryDraft
import app.mekasa.fable.data.demo.DemoBackend
import app.mekasa.fable.data.model.Household
import app.mekasa.fable.data.model.HouseholdMember
import app.mekasa.fable.data.model.InventoryItem
import app.mekasa.fable.data.remote.ApiException
import app.mekasa.fable.support.FakeApi
import app.mekasa.fable.support.FakeAuthGateway
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SessionViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private val api = FakeApi()
    private val auth = FakeAuthGateway()
    private val memory = InMemoryEmailMemory()

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun viewModel(allowTestToken: Boolean = false) =
        SessionViewModel(api = api, auth = auth, emailMemory = memory, allowTestTokenSignIn = allowTestToken)

    private val SessionViewModel.s: SessionState get() = state.value

    // ------------------------------------------------------------ welcome

    @Test
    fun `starts signed out and reflects firebase availability`() {
        val vm = viewModel()
        assertEquals(Stage.SignedOut, vm.s.stage)
        assertTrue(vm.s.firebaseConfigured)
        assertFalse(vm.s.isSignedIn)
    }

    @Test
    fun `offline preview lands on home with demo data`() {
        val vm = viewModel()
        vm.browseOffline()

        assertEquals(Stage.Home, vm.s.stage)
        assertTrue(vm.s.isDemo)
        assertTrue(vm.s.isOwner)
        assertEquals("The Guerrero Home", vm.s.household?.name)
        assertEquals(4, vm.s.data.inventory.size)
        assertEquals(2, vm.s.data.shopping.size)
        assertTrue(api.calls.isEmpty())
    }

    @Test
    fun `email sign in loads profile and routes to home when onboarded`() {
        val vm = viewModel()
        vm.signInWithEmail("ana@example.com", "secret", createAccount = false)

        assertEquals(Stage.Home, vm.s.stage)
        assertEquals("ana@example.com", vm.s.account?.email)
        assertEquals("hh-1", vm.s.household?.id)
        assertEquals(1, vm.s.data.inventory.size)
        assertEquals("ana@example.com", memory.load())
        assertTrue(api.calls.any { it == "currentHousehold:token-1" })
    }

    @Test
    fun `sign in without a household starts onboarding`() {
        api.household = null
        val vm = viewModel()
        vm.signInWithEmail("ana@example.com", "secret", createAccount = true)

        assertEquals(Stage.NameHousehold, vm.s.stage)
        assertNull(vm.s.household)
    }

    @Test
    fun `onboarding walks name, address, stores, home`() {
        api.household = null
        val vm = viewModel()
        vm.signInWithEmail("ana@example.com", "secret", createAccount = true)

        vm.createHousehold("Casa Ana")
        assertEquals(Stage.ConfirmAddress, vm.s.stage)
        assertEquals("Casa Ana", vm.s.household?.name)

        vm.saveAddress("42 Elm St")
        assertEquals(Stage.PickStores, vm.s.stage)

        vm.toggleStore("kroger")
        assertEquals(setOf("kroger"), vm.s.selectedStoreIds)
        vm.finishStoreSelection()
        assertEquals(Stage.Home, vm.s.stage)
        assertEquals(listOf("kroger"), vm.s.household?.storeIds)
    }

    @Test
    fun `test token sign in is refused unless enabled`() {
        val vm = viewModel(allowTestToken = false)
        vm.signInWithTestToken("dev@example.com")
        assertEquals(Stage.SignedOut, vm.s.stage)
        assertNotNull(vm.s.error)

        val debug = viewModel(allowTestToken = true)
        debug.signInWithTestToken("dev@example.com")
        assertEquals(Stage.Home, debug.s.stage)
        assertTrue(api.calls.any { it.startsWith("currentHousehold:test:fable-") })
    }

    // ---------------------------------------------------------- sign out

    @Test
    fun `sign out remembers the email and clears data`() {
        val vm = viewModel()
        vm.signInWithEmail("ana@example.com", "secret", createAccount = false)
        vm.signOut()

        assertEquals(Stage.SignedOut, vm.s.stage)
        assertEquals("ana@example.com", vm.s.rememberedEmail)
        assertNull(vm.s.household)
        assertTrue(vm.s.data.inventory.isEmpty())
        assertEquals(1, auth.signOutCalls)
    }

    @Test
    fun `demo sign out does not remember the preview address`() {
        val vm = viewModel()
        vm.browseOffline()
        vm.signOut()
        assertNull(vm.s.rememberedEmail)
    }

    @Test
    fun `401 after a failed refresh ends the session with a notice`() {
        val vm = viewModel()
        vm.signInWithEmail("ana@example.com", "secret", createAccount = false)

        api.failWith = ApiException(401, "invalid_token")
        auth.refreshedToken = null
        vm.consume("i1")

        assertEquals(Stage.SignedOut, vm.s.stage)
        assertEquals(SessionViewModel.SESSION_EXPIRED, vm.s.notice)
        assertEquals("ana@example.com", vm.s.rememberedEmail)
        assertEquals(1, auth.refreshCalls)
    }

    @Test
    fun `401 with a fresh token retries transparently`() {
        val vm = viewModel()
        vm.signInWithEmail("ana@example.com", "secret", createAccount = false)

        api.failWith = ApiException(401, "expired")
        auth.refreshedToken = "token-2"
        vm.consume("i1")

        assertEquals(Stage.Home, vm.s.stage)
        assertNull(vm.s.notice)
        assertEquals(1, vm.s.data.inventory.first().quantity)
        assertEquals(2, api.calls.count { it == "consume:i1:1" })
    }

    @Test
    fun `firebase auth state dropping to false signs out`() = runTest(dispatcher) {
        val vm = viewModel()
        vm.signInWithEmail("ana@example.com", "secret", createAccount = false)
        auth.authEvents.emit(false)

        assertEquals(Stage.SignedOut, vm.s.stage)
        assertEquals(SessionViewModel.SESSION_EXPIRED, vm.s.notice)
    }

    // ---------------------------------------------------------- inventory

    @Test
    fun `consume decrements and logs a scan event`() {
        val vm = viewModel()
        vm.browseOffline()
        val coke = vm.s.data.inventory.first { it.name == "Diet Coke" }

        vm.consume(coke.id)
        assertEquals(1, vm.s.data.inventory.first { it.id == coke.id }.quantity)
        assertEquals(ScanEvent.Tone.Used, vm.s.data.scanFeed.first().tone)

        vm.consume(coke.id)
        assertEquals(0, vm.s.data.inventory.first { it.id == coke.id }.quantity)
        assertEquals(ScanEvent.Tone.Depleted, vm.s.data.scanFeed.first().tone)

        vm.consume(coke.id)
        assertEquals(0, vm.s.data.inventory.first { it.id == coke.id }.quantity)
    }

    @Test
    fun `barcode consume reports outcomes and records unknown codes`() {
        val vm = viewModel()
        vm.browseOffline()
        val outcomes = mutableListOf<ConsumeOutcome>()

        vm.consumeByBarcode(DemoBackend.DIET_COKE_UPC) { outcomes += it }
        assertTrue(outcomes.last() is ConsumeOutcome.Used)

        vm.consumeByBarcode("000000000000") { outcomes += it }
        assertTrue(outcomes.last() is ConsumeOutcome.Unknown)
        assertEquals("000000000000", vm.s.data.unknownScans.single().barcode)
        assertEquals(ScanEvent.Tone.Unknown, vm.s.data.scanFeed.first().tone)

        vm.consumeByBarcode("   ") { outcomes += it }
        assertTrue(outcomes.last() is ConsumeOutcome.Failed)
    }

    @Test
    fun `remove hides the row, soft deletes, and purges after the undo window`() = runTest(dispatcher) {
        val vm = SessionViewModel(api = api, auth = auth, emailMemory = memory, undoWindowMillis = 5_000)
        vm.signInWithEmail("ana@example.com", "secret", createAccount = false)

        vm.removeInventoryItem("i1")
        assertTrue(vm.s.data.inventory.isEmpty())
        assertEquals("i1", vm.s.pendingRemoval?.item?.id)
        assertTrue(api.calls.contains("deleteInventory:i1"))
        assertFalse(api.calls.contains("purgeInventory:i1"))

        advanceTimeBy(5_001)
        assertNull(vm.s.pendingRemoval)
        assertTrue(api.calls.contains("purgeInventory:i1"))
        assertTrue(api.inventory.isEmpty())
    }

    @Test
    fun `undo within the window restores the row at its original index`() = runTest(dispatcher) {
        api.inventory += InventoryItem(id = "i2", householdId = "hh-1", name = "Eggs", quantity = 1, lowStockThreshold = 1)
        val vm = SessionViewModel(api = api, auth = auth, emailMemory = memory, undoWindowMillis = 5_000)
        vm.signInWithEmail("ana@example.com", "secret", createAccount = false)

        vm.removeInventoryItem("i1")
        assertEquals(listOf("i2"), vm.s.data.inventory.map { it.id })

        vm.undoInventoryRemove()
        assertEquals(listOf("i1", "i2"), vm.s.data.inventory.map { it.id })
        assertNull(vm.s.pendingRemoval)
        assertTrue(api.calls.contains("restoreInventory:i1"))

        advanceTimeBy(6_000)
        assertFalse(api.calls.contains("purgeInventory:i1"))
    }

    @Test
    fun `add inventory upserts and marks source`() {
        val vm = viewModel()
        vm.signInWithEmail("ana@example.com", "secret", createAccount = false)
        var done = false
        vm.addInventory(InventoryDraft(name = "Oat Milk", quantity = 2, source = "voice")) { done = true }

        assertTrue(done)
        assertEquals("Oat Milk", vm.s.data.inventory.first().name)
        assertTrue(api.calls.contains("createInventory:Oat Milk:voice"))
    }

    @Test
    fun `update inventory patches quantity and threshold`() {
        val vm = viewModel()
        vm.signInWithEmail("ana@example.com", "secret", createAccount = false)
        vm.updateInventory("i1", quantity = 7, threshold = 3)

        val item = vm.s.data.inventory.single()
        assertEquals(7, item.quantity)
        assertEquals(3, item.lowStockThreshold)
        assertTrue(api.calls.contains("patchInventory:i1:7:3"))
    }

    // ------------------------------------------------------------ shopping

    @Test
    fun `owner can mark purchased`() {
        val vm = viewModel()
        vm.signInWithEmail("ana@example.com", "secret", createAccount = false)
        vm.toggleShoppingPurchased("s1")

        assertTrue(vm.s.data.shopping.single().isChecked)
        assertNull(vm.s.error)
    }

    @Test
    fun `member without buyer permission is blocked from marking purchased`() {
        api.household = api.household!!.copy(ownerUid = "someone-else")
        api.members = mutableListOf(HouseholdMember(uid = "uid-1", householdId = "hh-1", role = "member"))
        val vm = viewModel()
        vm.signInWithEmail("ana@example.com", "secret", createAccount = false)
        assertFalse(vm.s.canMarkPurchased)

        vm.toggleShoppingPurchased("s1")

        assertFalse(vm.s.data.shopping.single().isChecked)
        assertEquals(SessionViewModel.OWNER_ONLY_PURCHASE, vm.s.error)
        assertTrue(api.calls.none { it.startsWith("patchShopping") })
    }

    @Test
    fun `buyer permission unlocks purchasing for a member`() {
        api.household = api.household!!.copy(ownerUid = "someone-else")
        api.members = mutableListOf(
            HouseholdMember(uid = "uid-1", householdId = "hh-1", role = "member", permissions = listOf("buyer")),
        )
        val vm = viewModel()
        vm.signInWithEmail("ana@example.com", "secret", createAccount = false)
        vm.toggleShoppingPurchased("s1")
        assertTrue(vm.s.data.shopping.single().isChecked)
    }

    @Test
    fun `add and remove shopping items`() {
        val vm = viewModel()
        vm.browseOffline()
        val before = vm.s.data.shopping.size

        vm.addShoppingItem("  Lemons ", 4)
        assertEquals(before + 1, vm.s.data.shopping.size)
        assertEquals("Lemons", vm.s.data.shopping.first().name)

        vm.addShoppingItem("   ")
        assertEquals(before + 1, vm.s.data.shopping.size)

        vm.removeShoppingItem(vm.s.data.shopping.first().id)
        assertEquals(before, vm.s.data.shopping.size)
    }

    // -------------------------------------------------------------- photo

    @Test
    fun `only the owner may change the home photo`() {
        api.household = api.household!!.copy(ownerUid = "someone-else")
        api.members = mutableListOf(HouseholdMember(uid = "uid-1", householdId = "hh-1", role = "member"))
        val vm = viewModel()
        vm.signInWithEmail("ana@example.com", "secret", createAccount = false)

        var result: Boolean? = null
        vm.saveHomeDetails(name = null, jpeg = byteArrayOf(1)) { result = it }
        assertEquals(false, result)
        assertEquals(SessionViewModel.OWNER_ONLY_PHOTO, vm.s.error)
        assertTrue(api.calls.none { it.startsWith("uploadPhoto") })
    }

    @Test
    fun `owner photo upload updates the household`() {
        val vm = viewModel()
        vm.signInWithEmail("ana@example.com", "secret", createAccount = false)

        var result: Boolean? = null
        vm.saveHomeDetails(name = "Renamed", jpeg = byteArrayOf(1, 2)) { result = it }
        assertEquals(true, result)
        assertEquals("https://cdn/photo.jpg", vm.s.household?.photoUrl)
        assertTrue(api.calls.contains("renameHousehold"))
        assertTrue(api.calls.contains("uploadPhoto:2"))
    }

    // ------------------------------------------------------------ spending

    @Test
    fun `selecting a period refetches spending`() {
        val vm = viewModel()
        vm.signInWithEmail("ana@example.com", "secret", createAccount = false)
        vm.selectSpendingPeriod("year")
        assertEquals("year", vm.s.data.spendingPeriod)
        assertEquals("year", vm.s.data.spending?.period)
        assertTrue(api.calls.contains("spending:year"))
    }

    // -------------------------------------------------------------- invites

    @Test
    fun `invite link is held until sign in then accepted`() {
        val vm = viewModel()
        vm.onInviteLink("mekasa://invite?token=abc")
        assertEquals("abc", vm.s.pendingInviteToken)
        assertTrue(api.calls.none { it.startsWith("acceptInvite") })

        vm.signInWithEmail("ana@example.com", "secret", createAccount = false)
        assertNull(vm.s.pendingInviteToken)
        assertTrue(api.calls.contains("acceptInvite:abc"))
        assertEquals(Stage.Home, vm.s.stage)
    }

    @Test
    fun `restore resumes a cached firebase user`() {
        auth.currentUid = "uid-1"
        val vm = viewModel()
        assertEquals(Stage.Home, vm.s.stage)
        assertEquals("hh-1", vm.s.household?.id)
    }

    @Test
    fun `stage for household mirrors onboarding rules`() {
        val base = Household(id = "h", ownerUid = "o")
        assertEquals(Stage.NameHousehold, Stage.forHousehold(null))
        assertEquals(Stage.ConfirmAddress, Stage.forHousehold(base))
        assertEquals(Stage.PickStores, Stage.forHousehold(base.copy(address = "x")))
        assertEquals(Stage.Home, Stage.forHousehold(base.copy(address = "x", storeIds = listOf("s"))))
    }
}
