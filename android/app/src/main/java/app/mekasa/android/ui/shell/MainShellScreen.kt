package app.mekasa.android.ui.shell

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
import androidx.compose.material.icons.outlined.AccountBalanceWallet
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.People
import androidx.compose.material.icons.outlined.ShoppingBag
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import app.mekasa.android.session.AppSession
import app.mekasa.android.session.AppUiState
import app.mekasa.android.ui.additems.AddItemsSheet
import app.mekasa.android.ui.components.MekasaScreen
import app.mekasa.android.ui.dashboard.DashboardScreen
import app.mekasa.android.ui.dashboard.HomePhotoScreen
import app.mekasa.android.ui.family.FamilyScreen
import app.mekasa.android.ui.inventory.InventoryScreen
import app.mekasa.android.ui.inventory.ItemDetailScreen
import app.mekasa.android.ui.shopping.ShoppingListScreen
import app.mekasa.android.ui.spending.SpendingScreen
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaShapes
import app.mekasa.android.ui.theme.Spacing
import app.mekasa.android.ui.trash.TrashStationScreen
import app.mekasa.android.data.InventoryItemDto

@Composable
fun MainShellScreen(
    state: AppUiState,
    session: AppSession,
) {
    var tab by remember { mutableStateOf(MainTab.Home) }
    var showAdd by remember { mutableStateOf(false) }
    var showInventory by remember { mutableStateOf(false) }
    var showTrash by remember { mutableStateOf(false) }
    var showHomePhoto by remember { mutableStateOf(false) }
    var selectedItem by remember { mutableStateOf<InventoryItemDto?>(null) }

    LaunchedEffect(state.household?.id, state.isOfflinePreview) {
        if (!state.isOfflinePreview) {
            session.refreshDashboard()
        }
    }

    // Keep detail in sync with inventory updates.
    val detailItem = selectedItem?.let { selected ->
        state.inventory.firstOrNull { it.id == selected.id } ?: selected
    }

    if (showTrash) {
        TrashStationScreen(
            state = state,
            session = session,
            kioskMode = false,
            onExit = { showTrash = false },
        )
        return
    }

    if (showHomePhoto) {
        HomePhotoScreen(
            state = state,
            session = session,
            onClose = { showHomePhoto = false },
        )
        return
    }

    if (detailItem != null) {
        ItemDetailScreen(
            item = detailItem,
            session = session,
            onBack = { selectedItem = null },
        )
        return
    }

    MekasaScreen(modifier = Modifier.testTag("MainShellView")) {
        Scaffold(
            containerColor = Color.Transparent,
            bottomBar = {
                BottomNavBar(
                    selected = tab,
                    onSelect = {
                        showInventory = false
                        selectedItem = null
                        tab = it
                    },
                    onAdd = { showAdd = true },
                )
            },
        ) { padding ->
            val contentPadding = PaddingValues(
                bottom = padding.calculateBottomPadding(),
            )
            when {
                tab == MainTab.Home && showInventory -> InventoryScreen(
                    items = state.inventory,
                    onConsume = session::consumeInventoryItem,
                    onOpenItem = { selectedItem = it },
                    onBack = { showInventory = false },
                    contentPadding = contentPadding,
                )
                tab == MainTab.Home -> DashboardScreen(
                    state = state,
                    session = session,
                    onSelectTab = { tab = it },
                    onOpenInventory = { showInventory = true },
                    onOpenHomePhoto = { showHomePhoto = true },
                    contentPadding = contentPadding,
                )
                tab == MainTab.List -> ShoppingListScreen(
                    state = state,
                    session = session,
                    contentPadding = contentPadding,
                )
                tab == MainTab.Spend -> SpendingScreen(
                    state = state,
                    session = session,
                    contentPadding = contentPadding,
                )
                tab == MainTab.Family -> FamilyScreen(
                    state = state,
                    session = session,
                    contentPadding = contentPadding,
                )
            }
        }
    }

    if (showAdd) {
        AddItemsSheet(
            state = state,
            session = session,
            onDismiss = { showAdd = false },
            onOpenTrash = { showTrash = true },
        )
    }
}

@Composable
private fun BottomNavBar(
    selected: MainTab,
    onSelect: (MainTab) -> Unit,
    onAdd: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = Spacing.lg)
            .padding(bottom = Spacing.lg)
            .testTag("BottomNavBar"),
        contentAlignment = Alignment.BottomCenter,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(64.dp)
                .background(MekasaColor.brand, MekasaShapes.pill)
                .padding(horizontal = Spacing.base),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            NavIcon(
                icon = Icons.Outlined.Home,
                selected = selected == MainTab.Home,
                label = "Home",
                testTag = "HomeTab",
                onClick = { onSelect(MainTab.Home) },
            )
            NavIcon(
                icon = Icons.Outlined.ShoppingBag,
                selected = selected == MainTab.List,
                label = "List",
                testTag = "ListTab",
                onClick = { onSelect(MainTab.List) },
            )
            Spacer(modifier = Modifier.width(64.dp))
            NavIcon(
                icon = Icons.Outlined.AccountBalanceWallet,
                selected = selected == MainTab.Spend,
                label = "Spend",
                onClick = { onSelect(MainTab.Spend) },
            )
            NavIcon(
                icon = Icons.Outlined.People,
                selected = selected == MainTab.Family,
                label = "Family",
                onClick = { onSelect(MainTab.Family) },
            )
        }
        FloatingActionButton(
            onClick = onAdd,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .offset(y = (-22).dp)
                .size(56.dp)
                .border(4.dp, MekasaColor.surface, CircleShape)
                .testTag("AddItemButton"),
            shape = CircleShape,
            containerColor = MekasaColor.accent,
            contentColor = Color.White,
        ) {
            Icon(Icons.Filled.Add, contentDescription = "Add items")
        }
    }
}

@Composable
private fun RowScope.NavIcon(
    icon: ImageVector,
    selected: Boolean,
    label: String,
    testTag: String = label,
    onClick: () -> Unit,
) {
    IconButton(
        onClick = onClick,
        modifier = Modifier
            .weight(1f)
            .testTag(testTag),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = if (selected) Color.White else MekasaColor.brandMuted,
            modifier = Modifier.size(24.dp),
        )
    }
}
