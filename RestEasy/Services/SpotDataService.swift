import Foundation
import CoreLocation

/// Provides resting spot data and CRUD operations (in-memory for demo).
@MainActor
final class SpotDataService: ObservableObject {
    @Published private(set) var spots: [RestingSpot] = []
    @Published private(set) var reviews: [Review] = []

    init() {
        loadSampleData()
    }

    /// Returns spots sorted by distance from the given coordinate.
    /// - Parameters:
    ///   - coordinate: The center point to search from.
    ///   - radiusMeters: Maximum distance in meters (default 50 km).
    /// - Returns: Nearby spots ordered closest-first.
    func spotsNear(_ coordinate: CLLocationCoordinate2D, radiusMeters: Double = 50_000) -> [RestingSpot] {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return spots
            .filter { spot in
                let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
                return origin.distance(from: spotLocation) <= radiusMeters
            }
            .sorted { lhs, rhs in
                let lhsDist = origin.distance(from: CLLocation(latitude: lhs.latitude, longitude: lhs.longitude))
                let rhsDist = origin.distance(from: CLLocation(latitude: rhs.latitude, longitude: rhs.longitude))
                return lhsDist < rhsDist
            }
    }

    /// Adds a newly uploaded resting spot.
    /// - Parameter spot: The spot to append to the in-memory list.
    func addSpot(_ spot: RestingSpot) {
        spots.append(spot)
    }

    /// Returns reviews for a specific spot.
    /// - Parameter spotID: The resting spot identifier.
    /// - Returns: Reviews linked to that spot.
    func reviews(for spotID: UUID) -> [Review] {
        reviews.filter { $0.spotID == spotID }
    }

    /// Loads hardcoded UIC / West Loop spots from `SeedSpots`.
    private func loadSampleData() {
        spots = SeedSpots.spots
        reviews = SeedSpots.reviews
    }
}
