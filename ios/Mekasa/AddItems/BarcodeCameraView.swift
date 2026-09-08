import AVFoundation
import SwiftUI
import VisionKit

/// Live barcode camera using VisionKit DataScanner (iOS 17+).
/// Satisfies: REQ-004
/// Spec version: 1.0
struct BarcodeCameraView: UIViewControllerRepresentable {
    var onCode: (String) -> Void
    var onError: (String) -> Void

    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        context.coordinator.onCode = onCode
        context.coordinator.onError = onError
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }

    static func dismantleUIViewController(
        _ uiViewController: DataScannerViewController,
        coordinator: Coordinator
    ) {
        uiViewController.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode, onError: onError)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCode: (String) -> Void
        var onError: (String) -> Void
        private var lastCode: String?
        private var lastAt: Date = .distantPast

        init(onCode: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onCode = onCode
            self.onError = onError
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didTapOn item: RecognizedItem
        ) {
            handle(item)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            if let first = addedItems.first {
                handle(first)
            }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            onError(error.localizedDescription)
        }

        private func handle(_ item: RecognizedItem) {
            guard case let .barcode(barcode) = item,
                  let value = barcode.payloadStringValue,
                  !value.isEmpty
            else { return }
            let now = Date()
            if value == lastCode, now.timeIntervalSince(lastAt) < 2 {
                return
            }
            lastCode = value
            lastAt = now
            onCode(value)
        }
    }
}

enum BarcodeCameraPermission {
    static func requestIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
}
