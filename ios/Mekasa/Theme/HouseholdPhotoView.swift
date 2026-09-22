import SwiftUI
import UIKit

/// Renders a household `photo_url` (remote HTTPS or `data:` URL).
enum HouseholdPhotoImage {
    static func uiImage(from urlString: String?) -> UIImage? {
        guard let urlString, !urlString.isEmpty else { return nil }
        if urlString.hasPrefix("data:"),
           let b64 = urlString.split(separator: ",").last,
           let data = Data(base64Encoded: String(b64)) {
            return UIImage(data: data)
        }
        return nil
    }
}

struct HouseholdPhotoView: View {
    let urlString: String?
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let local = HouseholdPhotoImage.uiImage(from: urlString) {
                Image(uiImage: local)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if let urlString, let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().aspectRatio(contentMode: contentMode)
                    case .failure:
                        placeholder
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(MekasaTheme.brandMuted.opacity(0.35))
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    MekasaTheme.brandMuted.opacity(0.55),
                    MekasaTheme.brand.opacity(0.85),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "house.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}
