import CoreLocation
import Foundation

/// GPS + reverse geocode for onboarding address (REQ-003).
/// Spec version: 1.0
@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var suggestedAddress: String?
    @Published var lastError: String?

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    func detectHomeAddress() async throws -> (address: String, latitude: Double, longitude: Double) {
        if manager.authorizationStatus == .notDetermined {
            requestWhenInUse()
        }
        let location = try await fetchLocation()
        coordinate = location.coordinate
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        let address = Self.format(placemark: placemarks.first) ?? "\(location.coordinate.latitude), \(location.coordinate.longitude)"
        suggestedAddress = address
        return (address, location.coordinate.latitude, location.coordinate.longitude)
    }

    private func fetchLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    private static func format(placemark: CLPlacemark?) -> String? {
        guard let placemark else { return nil }
        let parts = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode,
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            lastError = error.localizedDescription
            locationContinuation?.resume(throwing: error)
            locationContinuation = nil
        }
    }
}
