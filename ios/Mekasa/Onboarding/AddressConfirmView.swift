import SwiftUI

/// GPS reverse-geocode → confirm/edit address before store search.
/// Satisfies: REQ-003 AC1–AC3, UI-003
/// Spec version: 1.0
struct AddressConfirmView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var location = LocationService()
    @State private var address = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var didDetect = false

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                OnboardingHeader(step: .address)
                    .padding(.top, 48)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Where is home?")
                            .font(MekasaTheme.displayFont)
                            .foregroundStyle(MekasaTheme.brand)
                            .padding(.top, 36)

                        Text("We'll use this to find grocery stores within 15 miles. Edit anything that looks wrong.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)

                        MekasaTextField(
                            label: "Home address",
                            placeholder: "Street, city, state",
                            text: $address
                        )

                        SecondaryButton(title: didDetect ? "Detect again" : "Use my location") {
                            Task { await detect() }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 140)
                }

                StickyBottomBar(progress: 3.0 / 6.0) {
                    PrimaryButton(
                        title: "Confirm address",
                        disabled: address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        isLoading: session.isBusy
                    ) {
                        Task { await save() }
                    }
                }
            }
        }
        .task {
            if session.isUIPreview {
                if address.isEmpty {
                    address = "1842 Magnolia Ave, Austin, TX 78702"
                    latitude = 30.2672
                    longitude = -97.7431
                    didDetect = true
                }
                return
            }
            if let existing = session.household?.address {
                address = existing
                latitude = session.household?.latitude
                longitude = session.household?.longitude
                didDetect = true
            } else {
                await detect()
            }
        }
    }

    private func detect() async {
        session.isBusy = true
        defer { session.isBusy = false }
        do {
            let result = try await location.detectHomeAddress()
            address = result.address
            latitude = result.latitude
            longitude = result.longitude
            didDetect = true
        } catch {
            session.lastError = "Location unavailable. Enter your address manually. (\(error.localizedDescription))"
        }
    }

    private func save() async {
        guard var household = session.household else {
            session.lastError = "Missing household."
            return
        }
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if session.isUIPreview {
            household.address = trimmed
            household.latitude = latitude ?? 30.2672
            household.longitude = longitude ?? -97.7431
            session.household = household
            withAnimation { session.onboardingStep = .stores }
            return
        }
        guard let token = session.idToken else {
            session.lastError = "Not signed in."
            return
        }
        session.isBusy = true
        defer { session.isBusy = false }
        do {
            let updated = try await MekasaAPIClient.shared.updateAddress(
                householdID: household.id,
                address: trimmed,
                latitude: latitude,
                longitude: longitude,
                token: token
            )
            session.household = updated
            withAnimation { session.onboardingStep = .stores }
        } catch {
            session.lastError = error.localizedDescription
        }
    }
}

#Preview {
    AddressConfirmView().environmentObject(AppSession())
}
