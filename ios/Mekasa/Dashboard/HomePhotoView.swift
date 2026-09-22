import PhotosUI
import SwiftUI
import UIKit

/// Add or replace the household home photo from camera or photo library.
/// Satisfies: REQ-002 AC2–AC3, UI-004 AC3
/// Spec version: 1.0
struct HomePhotoView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var selectedImage: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var localError: String?

    private var canSave: Bool { selectedImage != nil && !session.isBusy }

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(MekasaTheme.textMuted)
                        .accessibilityIdentifier(TestIdentifiers.cancelButton)
                    Spacer()
                    Text("Home photo")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(MekasaTheme.brand)
                    Spacer()
                    Color.clear.frame(width: 56, height: 1)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 24) {
                        Text("Show your house on the home screen.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 12)

                        previewCard
                            .padding(.horizontal, 24)

                        VStack(spacing: 12) {
                            if CameraImagePicker.isCameraAvailable {
                                PrimaryButton(title: "Take photo", disabled: session.isBusy) {
                                    localError = nil
                                    showCamera = true
                                }
                                .accessibilityIdentifier(TestIdentifiers.homePhotoCameraButton)
                            }

                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Text("Choose from Photos")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .foregroundStyle(MekasaTheme.brand)
                                    .background(MekasaTheme.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .stroke(MekasaTheme.brandMuted.opacity(0.35), lineWidth: 1)
                                    )
                            }
                            .disabled(session.isBusy)
                            .accessibilityIdentifier(TestIdentifiers.homePhotoLibraryButton)
                        }
                        .padding(.horizontal, 24)

                        if let localError {
                            Text(localError)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.accent)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        } else if let message = session.lastError {
                            Text(message)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.accent)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        Text("Owners can update this anytime. Members see it on the dashboard hero.")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(MekasaTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.bottom, 140)
                }

                StickyBottomBar(progress: nil) {
                    PrimaryButton(
                        title: "Save home photo",
                        disabled: !canSave,
                        isLoading: session.isBusy
                    ) {
                        Task { await save() }
                    }
                    .accessibilityIdentifier(TestIdentifiers.saveButton)
                }
            }
        }
        .accessibilityIdentifier(TestIdentifiers.homePhotoView)
        .onAppear { seedFromHousehold() }
        .onChange(of: photoItem) { _, item in
            Task { await loadLibraryItem(item) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker(image: $selectedImage)
                .ignoresSafeArea()
        }
    }

    private var previewCard: some View {
        ZStack {
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
            } else {
                HouseholdPhotoView(urlString: session.household?.photoURL)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(MekasaTheme.brandMuted.opacity(0.35), lineWidth: 1)
        )
        .accessibilityIdentifier(TestIdentifiers.homePhotoPreview)
    }

    private func seedFromHousehold() {
        if selectedImage == nil,
           let existing = HouseholdPhotoImage.uiImage(from: session.household?.photoURL) {
            selectedImage = existing
        }
    }

    private func loadLibraryItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else {
                localError = "Couldn’t read that photo. Try another one."
                return
            }
            selectedImage = image
            localError = nil
        } catch {
            localError = error.localizedDescription
        }
    }

    private func save() async {
        guard let selectedImage else { return }
        localError = nil
        session.lastError = nil
        let ok = await session.uploadHouseholdHomePhoto(selectedImage)
        if ok {
            dismiss()
        } else if session.lastError == nil {
            localError = "Couldn’t save the home photo."
        }
    }
}

#Preview {
    NavigationStack {
        HomePhotoView()
            .environmentObject({
                let s = AppSession()
                s.isUIPreview = true
                s.household = PreviewFixtures.household(name: "The Demo House")
                return s
            }())
    }
}
