package app.mekasa.fable.ui.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.PieChart
import androidx.compose.material.icons.filled.ShoppingBag
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.People
import androidx.compose.material.icons.outlined.PieChart
import androidx.compose.material.icons.outlined.ShoppingBag
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import app.mekasa.fable.session.SessionState
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.ui.TestTags
import app.mekasa.fable.ui.additems.AddItemsSheet
import app.mekasa.fable.ui.components.Backdrop
import app.mekasa.fable.ui.dashboard.DashboardScreen
import app.mekasa.fable.ui.dashboard.HomePhotoScreen
import app.mekasa.fable.ui.family.FamilyScreen
import app.mekasa.fable.ui.inventory.InventoryScreen
import app.mekasa.fable.ui.inventory.ItemDetailScreen
import app.mekasa.fable.ui.shopping.ShoppingListScreen
import app.mekasa.fable.ui.spending.SpendingScreen
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Shapes
import app.mekasa.fable.ui.theme.Space
import app.mekasa.fable.ui.trash.TrashStationScreen

/** Navigation routes inside the signed-in shell. */
object Routes {
    const val DASHBOARD = "dashboard"
    const val LIST = "list"
    const val SPEND = "spend"
    const val FAMILY = "family"
    const val INVENTORY = "inventory"
    const val HOME_PHOTO = "home-photo"
    const val TRASH = "trash"
    const val ITEM = "item/{itemId}"

    fun item(id: String) = "item/$id"

    val tabs = listOf(DASHBOARD, LIST, SPEND, FAMILY)
}

enum class HomeTab(val route: String, val label: String, val icon: ImageVector, val selectedIcon: ImageVector) {
    Home(Routes.DASHBOARD, "Home", Icons.Outlined.Home, Icons.Filled.Home),
    List(Routes.LIST, "List", Icons.Outlined.ShoppingBag, Icons.Filled.ShoppingBag),
    Spend(Routes.SPEND, "Spend", Icons.Outlined.PieChart, Icons.Filled.PieChart),
    Family(Routes.FAMILY, "Family", Icons.Outlined.People, Icons.Filled.People),
}

