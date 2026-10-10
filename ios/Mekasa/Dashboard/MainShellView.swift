import SwiftUI

/// Post-onboarding shell: Dashboard + bottom nav + center Add FAB.
/// Satisfies: UI-004
/// Spec version: 1.0
struct MainShellView: View {
    @EnvironmentObject private var session: AppSession
    @State private var tab: MainTab = .home
    @State private var showAddItems = false
    @State private var showHouseAdd = false

    var body: some View {
        MekasaScreen {
            ZStack(alignment: .bottom) {
                Group {
                    switch tab {
                    case .home:
                        NavigationStack {
                            DashboardView(selectedTab: $tab)
                        }
                    case .list:
                        NavigationStack { ShoppingListView() }
                    case .spend:
                        NavigationStack { SpendingView() }
                    case .family:
                        NavigationStack { FamilyMembersView() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                BottomNavBar(selected: $tab) {
                    showHouseAdd = false
                    showAddItems = true
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TestIdentifiers.mainShellView)
        .sheet(isPresented: $showAddItems, onDismiss: { showHouseAdd = false }) {
            addSheet
                .environmentObject(session)
        }
        .task {
            guard !session.isUITesting else { return }
            if session.userUID == nil {
                session.userUID = AuthService.shared.currentUserUID
            }
            await session.refreshInventory()
            await session.refreshShoppingList(syncLowStock: true)
            await session.refreshSpending(period: .week)
            await session.refreshMyMembership()
            session.updateRealtimeSync()
            PushRegistrationService.shared.requestPermissionAndRegister(idToken: session.idToken)
        }
    }
}

extension MainShellView {
    @ViewBuilder
    fileprivate var addSheet: some View {
        if session.submitsShoppingRequests && !showHouseAdd {
            NavigationStack {
                MekasaScreen {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("What do you want?")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(MekasaTheme.text)
                            Text("An owner approves it before it goes on the shopping list.")
                                .font(MekasaTheme.bodyFont)
                                .foregroundStyle(MekasaTheme.textMuted)
                            ShoppingRequestComposer { _ in
                                showAddItems = false
                            }
                            SecondaryButton(title: "Add to the house instead") {
                                showHouseAdd = true
                            }
                        }
                        .padding(24)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { showAddItems = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .accessibilityIdentifier(TestIdentifiers.teenShoppingAsk)
        } else {
            NavigationStack {
                AddItemsView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct BottomNavBar: View {
    @Binding var selected: MainTab
    let onAdd: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            HStack {
                navButton(.home)
                navButton(.list)
                Color.clear.frame(width: 64)
                navButton(.spend)
                navButton(.family)
            }
            .padding(.horizontal, 20)
            .frame(height: 64)
            .background(MekasaTheme.brand)
            .clipShape(Capsule())
            .shadow(color: MekasaTheme.shadow.opacity(0.2), radius: 16, y: 8)

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MekasaTheme.onAccent)
                    .frame(width: 56, height: 56)
                    .background(MekasaTheme.accent)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(MekasaTheme.surface, lineWidth: 4))
                    .shadow(color: MekasaTheme.accent.opacity(0.35), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .offset(y: -22)
            .accessibilityLabel("Add items")
            .accessibilityIdentifier(TestIdentifiers.addItemButton)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TestIdentifiers.bottomNavBar)
    }

    private func navButton(_ tab: MainTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selected = tab }
        } label: {
            Image(systemName: tab.systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(selected == tab ? MekasaTheme.onBrand : MekasaTheme.onBrandMuted)
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityIdentifier(tab == .home ? TestIdentifiers.homeTab : (tab == .list ? TestIdentifiers.listTab : tab.title))
    }
}

#Preview {
    MainShellView().environmentObject({
        let s = AppSession()
        s.household = PreviewFixtures.household(name: "The Rodriguez House")
        s.onboardingStep = .done
        return s
    }())
}
