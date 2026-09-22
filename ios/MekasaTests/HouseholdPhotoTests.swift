import XCTest
@testable import Mekasa
import UIKit

final class HouseholdPhotoTests: XCTestCase {
    func testDecodeDataURLPhoto() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        guard let jpeg = image.jpegData(compressionQuality: 0.9) else {
            return XCTFail("jpeg encode")
        }
        let dataURL = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
        XCTAssertNotNil(HouseholdPhotoImage.uiImage(from: dataURL))
        XCTAssertNil(HouseholdPhotoImage.uiImage(from: nil))
        XCTAssertNil(HouseholdPhotoImage.uiImage(from: ""))
    }

    @MainActor
    func testUploadHomePhoto_inUIPreview_updatesSession() async {
        let session = AppSession()
        session.isUIPreview = true
        session.household = PreviewFixtures.household(name: "Photo House")
        let image = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        let ok = await session.uploadHouseholdHomePhoto(image)
        XCTAssertTrue(ok)
        XCTAssertNotNil(session.household?.photoURL)
        XCTAssertTrue(session.household?.photoURL?.hasPrefix("data:image/jpeg;base64,") == true)
    }
}