@Composable
fun HomeShell(
    state: SessionState,
    session: SessionViewModel,
    startRoute: String = Routes.DASHBOARD,
) {
    val navController = rememberNavController()
    val backStack by navController.currentBackStackEntryAsState()
    val currentRoute = backStack?.destination?.route
    val showChrome = currentRoute in Routes.tabs
    var showAddSheet by rememberSaveable { mutableStateOf(false) }

    LaunchedEffect(state.household?.id) {
        if (!state.isDemo) session.refreshAll()
    }

    Backdrop(modifier = Modifier.testTag(TestTags.MAIN_SHELL_VIEW)) {
        Scaffold(
            containerColor = Color.Transparent,
            bottomBar = {
                AnimatedVisibility(
                    visible = showChrome,
                    enter = slideInVertically { it } + fadeIn(),
                    exit = slideOutVertically { it } + fadeOut(),
                ) {
                    BottomPillNav(
                        currentRoute = currentRoute,
                        onSelect = { tab -> navController.switchTab(tab.route) },
                        onAdd = { showAddSheet = true },
                    )
                }
            },
        ) { innerPadding ->
            val bottomInset = PaddingValues(bottom = innerPadding.calculateBottomPadding())
            NavHost(
                navController = navController,
                startDestination = startRoute,
                enterTransition = { fadeIn() },
                exitTransition = { fadeOut() },
                popEnterTransition = { fadeIn() },
                popExitTransition = { fadeOut() },
            ) {
                composable(Routes.DASHBOARD) {
                    DashboardScreen(
                        state = state,
                        session = session,
                        contentPadding = bottomInset,
                        onOpenInventory = { navController.navigate(Routes.INVENTORY) },
                        onOpenItem = { navController.navigate(Routes.item(it.id)) },
                        onOpenList = { navController.switchTab(Routes.LIST) },
                        onOpenSpending = { navController.switchTab(Routes.SPEND) },
                        onEditHome = { navController.navigate(Routes.HOME_PHOTO) },
                    )
                }
                composable(Routes.LIST) {
                    ShoppingListScreen(state = state, session = session, contentPadding = bottomInset)
                }
                composable(Routes.SPEND) {
                    SpendingScreen(state = state, session = session, contentPadding = bottomInset)
                }
                composable(Routes.FAMILY) {
                    FamilyScreen(
                        state = state,
                        session = session,
                        contentPadding = bottomInset,
                        onOpenTrash = { navController.navigate(Routes.TRASH) },
                    )
                }
                composable(Routes.INVENTORY) {
                    InventoryScreen(
                        items = state.data.inventory,
                        pendingRemoval = state.pendingRemoval,
                        onBack = { navController.popBackStack() },
                        onConsume = { session.consume(it.id) },
                        onRemove = { session.removeInventoryItem(it.id) },
                        onUndoRemove = session::undoInventoryRemove,
                        onOpenItem = { navController.navigate(Routes.item(it.id)) },
                        onAdd = { showAddSheet = true },
                    )
                }
                composable(Routes.ITEM) { entry ->
                    val itemId = entry.arguments?.getString("itemId")
                    val item = state.data.inventory.firstOrNull { it.id == itemId }
                    if (item == null) {
                        LaunchedEffect(itemId) { navController.popBackStack() }
                    } else {
                        ItemDetailScreen(item = item, session = session, onBack = { navController.popBackStack() })
                    }
                }
                composable(Routes.HOME_PHOTO) {
                    HomePhotoScreen(state = state, session = session, onClose = { navController.popBackStack() })
                }
                composable(Routes.TRASH) {
                    TrashStationScreen(
                        state = state,
                        session = session,
                        kiosk = false,
                        onExit = { navController.popBackStack() },
                    )
                }
            }
        }
    }

    if (showAddSheet) {
        AddItemsSheet(
            state = state,
            session = session,
            onDismiss = { showAddSheet = false },
            onOpenTrash = {
                showAddSheet = false
                navController.navigate(Routes.TRASH)
            },
        )
    }
}

private fun NavHostController.switchTab(route: String) {
    navigate(route) {
        popUpTo(graph.findStartDestination().id) { saveState = true }
        launchSingleTop = true
        restoreState = true
    }
}

/** 64dp charcoal pill with four tabs and a raised red FAB in the centre gap. */
@Composable
private fun BottomPillNav(
    currentRoute: String?,
    onSelect: (HomeTab) -> Unit,
    onAdd: () -> Unit,
) {
    val palette = MekasaTheme.palette
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = Space.base)
            .padding(bottom = Space.base, top = Space.lg)
            .testTag(TestTags.BOTTOM_NAV_BAR),
        contentAlignment = Alignment.BottomCenter,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(64.dp)
                .background(palette.brand, Shapes.pill)
                .padding(horizontal = Space.sm),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            val tabs = HomeTab.entries
            tabs.take(2).forEach { NavSlot(it, currentRoute == it.route, onSelect) }
            Spacer(Modifier.width(64.dp))
            tabs.drop(2).forEach { NavSlot(it, currentRoute == it.route, onSelect) }
        }
        FloatingActionButton(
            onClick = onAdd,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .offset(y = (-4).dp)
                .size(56.dp)
                .border(4.dp, palette.surface, CircleShape)
                .testTag(TestTags.ADD_ITEM_BUTTON),
            shape = CircleShape,
            containerColor = palette.accent,
            contentColor = Color.White,
        ) {
            Icon(Icons.Filled.Add, contentDescription = "Add items")
        }
    }
}

@Composable
private fun RowScope.NavSlot(tab: HomeTab, selected: Boolean, onSelect: (HomeTab) -> Unit) {
    IconButton(
        onClick = { onSelect(tab) },
        modifier = Modifier.weight(1f).testTag(TestTags.tab(tab.label)),
    ) {
        Icon(
            imageVector = if (selected) tab.selectedIcon else tab.icon,
            contentDescription = tab.label,
            tint = if (selected) Color.White else Color(0xFFB7C6C2),
            modifier = Modifier.size(24.dp),
        )
    }
}
