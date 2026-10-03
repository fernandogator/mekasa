import UIKit

/// What an in-store capture produced for an unidentified receipt line.
struct LocalItemCaptureResult: Equatable {
    var barcode: String?
    /// Uploaded photo URL (nil when no photo was taken or the upload failed).
    var photoURL: String?
    /// Catalog hit for the scanned barcode, when Open Food Facts knows it.
    var lookup: BarcodeLookupDTO?
}

/// User item photos: replace any item picture and in-store captures (REQ-004 / REQ-005).
/// Spec version: 1.0
extension AppSession {
    /// Upload the user's own picture and return its URL for `imageURL`.
    /// Preview / UI-test sessions return a local data URL (never synced).
    func uploadItemPhoto(_ image: UIImage) async -> String? {
        guard let jpeg = ItemPhotoEncoding.jpegData(from: image) else {
            lastError = "Couldn’t encode that photo."
            return nil
        }
        if isUIPreview || isUITesting {
            return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
        }
        guard let token = idToken, let householdID = household?.id else {
            lastError = "Sign in to your household to use your own photos."
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
                lastError = "Couldn’t upload that photo."
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
                lastError = "Couldn’t save the new photo."
            }
            return false
        }
    }

    /// Send an in-store capture for a receipt line the catalog could not identify:
    /// the scanned barcode / PLU and photo go to the store's shared table, and the
    /// barcode is looked up in case Open Food Facts knows it by code.
    func captureUnidentifiedItem(
        store: ReceiptStoreContext?,
        storeItemID: String?,
        barcode: String?,
        image: UIImage?
    ) async -> LocalItemCaptureResult? {
        let code = barcode.flatMap { $0.isEmpty ? nil : $0 }
        var result = LocalItemCaptureResult(barcode: code)
        guard let token = idToken, let householdID = household?.id, !isUIPreview, !isUITesting else {
            if let image { result.photoURL = await uploadItemPhoto(image) }
            return result
        }
        do {
            if let store, let storeItemID {
                let jpeg = image.flatMap { ItemPhotoEncoding.jpegData(from: $0) }
                let row = try await MekasaAPIClient.shared.captureStoreItem(
                    householdID: householdID,
                    storeID: store.storeID,
                    storeItemID: storeItemID,
                    barcode: code,
                    imageData: jpeg,
                    token: token
                )
                result.photoURL = row.photoUrl
            } else if let image {
                result.photoURL = await uploadItemPhoto(image)
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
        } catch {
            if SessionExpiry.isUnauthorized(error) {
                handleAPIFailure(error)
            } else {
                lastError = "Couldn’t save the scan. Check your connection and try again."
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
