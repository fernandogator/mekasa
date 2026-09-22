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

    @MainActor
    func testSaveHomePhotoEdits_updatesNameAndPhoto() async {
        let session = AppSession()
        session.isUIPreview = true
        session.household = PreviewFixtures.household(name: "Old Name")
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 24)).image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 24))
        }
        let ok = await session.saveHomePhotoEdits(
            name: "The Guerrero Home",
            image: image,
            nameChanged: true,
            imageChanged: true
        )
        XCTAssertTrue(ok)
        XCTAssertEqual(session.household?.name, "The Guerrero Home")
        XCTAssertNotNil(session.household?.photoURL)
    }

    func testCropCanvas_renderProducesImage() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 100)).image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        }
        let cropped = HomePhotoCropCanvas.render(
            image: image,
            scale: 1.4,
            offset: CGSize(width: 10, height: -5),
            frameSize: CGSize(width: 160, height: 110)
        )
        XCTAssertNotNil(cropped)
<<<<<<< HEAD
        XCTAssertEqual(Double(cropped!.size.width), 160, accuracy: 0.5)
        XCTAssertEqual(Double(cropped!.size.height), 110, accuracy: 0.5)
=======
        XCTAssertEqual(cropped?.size.width, 160, accuracy: 0.5)
        XCTAssertEqual(cropped?.size.height, 110, accuracy: 0.5)
>>>>>>> origin/main
    }
}
