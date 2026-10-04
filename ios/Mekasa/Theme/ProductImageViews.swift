import SwiftUI

/// Remote product image from Open Food Facts (or placeholder).
/// Satisfies: REQ-004 image display, UI inventory thumbnail/detail
/// Spec version: 1.0
struct ProductThumbnail: View {
    let urlString: String?
    var size: CGFloat = 56
    var cornerRadius: CGFloat = 16

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                MekasaRemoteImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder.overlay { ProgressView() }
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(urlString == nil)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(MekasaTheme.surfaceMuted)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(MekasaTheme.border)
            }
    }
}

/// Large product hero; tap to present a full-screen lightbox. With `onReplace`,
/// tap offers View full size / Take photo / Choose from library instead.
struct ProductHeroImage: View {
    let urlString: String?
    let title: String
    var onReplace: ((UIImage) async -> Void)?
    @State private var showLightbox = false
    @State private var showPhotoOptions = false
    @State private var isUploading = false

    var body: some View {
        Button {
            if onReplace != nil {
                showPhotoOptions = true
            } else if urlString != nil {
                showLightbox = true
            }
        } label: {
            Group {
                if let urlString, let url = URL(string: urlString) {
                    MekasaRemoteImage(url: url) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: 280)
                                .padding(16)
                        case .failure, .empty:
                            heroPlaceholder
                        @unknown default:
                            heroPlaceholder
                        }
                    }
                } else {
                    heroPlaceholder
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .background(MekasaTheme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay {
                if isUploading {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(MekasaTheme.scrim.opacity(0.35))
                        .overlay { ProgressView().tint(MekasaTheme.onBrand) }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if onReplace != nil {
                    Label("Change photo", systemImage: "camera.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(MekasaTheme.onBrand)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(MekasaTheme.brand.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(14)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(urlString == nil && onReplace == nil)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier(TestIdentifiers.itemImage)
        .fullScreenCover(isPresented: $showLightbox) {
            ProductImageLightbox(urlString: urlString, title: title)
        }
        .itemPhotoReplacement(
            isPresented: $showPhotoOptions,
            onViewFullSize: urlString == nil ? nil : { showLightbox = true }
        ) { image in
            guard let onReplace else { return }
            Task {
                isUploading = true
                await onReplace(image)
                isUploading = false
            }
        }
    }

    private var accessibilityText: String {
        if onReplace != nil {
            return "Product image for \(title), double tap to view or replace"
        }
        return urlString == nil ? "No product image" : "Product image for \(title), double tap to enlarge"
    }

    private var heroPlaceholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 40, weight: .semibold))
            .foregroundStyle(MekasaTheme.border)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProductImageLightbox: View {
    let urlString: String?
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            MekasaTheme.cameraSurface.ignoresSafeArea()
            if let urlString, let url = URL(string: urlString) {
                MekasaRemoteImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(16)
                    case .failure, .empty:
                        ProgressView().tint(MekasaTheme.onCamera)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(MekasaTheme.onCamera.opacity(0.9))
                    .padding(20)
            }
            .accessibilityLabel("Close")
        }
        .accessibilityLabel("Enlarged image of \(title)")
        .onTapGesture { dismiss() }
    }
}
