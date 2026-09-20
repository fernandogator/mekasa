import SwiftUI

/// Post-onboarding shell: Dashboard + bottom nav + center Add FAB.
/// Satisfies: UI-004
/// Spec version: 1.0
struct MainShellView: View {
    @EnvironmentObject private var session: AppSession
    @State private var tab: MainTab = .home
    @State private var showAddItems = false

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
                    showAddItems = true
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TestIdentifiers.mainShellView)
        .sheet(isPresented: $showAddItems) {
            NavigationStack {
                AddItemsView()
            }
            .environmentObject(session)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
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
            .shadow(color: .black.opacity(0.2), radius: 16, y: 8)

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
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
                .foregroundStyle(selected == tab ? Color.white : MekasaTheme.brandMuted)
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
