import SwiftUI

/// Routes signup → household → address → stores → scan → invite → home.
/// Satisfies: UI-003
/// Spec version: 1.0
struct RootView: View {
    @EnvironmentObject private var session: AppSession
    @ObservedObject private var faceIDLock = FaceIDLock.shared

    private var showFaceIDLock: Bool {
        faceIDLock.shouldPresentLock(
            onboardingDone: session.onboardingStep == .done,
            isUITesting: session.isUITesting
        )
    }

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
            case .done where session.isTrashKioskMode:
                NavigationStack {
                    TrashStationView(kioskMode: true)
                }
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
        .overlay {
            if showFaceIDLock {
                FaceIDLockScreen(lock: faceIDLock)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showFaceIDLock)
        .onAppear {
            // Cold start already on `.done` does not fire onChange — lock then if needed.
            if session.onboardingStep == .done {
                faceIDLock.prepareForHome(isUITesting: session.isUITesting)
            }
        }
        .onChange(of: session.onboardingStep) { _, step in
            if step == .done {
                faceIDLock.prepareForHome(isUITesting: session.isUITesting)
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { session.lastError != nil },
            set: { isPresented in
                guard !isPresented, let dismissed = session.lastError else { return }
                // SwiftUI calls this mid view-update; publishing here directly triggers
                // "Publishing changes from within view updates is not allowed".
                Task { @MainActor in
                    if session.lastError == dismissed { session.lastError = nil }
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(session.lastError ?? "")
        }
    }
}

#Preview {
    RootView().environmentObject(AppSession())
}
