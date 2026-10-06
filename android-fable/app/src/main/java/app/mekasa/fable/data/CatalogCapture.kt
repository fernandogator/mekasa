package app.mekasa.fable.data

import app.mekasa.fable.data.model.ProductCaptureRequest
import app.mekasa.fable.data.model.ReceiptLine

/**
 * A code the shared catalog accepts on capture: UPC (8–14 digits) or PLU (4–5).
 * Satisfies: REQ-RCP-020 AC2, AC7
 * Spec version: 1.0
 */
sealed interface CatalogCode {
    val value: String

    data class Upc(override val value: String) : CatalogCode
    data class Plu(override val value: String) : CatalogCode

    companion object {
        fun parse(raw: String?): CatalogCode? {
            val code = raw?.trim().orEmpty()
            if (code.isEmpty() || !code.all { it in '0'..'9' }) return null
            return when (code.length) {
                in 4..5 -> Plu(code)
                in 8..14 -> Upc(code)
                else -> null
            }
        }
    }
}

/**
 * What the receipt review collected for one line before it saves: an optional
 * typed code, an optional photo, and the receipt text and chain that make the
 * capture an alias for the next scan.
 * Satisfies: REQ-RCP-020 AC6, AC15
 * Spec version: 1.0
 */
data class LineCapture(
    val code: String? = null,
    val photoJpeg: ByteArray? = null,
    val receiptText: String? = null,
    val storeChainId: String? = null,
) {
    /** A code, or receipt text, sends the photo to the shared product photos. */
    val sharesPhoto: Boolean
        get() = CatalogCode.parse(code) != null || (code.isNullOrBlank() && CatalogCapture.alias(receiptText) != null)

    val isPhotoOnly: Boolean
        get() = code.isNullOrBlank() && photoJpeg != null && sharesPhoto

    override fun equals(other: Any?): Boolean =
        other is LineCapture && code == other.code && receiptText == other.receiptText &&
            storeChainId == other.storeChainId && photoJpeg.contentEqualsNullable(other.photoJpeg)

    override fun hashCode(): Int =
        listOf(code, receiptText, storeChainId, photoJpeg?.contentHashCode()).hashCode()
}

private fun ByteArray?.contentEqualsNullable(other: ByteArray?): Boolean =
    if (this == null) other == null else other != null && contentEquals(other)

/**
 * Capture bodies and copy shared by the receipt review and item detail. Pure for unit tests.
 * Satisfies: REQ-RCP-020 AC15, REQ-RCP-021 AC7
 * Spec version: 1.0
 */
object CatalogCapture {
    const val SHARED_PHOTO_LABEL = "Shared photo"
    const val SAVED_CARD_NOTE = "No barcode · matched by receipt text next time"
    const val ADD_CODE_TITLE = "Add barcode or PLU"
    const val ADD_CODE_HINT = "Adding the code lets Mekasa look up nutrition info for this item."
    const val SHARED_LABEL = "Shared with all users"
    const val STEP_COPY = "Your photo will be shown with this product to other Mekasa households. " +
        "Keep people, faces and receipts out of the shot."
    const val SHEET_TITLE = "Product photos are shared"
    const val SHEET_COPY = "Photos you take here are shown with this product to all Mekasa users. " +
        "Item-detail photos stay private to your household. Keep people, faces and receipts out of the shot."

    fun alias(receiptText: String?): String? = receiptText?.trim()?.takeIf { it.isNotEmpty() }?.take(200)

    fun noCodeMessage(storeName: String?): String {
        val store = storeName?.trim().orEmpty()
        val receipts = if (store.isEmpty()) "these receipts" else "$store receipts"
        return "No barcode scanned — the photo and name are shared for $receipts"
    }

    /**
     * The capture to send after the item is created, or null when nothing goes
     * to the catalog: a UPC / PLU with its photo and receipt text, or a shared
     * photo with receipt text and no code.
     */
    fun request(capture: LineCapture, photoId: String?): ProductCaptureRequest? {
        val alias = alias(capture.receiptText)
        return when (val code = CatalogCode.parse(capture.code)) {
            is CatalogCode.Upc -> ProductCaptureRequest(upc = code.value, photoId = photoId, receiptText = alias, storeChainId = capture.storeChainId)
            is CatalogCode.Plu -> ProductCaptureRequest(pluCode = code.value, photoId = photoId, receiptText = alias, storeChainId = capture.storeChainId)
            null -> if (capture.code.isNullOrBlank() && photoId != null && alias != null) {
                ProductCaptureRequest(photoId = photoId, receiptText = alias, storeChainId = capture.storeChainId)
            } else {
                null
            }
        }
    }

    /** The inventory draft for a picked receipt line, carrying its capture when it has one. */
    fun receiptDraft(line: ReceiptLine, capture: LineCapture?): InventoryDraft = InventoryDraft(
        name = line.name,
        category = line.category,
        quantity = line.quantity.coerceAtLeast(1),
        barcode = line.barcode,
        imageUrl = line.imageUrl,
        source = "receipt",
        pricePaid = line.pricePaid,
        capture = capture?.takeIf { CatalogCode.parse(it.code) != null || it.photoJpeg != null },
    )

    fun codeRequest(code: CatalogCode): ProductCaptureRequest = when (code) {
        is CatalogCode.Upc -> ProductCaptureRequest(upc = code.value)
        is CatalogCode.Plu -> ProductCaptureRequest(pluCode = code.value)
    }

    /** `invalid_upc` / `invalid_plu` from the capture API, in plain words. */
    fun errorMessage(detail: String?): String = when {
        detail?.contains("invalid_upc") == true -> "That barcode isn't valid. Barcodes have 8–14 digits."
        detail?.contains("invalid_plu") == true -> "That PLU isn't valid. Produce PLUs have 4 or 5 digits."
        else -> "Couldn't save the code. Try again."
    }
}
