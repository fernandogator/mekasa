import SwiftUI

/// Multi-select nearby stores (Google Places when configured, else stub list).
/// Shares its list, rows and address prompt with Family → Grocery stores.
/// Satisfies: REQ-003 AC4–AC6, AC11, UI-002 / UI-003
/// Spec version: 1.0
struct StoreSelectionView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var model = StorePickerModel()

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                OnboardingHeader(step: .stores)
                    .padding(.top, 48)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Where do you shop?")
                        .font(MekasaTheme.displayFont)
                        .foregroundStyle(MekasaTheme.text)

                    switch model.phase {
                    case .address:
                        StoreAddressPrompt(
                            address: $model.address,
                            isLoading: model.isWorking,
                            message: model.message
                        ) {
                            Task { await model.findStores(session: session) }
                        }
                        Spacer()
                    case .loading, .failed, .list:
                        Text(StoreSelectionCopy.subtitle(address: session.household?.address))
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)

                        if model.phase == .failed {
                            SecondaryButton(title: "Try again") {
                                Task { await model.load(session: session) }
                            }
                        }

                        StorePickerList(
                            stores: model.stores,
                            placesIDs: model.placesIDs,
                            selected: $model.selected,
                            query: $model.query
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 8)

                StickyBottomBar(progress: 4.0 / 6.0) {
                    PrimaryButton(
                        title: "Confirm stores",
                        disabled: model.selected.isEmpty || model.phase != .list,
                        isLoading: session.isBusy || model.isWorking
                    ) {
                        Task { await confirm() }
                    }
                    .accessibilityIdentifier(TestIdentifiers.storeConfirmButton)
                }
            }
        }
        .task { await model.start(session: session) }
    }

    /// Satisfies: REQ-003 AC6, AC11 (onboarding saves store details too)
    /// Spec version: 1.0
    private func confirm() async {
        if await model.confirm(session: session) {
            withAnimation { session.onboardingStep = .initialScan }
        }
    }
}

#Preview {
    StoreSelectionView().environmentObject(AppSession())
}
