import UIKit

/// What an in-store capture produced for an unidentified receipt line.
struct LocalItemCaptureResult: Equatable {
    var barcode: String?
    /// Uploaded photo URL (nil when no photo was taken or the upload failed).
    var photoURL: String?
    /// Set when the photo went to the shared product photos with a UPC / PLU
    /// (REQ-RCP-021); otherwise the photo is household-private.
    var productPhotoID: String?
    /// Catalog hit for the scanned barcode, when Open Food Facts knows it.
    var lookup: BarcodeLookupDTO?
}

/// A code the shared catalog accepts on capture: UPC (8–14 digits) or PLU (4–5).
/// Satisfies: REQ-RCP-020 AC2, AC7
/// Spec version: 1.0
enum CatalogCaptureCode: Equatable {
    case upc(String)
    case plu(String)

    init?(_ raw: String?) {
        guard let raw, !raw.isEmpty, raw.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        switch raw.count {
        case 4 ... 5: self = .plu(raw)
        case 8 ... 14: self = .upc(raw)
        default: return nil
        }
    }

    /// Capture body for an inventory item created from a receipt line: the
    /// receipt text and chain go with the code and photo so the next scan of
    /// that text matches the product (REQ-RCP-020 AC6, REQ-RCP-007 AC5).
    func request(photoID: String?, receiptText: String?, storeChainId: String?) -> ProductCaptureRequestDTO {
        var body = ProductCaptureRequestDTO(
            photoId: photoID,
            receiptText: Self.trimmedAlias(receiptText),
            storeChainId: storeChainId
        )
        switch self {
        case let .upc(code): body.upc = code
        case let .plu(code): body.pluCode = code
        }
        return body
    }

    /// Photo-only capture: no code, so the receipt text names the product
    /// for its chain (REQ-RCP-020 AC15). Nil without a shared photo or text.
    static func photoOnlyRequest(photoID: String?, receiptText: String?, storeChainId: String?) -> ProductCaptureRequestDTO? {
        guard let photoID, let alias = trimmedAlias(receiptText) else { return nil }
        return ProductCaptureRequestDTO(photoId: photoID, receiptText: alias, storeChainId: storeChainId)
    }

    static func trimmedAlias(_ receiptText: String?) -> String? {
        receiptText
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : String($0.prefix(200)) }
    }
}

