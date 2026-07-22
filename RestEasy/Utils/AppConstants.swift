import CoreLocation
import MapKit

/// Shared app-wide constants for map defaults.
enum AppConstants {
    /// Downtown Chicago / UIC area — used when the user's location is unavailable.
    static let defaultMapCenter = CLLocationCoordinate2D(latitude: 41.8756, longitude: -87.6505)

    /// City-level span when fully zoomed out.
    static let maxMapSpanDelta = 0.15

    /// Street-level span when fully zoomed in (~one block).
    static let minMapSpanDelta = 0.001

    /// Normalized zoom value: 0 = zoomed out, 1 = street level.
    static let mapZoomRange: ClosedRange<Double> = 0...1

    /// Default zoom that shows the UIC / West Loop neighborhood.
    static let defaultMapZoomLevel = 0.2

    /// Share of the map content area reserved for the map when a spot detail panel is open.
    static let spotDetailMapHeightRatio: CGFloat = 0.5

    /// Camera altitude (meters) while following the user during live guidance.
    static let liveNavigationCameraDistance: CLLocationDistance = 350

    /// How far from the route (meters) before RestEasy requests a new path.
    static let liveOffRouteThresholdMeters: CLLocationDistance = 45

    /// How close to a step endpoint (meters) before advancing to the next instruction.
    static let liveStepCompletionRadiusMeters: CLLocationDistance = 25

    /// Minimum seconds between automatic reroute requests.
    static let liveRerouteCooldownSeconds: TimeInterval = 12

    /// Converts a normalized zoom level into a map span delta.
    /// - Parameter zoomLevel: A value from `mapZoomRange`.
    /// - Returns: The latitude/longitude delta for the map camera.
    static func mapSpanDelta(for zoomLevel: Double) -> Double {
        let clampedZoom = min(mapZoomRange.upperBound, max(mapZoomRange.lowerBound, zoomLevel))
        let zoomRatio = minMapSpanDelta / maxMapSpanDelta
        return maxMapSpanDelta * pow(zoomRatio, clampedZoom)
    }

    /// Default Chicago map region used for the initial camera position.
    /// - Returns: An `MKCoordinateRegion` centered on Chicago.
    static var defaultMapRegion: MKCoordinateRegion {
        let delta = mapSpanDelta(for: defaultMapZoomLevel)
        return MKCoordinateRegion(
            center: defaultMapCenter,
            span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
        )
    }
}
