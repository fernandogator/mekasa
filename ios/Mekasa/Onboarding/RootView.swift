import SwiftUI

/// Routes signup → household → address → stores → scan → invite → home.
/// Satisfies: UI-003
/// Spec version: 1.0
struct RootView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        Group {
            switch session.onboardingStep {
            case .welcome:
                WelcomeView()
            case .household:
                HouseholdSetupView()
            case .address:
                AddressConfirmView()
            case .stores:
                StoreSelectionView()
            case .initialScan:
                InitialScanView()
            case .invite:
                InviteView()
            case .done:
                MainShellView()
            }
        }
        // Keep children as distinct accessibility elements. Applying an identifier
        // on this Group without `.contain` was rewriting every descendant's id to
        // "RootView" (AddItemButton, HomeTab, etc. became unfindable in XCUITest).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TestIdentifiers.rootView)
        .animation(session.isUITesting ? nil : .easeInOut(duration: 0.25), value: session.onboardingStep)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .alert("Something went wrong", isPresented: Binding(
            get: { session.lastError != nil },
            set: { if !$0 { session.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { session.lastError = nil }
        } message: {
            Text(session.lastError ?? "")
        }
    }
}

#Preview {
    RootView().environmentObject(AppSession())
}
