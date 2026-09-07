import PhotosUI
import SwiftUI

/// Name + optional photo for the household.
/// Satisfies: REQ-002, UI-003
/// Spec version: 1.0
struct HouseholdSetupView: View {
    @EnvironmentObject private var session: AppSession
    @State private var name = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoImage: UIImage?

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                OnboardingHeader(step: .household)
                    .padding(.top, 48)

                ScrollView {
                    VStack(spacing: 32) {
                        Text("Name this house.")
                            .font(MekasaTheme.displayFont)
                            .foregroundStyle(MekasaTheme.brand)
                            .multilineTextAlignment(.center)
                            .padding(.top, 36)

                        PhotosPicker(selection: $photoItem, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                ZStack {
                                    Circle()
                                        .fill(MekasaTheme.surfaceElevated)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(
                                                    style: StrokeStyle(lineWidth: 2, dash: [6])
                                                )
                                                .foregroundStyle(MekasaTheme.brandMuted)
                                        )
                                        .frame(width: 128, height: 128)
                                        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

                                    if let photoImage {
                                        Image(uiImage: photoImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 128, height: 128)
                                            .clipShape(Circle())
                                    } else {
                                        VStack(spacing: 6) {
                                            Image(systemName: "house.fill")
                                                .font(.system(size: 22, weight: .semibold))
                                            Text("Add Photo")
                                                .font(MekasaTheme.labelFont)
                                                .tracking(0.8)
                                                .textCase(.uppercase)
                                                .foregroundStyle(MekasaTheme.textMuted)
                                        }
                                        .foregroundStyle(MekasaTheme.brand)
                                    }
                                }
                                Circle()
                                    .fill(MekasaTheme.brand)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                    )
                                    .shadow(radius: 4, y: 2)
                            }
                        }
                        .onChange(of: photoItem) { _, item in
                            Task {
                                guard let data = try? await item?.loadTransferable(type: Data.self),
                                      let image = UIImage(data: data)
                                else { return }
                                photoImage = image
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            MekasaTextField(
                                label: "Household Name",
                                placeholder: "The Rivas House",
                                text: $name
                            )
                            Text("You're the admin. You can invite people next. Name is optional.")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.textMuted)
                                .padding(.leading, 16)
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 140)
                }

                StickyBottomBar(progress: 2.0 / 6.0) {
                    PrimaryButton(title: "Continue", isLoading: session.isBusy) {
                        Task { await createHousehold() }
                    }
                }
            }
        }
        .onAppear {
            if let existing = session.household?.name {
                name = existing
            }
        }
    }

    private func createHousehold() async {
        guard let token = session.idToken else {
            session.lastError = "Not signed in."
            return
        }
        session.isBusy = true
        defer { session.isBusy = false }
        do {
            // Photo upload is not in the thin API yet — name only for now.
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let household = try await MekasaAPIClient.shared.createHousehold(
                name: trimmed.isEmpty ? nil : trimmed,
                photoURL: nil,
                token: token
            )
            session.household = household
            withAnimation { session.onboardingStep = .address }
        } catch {
            // Resume if household already exists
            if let existing = try? await MekasaAPIClient.shared.currentHousehold(token: token) {
                session.household = existing
                withAnimation { session.onboardingStep = .address }
            } else {
                session.lastError = error.localizedDescription
            }
        }
    }
}

#Preview {
    HouseholdSetupView().environmentObject(AppSession())
}
