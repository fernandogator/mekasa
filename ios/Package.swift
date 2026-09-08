// swift-tools-version: 5.9
import PackageDescription

/// SPM dependencies for Mekasa iOS.
/// The Xcode project is generated from `project.yml` (XcodeGen); keep package
/// URLs/versions in sync between this file and `project.yml`.
let package = Package(
    name: "Mekasa",
    platforms: [.iOS(.v17)],
    products: [],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "11.6.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "8.0.0"),
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing",
            from: "1.15.0"
        ),
    ],
    targets: []
)