/// User item photos: replace any item picture and in-store captures (REQ-004 / REQ-005).
/// Satisfies: REQ-INV-019 (Replace an Item Picture With a Private Photo)
/// Acceptance criteria: AC1, AC4, AC8
/// Spec version: 1.0
extension AppSession {
    /// Upload the user's own picture to the household's private photo store and
    /// return its URL for `imageURL`. The URL is only readable by household
    /// members (REQ-INV-019). Preview / UI-test sessions return a local data URL.
    func uploadItemPhoto(_ image: UIImage) async -> String? {
        guard let jpeg = ItemPhotoEncoding.jpegData(from: image) else {
            showError("Couldn’t encode that photo.")
            return nil
        }
        if isUIPreview || isUITesting {
            return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
        }
        guard let token = idToken, let householdID = household?.id else {
            showError("Sign in to your household to use your own photos.")
            return nil
        }
        do {
            let uploaded = try await MekasaAPIClient.shared.uploadItemPhoto(
                householdID: householdID,
                imageData: jpeg,
                token: token
            )
            return uploaded.url
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                handleAPIFailure(error)
            } else {
                showError("Couldn’t upload that photo.", error: error)
            }
            return nil
        }
    }

    /// Replace a saved inventory item's picture with the user's own photo.
    @discardableResult
    func replaceInventoryItemImage(itemID: String, image: UIImage) async -> Bool {
        guard let url = await uploadItemPhoto(image),
              let idx = inventory.firstIndex(where: { $0.id == itemID })
        else { return false }
        inventory[idx].imageURL = url
        inventory[idx].updatedAt = Date()
        guard canSyncInventory, let token = idToken, let householdID = household?.id else {
            return true
        }
        do {
            let remote = try await MekasaAPIClient.shared.updateInventoryItem(
                householdID: householdID,
                itemID: itemID,
                imageURL: url,
                token: token
            )
            if let idx = inventory.firstIndex(where: { $0.id == remote.id }) {
                inventory[idx] = remote.toLocal()
            }
            logActivity("Updated photo for \(remote.name)", kind: .success)
            return true
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                handleAPIFailure(error)
            } else {
                showError("Couldn’t save the new photo.", error: error)
            }
            return false
        }
    }

    /// In-store capture for a receipt line the catalog could not identify. With
    /// a UPC / PLU, or with no code when `shareWithoutCode` (the line has
    /// receipt text, REQ-RCP-020 AC15), the photo is uploaded to the shared
    /// product photos (REQ-RCP-021) so the confirm step can send it with the
    /// receipt text; otherwise it stays a household-private item photo
    /// (REQ-INV-019). The scanned code is also looked up in case Open Food Facts knows it.
    func captureUnidentifiedItem(
        barcode: String?,
        image: UIImage?,
        shareWithoutCode: Bool = false
    ) async -> LocalItemCaptureResult? {
        await RequestTracing.$correlationID.withValue(receiptFlowID) { () async -> LocalItemCaptureResult? in
            await performCapture(barcode: barcode, image: image, shareWithoutCode: shareWithoutCode)
        }
    }

    private func performCapture(
        barcode: String?,
        image: UIImage?,
        shareWithoutCode: Bool
    ) async -> LocalItemCaptureResult? {
        let code = barcode.flatMap { $0.isEmpty ? nil : $0 }
        var result = LocalItemCaptureResult(barcode: code)
        if let image {
            let shares = CatalogCaptureCode(code) != nil || (code == nil && shareWithoutCode)
            if shares, let shared = await uploadProductPhoto(image) {
                result.photoURL = shared.imageUrl
                result.productPhotoID = shared.photoId
            } else {
                result.photoURL = await uploadItemPhoto(image)
            }
            if result.photoURL == nil, code == nil {
                return nil
            }
        }
        guard let token = idToken, let householdID = household?.id, !isUIPreview, !isUITesting else {
            return result
        }
        if let code, code.count >= ManualBarcodeEntry.minLength {
            let hit = try? await MekasaAPIClient.shared.lookupBarcode(
                code: code,
                householdID: householdID,
                token: token
            )
            if let hit, hit.found { result.lookup = hit }
        }
        return result
    }

    /// Add a barcode or PLU to a saved item that has none (REQ-RCP-020 AC15):
    /// the capture links or re-keys its shared product, then a UPC refreshes
    /// the health grade right away (REQ-021 AC4). PLU produce has no nutrition source.
    /// Returns an error message to show inline, or nil on success.
    func addCodeToInventoryItem(itemID: String, code: CatalogCaptureCode) async -> String? {
        guard canSyncInventory, let token = idToken, let householdID = household?.id else {
            return "Sign in to your household to add a barcode."
        }
        var body = ProductCaptureRequestDTO()
        switch code {
        case let .upc(value): body.upc = value
        case let .plu(value): body.pluCode = value
        }
        do {
            let response = try await MekasaAPIClient.shared.captureInventoryItemProduct(
                householdID: householdID,
                itemID: itemID,
                capture: body,
                token: token
            )
            guard var remote = response.inventoryItem else { return nil }
            if case .upc = code, remote.health == nil,
               let refreshed = try? await MekasaAPIClient.shared.refreshInventoryItemHealth(
                   householdID: householdID,
                   itemID: itemID,
                   token: token
               ) {
                remote = refreshed
            }
            if let idx = inventory.firstIndex(where: { $0.id == remote.id }) {
                inventory[idx] = remote.toLocal()
            }
            logActivity("Added code to \(remote.name)", kind: .success)
            return nil
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                handleAPIFailure(error)
                return nil
            }
            return PhotoOnlyCapture.errorMessage(for: error)
        }
    }

    /// Upload a capture photo to the shared product photos (REQ-RCP-021 AC1).
    /// Nil in preview / UI tests and when signed out, so callers fall back to a
    /// private item photo.
    func uploadProductPhoto(_ image: UIImage) async -> ProductPhotoUploadDTO? {
        guard !isUIPreview, !isUITesting, let token = idToken, let householdID = household?.id,
              let jpeg = ItemPhotoEncoding.jpegData(from: image)
        else { return nil }
        do {
            return try await MekasaAPIClient.shared.uploadProductPhoto(
                householdID: householdID,
                imageData: jpeg,
                token: token
            )
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                handleAPIFailure(error)
            }
            return nil
        }
    }
}

/// Downscale + JPEG-encode user photos so uploads stay small.
enum ItemPhotoEncoding {
    static let maxDimension: CGFloat = 1280
    static let quality: CGFloat = 0.75

    static func jpegData(from image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image.jpegData(compressionQuality: quality) }
        let scale = maxDimension / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
