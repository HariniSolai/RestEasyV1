import CoreLocation
import Combine

/// Manages device location and heading for nearby spot discovery and live navigation.
@MainActor
final class LocationManager: NSObject, ObservableObject {
    /// The coordinate used as "you are here" on the map and for routing.
    @Published private(set) var userLocation: CLLocationCoordinate2D = AppConstants.defaultMapCenter

    /// Compass heading in degrees clockwise from true north. `nil` when unavailable.
    @Published private(set) var headingDegrees: CLLocationDirection?

    /// `true` when showing the Chicago default instead of a live GPS fix.
    @Published private(set) var isApproximateLocation = true

    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private var isHeadingActive = false

    /// Simulators default to San Francisco; keep RestEasy centered on Chicago there.
    private var shouldUseChicagoInSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        applyChicagoFallback()
    }

    /// Requests location permission and begins updates when allowed.
    func requestLocation() {
        authorizationStatus = manager.authorizationStatus

        if shouldUseChicagoInSimulator {
            applyChicagoFallback()
            return
        }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            applyChicagoFallback()
        @unknown default:
            applyChicagoFallback()
        }
    }

    /// Starts compass heading updates used during live turn-by-turn guidance.
    func startHeadingUpdates() {
        guard !shouldUseChicagoInSimulator else { return }
        guard CLLocationManager.headingAvailable() else { return }
        isHeadingActive = true
        manager.headingFilter = 5
        manager.startUpdatingHeading()
    }

    /// Stops compass heading updates when live guidance ends.
    func stopHeadingUpdates() {
        isHeadingActive = false
        manager.stopUpdatingHeading()
        headingDegrees = nil
    }

    /// Sets the published location to downtown Chicago for demos and denied GPS.
    private func applyChicagoFallback() {
        userLocation = AppConstants.defaultMapCenter
        isApproximateLocation = true
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus

            if shouldUseChicagoInSimulator {
                applyChicagoFallback()
                return
            }

            switch authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.startUpdatingLocation()
            case .denied, .restricted:
                applyChicagoFallback()
            case .notDetermined:
                break
            @unknown default:
                applyChicagoFallback()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            if shouldUseChicagoInSimulator {
                applyChicagoFallback()
                return
            }

            userLocation = location.coordinate
            isApproximateLocation = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            guard isHeadingActive else { return }
            let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
            guard heading >= 0 else { return }
            headingDegrees = heading
        }
    }

    nonisolated func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("Location error: \(error.localizedDescription)")
            if isApproximateLocation {
                applyChicagoFallback()
            }
        }
    }
}
