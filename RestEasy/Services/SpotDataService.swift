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

    /// Returns nearby spots, optionally filtered by amenity tags and free-text query.
    /// - Parameters:
    ///   - coordinate: The center point to search from.
    ///   - radiusMeters: Maximum distance in meters (default 50 km).
    ///   - requiredFeatures: When non-empty, only spots that include all of these tags.
    ///   - query: Optional text matched against name, address, directions, and feature tags.
    /// - Returns: Nearby spots ordered closest-first.
    func spotsNear(
        _ coordinate: CLLocationCoordinate2D,
        radiusMeters: Double = 50_000,
        requiredFeatures: Set<SpotFeature> = [],
        query: String = ""
    ) -> [RestingSpot] {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return spots
            .filter { spot in
                let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
                guard origin.distance(from: spotLocation) <= radiusMeters else { return false }
                guard matchesRequiredFeatures(spot, requiredFeatures: requiredFeatures) else { return false }
                guard matchesQuery(spot, query: normalizedQuery) else { return false }
                return true
            }
            .sorted { lhs, rhs in
                let lhsDist = origin.distance(from: CLLocation(latitude: lhs.latitude, longitude: lhs.longitude))
                let rhsDist = origin.distance(from: CLLocation(latitude: rhs.latitude, longitude: rhs.longitude))
                return lhsDist < rhsDist
            }
    }

    /// Adds a newly uploaded resting spot, including any amenity tags the user selected.
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

    /// Returns whether a spot includes every selected amenity filter.
    /// - Parameters:
    ///   - spot: The resting spot to evaluate.
    ///   - requiredFeatures: Amenity tags that must all be present.
    /// - Returns: `true` when no filters are active or the spot has all of them.
    private func matchesRequiredFeatures(
        _ spot: RestingSpot,
        requiredFeatures: Set<SpotFeature>
    ) -> Bool {
        guard !requiredFeatures.isEmpty else { return true }
        return requiredFeatures.isSubset(of: Set(spot.features))
    }

    /// Returns whether a spot matches free-text search across name, address, and tags.
    /// - Parameters:
    ///   - spot: The resting spot to evaluate.
    ///   - query: Normalized search text.
    /// - Returns: `true` when the query is empty or matches spot content/tags.
    private func matchesQuery(_ spot: RestingSpot, query: String) -> Bool {
        guard !query.isEmpty else { return true }

        let loweredQuery = query.lowercased()
        if spot.name.lowercased().contains(loweredQuery) { return true }
        if spot.address.lowercased().contains(loweredQuery) { return true }
        if let directions = spot.directions?.lowercased(), directions.contains(loweredQuery) {
            return true
        }

        return spot.features.contains { feature in
            feature.matches(query: query)
        }
    }

    /// Loads hardcoded UIC / West Loop spots from `SeedSpots`.
    private func loadSampleData() {
        spots = SeedSpots.spots
        reviews = SeedSpots.reviews
    }
}
