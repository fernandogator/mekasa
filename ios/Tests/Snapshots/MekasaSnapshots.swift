import SnapshotTesting
import UIKit
import XCTest

/// Snapshot helper: skips cleanly when a baseline has not been recorded yet.
enum MekasaSnapshots {
    static func assertScreen(
        of value: UIViewController,
        as snapshotting: Snapshotting<UIViewController, UIImage>,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) throws {
        let fileURL = URL(fileURLWithPath: "\(file)", isDirectory: false)
        let className = fileURL.deletingPathExtension().lastPathComponent
        let snapshotsDir = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__", isDirectory: true)
            .appendingPathComponent(className, isDirectory: true)
        let baseName = String(testName.prefix(while: { $0 != "(" }))
        let reference = snapshotsDir.appendingPathComponent("\(baseName).png")
        if !FileManager.default.fileExists(atPath: reference.path) {
            throw XCTSkip(
                "Baseline missing at \(reference.path). On a Mac: record once with isRecording, commit PNG, keep record=false."
            )
        }
        assertSnapshot(
            of: value,
            as: snapshotting,
            named: nil,
            record: false,
            timeout: 5,
            file: file,
            testName: testName,
            line: line
        )
    }
}
