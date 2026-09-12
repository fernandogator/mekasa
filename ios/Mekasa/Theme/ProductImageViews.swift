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
                AsyncImage(url: url) { phase in
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
            .fill(Color(red: 0xf1 / 255, green: 0xf4 / 255, blue: 0xf3 / 255))
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(MekasaTheme.brandMuted)
            }
    }
}

/// Large product hero; tap to present a full-screen lightbox.
struct ProductHeroImage: View {
    let urlString: String?
    let title: String
    @State private var showLightbox = false

    var body: some View {
        Button {
            guard urlString != nil else { return }
            showLightbox = true
        } label: {
            Group {
                if let urlString, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
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
            .background(Color(red: 0xf1 / 255, green: 0xf4 / 255, blue: 0xf3 / 255))
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(urlString == nil)
        .accessibilityLabel(urlString == nil ? "No product image" : "Product image for \(title), double tap to enlarge")
        .accessibilityIdentifier(TestIdentifiers.itemImage)
        .fullScreenCover(isPresented: $showLightbox) {
            ProductImageLightbox(urlString: urlString, title: title)
        }
    }

    private var heroPlaceholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 40, weight: .semibold))
            .foregroundStyle(MekasaTheme.brandMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProductImageLightbox: View {
    let urlString: String?
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(16)
                    case .failure, .empty:
                        ProgressView().tint(.white)
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
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(20)
            }
            .accessibilityLabel("Close")
        }
        .accessibilityLabel("Enlarged image of \(title)")
        .onTapGesture { dismiss() }
    }
}
