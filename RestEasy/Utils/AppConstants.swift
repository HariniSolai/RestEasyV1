import CoreLocation

/// Shared app-wide constants for map defaults.
enum AppConstants {
    /// UIC / West Loop — used when the user's location is unavailable.
    static let defaultMapCenter = CLLocationCoordinate2D(latitude: 41.8756, longitude: -87.6505)

    /// City-level span when fully zoomed out.
    static let maxMapSpanDelta = 0.15

    /// Street-level span when fully zoomed in (~one block).
    static let minMapSpanDelta = 0.001

    /// Normalized zoom value: 0 = zoomed out, 1 = street level.
    static let mapZoomRange: ClosedRange<Double> = 0...1

    /// Default zoom that shows the UIC / West Loop neighborhood.
    static let defaultMapZoomLevel = 0.2

    /// Converts a normalized zoom level into a map span delta.
    /// - Parameter zoomLevel: A value from `mapZoomRange`.
    /// - Returns: The latitude/longitude delta for the map camera.
    static func mapSpanDelta(for zoomLevel: Double) -> Double {
        let clampedZoom = min(mapZoomRange.upperBound, max(mapZoomRange.lowerBound, zoomLevel))
        let zoomRatio = minMapSpanDelta / maxMapSpanDelta
        return maxMapSpanDelta * pow(zoomRatio, clampedZoom)
    }
}
