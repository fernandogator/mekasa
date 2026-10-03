import SnapshotTesting
import UIKit
import XCTest

/// Snapshot helper: skips cleanly when a baseline has not been recorded yet.
///
/// Record mode: run with `MEKASA_RECORD_SNAPSHOTS=1` in the test process
/// (`scripts/record_snapshots.sh` does this via `TEST_RUNNER_…`). Every test then
/// writes its PNG under `__Snapshots__/<TestClass>/` and is reported as failed by
/// swift-snapshot-testing — that is expected; re-run without the flag to verify.
enum MekasaSnapshots {
    static var isRecording: Bool {
        let value = ProcessInfo.processInfo.environment["MEKASA_RECORD_SNAPSHOTS"] ?? ""
        return value == "1" || value.lowercased() == "true"
    }

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
        if !isRecording, !FileManager.default.fileExists(atPath: reference.path) {
            throw XCTSkip(
                "Baseline missing at \(reference.path). On a Mac: ios/scripts/record_snapshots.sh, review PNGs, commit."
            )
        }
        assertSnapshot(
            of: value,
            as: snapshotting,
            named: nil,
            record: isRecording,
            timeout: 5,
            file: file,
            testName: testName,
            line: line
        )
    }
}
