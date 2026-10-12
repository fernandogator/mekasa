import SwiftUI

/// Remote product image from Open Food Facts (or placeholder).
/// Satisfies: REQ-004 image display, UI inventory thumbnail/detail
/// Spec version: 1.0
struct ProductThumbnail: View {
    let urlString: String?
    var size: CGFloat
    var cornerRadius: CGFloat
    /// Painted from the local database when this URL was seen before (UI-006 AC8).
    @State private var image: UIImage?
    @State private var failed = false

    init(urlString: String?, size: CGFloat = 56, cornerRadius: CGFloat = 16) {
        self.urlString = urlString
        self.size = size
        self.cornerRadius = cornerRadius
        _image = State(initialValue: Self.cachedImage(urlString))
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if failed || urlString == nil {
                placeholder
            } else {
                placeholder.overlay { ProgressView() }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(urlString == nil)
        .task(id: urlString) {
            failed = false
            if let cached = Self.cachedImage(urlString) {
                image = cached
                return
            }
            image = nil
            guard let urlString, let url = URL(string: urlString) else { return }
            do {
                image = try await ThumbnailLoader.shared.image(for: url)
            } catch is CancellationError {
                return
            } catch let urlError as URLError where urlError.code == .cancelled {
                return
            } catch {
                failed = true
            }
        }
    }

    private static func cachedImage(_ urlString: String?) -> UIImage? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        return ThumbnailStore.shared.image(for: PrivateItemPhoto.resolve(url).absoluteString)
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
/// Pass `lightboxPresented` when the parent owns the cover (so it can stay open
/// while swiping between items).
struct ProductHeroImage: View {
    let urlString: String?
    let title: String
    var onReplace: ((UIImage) async -> Void)?
    var lightboxPresented: Binding<Bool>?
    @State private var showLightbox = false
    @State private var showPhotoOptions = false
    @State private var isUploading = false

    init(
        urlString: String?,
        title: String,
        lightboxPresented: Binding<Bool>? = nil,
        onReplace: ((UIImage) async -> Void)? = nil
    ) {
        self.urlString = urlString
        self.title = title
        self.lightboxPresented = lightboxPresented
        self.onReplace = onReplace
    }

    var body: some View {
        Button {
            if onReplace != nil {
                showPhotoOptions = true
            } else if urlString != nil {
                openLightbox()
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
            onViewFullSize: urlString == nil ? nil : { openLightbox() }
        ) { image in
            guard let onReplace else { return }
            Task {
                isUploading = true
                await onReplace(image)
                isUploading = false
            }
        }
    }

    private func openLightbox() {
        if let lightboxPresented {
            lightboxPresented.wrappedValue = true
        } else {
            showLightbox = true
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
    /// REQ-INV-020: swipe / chevrons move within the list the detail came from.
    var onPrevious: (() -> Void)? = nil
    var onNext: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0

    private var canPage: Bool { onPrevious != nil || onNext != nil }

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
                            .offset(x: dragOffset)
                            .id(urlString)
                    case .failure, .empty:
                        ProgressView().tint(MekasaTheme.onCamera)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.onCamera)
                    .lineLimit(1)
                    .padding(.horizontal, 56)
                if canPage {
                    Text("Swipe for the next item")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(MekasaTheme.onCamera.opacity(0.7))
                }
            }
            .padding(.top, 16)
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
        .overlay(alignment: .leading) {
            if onPrevious != nil {
                lightboxChevron(systemName: "chevron.left", label: "Previous item") {
                    onPrevious?()
                }
                .accessibilityIdentifier(TestIdentifiers.itemPagerPrevious)
            }
        }
        .overlay(alignment: .trailing) {
            if onNext != nil {
                lightboxChevron(systemName: "chevron.right", label: "Next item") {
                    onNext?()
                }
                .accessibilityIdentifier(TestIdentifiers.itemPagerNext)
            }
        }
        .accessibilityLabel("Enlarged image of \(title)")
        .accessibilityAction(named: Text("Next item")) { onNext?() }
        .accessibilityAction(named: Text("Previous item")) { onPrevious?() }
        .simultaneousGesture(lightboxSwipe)
        .onTapGesture { dismiss() }
        .accessibilityIdentifier(TestIdentifiers.itemLightbox)
    }

    private func lightboxChevron(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(MekasaTheme.onCamera)
                .frame(width: 40, height: 40)
                .background(MekasaTheme.onCamera.opacity(0.18))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(12)
        .accessibilityLabel(label)
    }

    private var lightboxSwipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard canPage else { return }
                let dx = value.translation.width
                guard abs(dx) > abs(value.translation.height) * 1.5 else { return }
                dragOffset = dx * 0.35
            }
            .onEnded { value in
                guard canPage else {
                    dragOffset = 0
                    return
                }
                if let step = ItemPager.step(translation: value.translation, startX: value.startLocation.x) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { dragOffset = 0 }
                    switch step {
                    case .previous: onPrevious?()
                    case .next: onNext?()
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragOffset = 0 }
                }
            }
    }
}
