import CoreLocation

/// Shared app-wide constants for map defaults.
enum AppConstants {
    /// Downtown Chicago — used when the user's location is unavailable.
    static let defaultMapCenter = CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298)
}
