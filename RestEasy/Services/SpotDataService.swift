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
    func addSpot(_ spot: RestingSpot) {
        spots.append(spot)
    }

    /// Returns reviews for a specific spot.
    func reviews(for spotID: UUID) -> [Review] {
        reviews.filter { $0.spotID == spotID }
    }

    private func loadSampleData() {
        spots = [
            RestingSpot(
                id: UUID(),
                name: "Millennium Park Rest Area",
                address: "201 E Randolph St, Chicago, IL",
                directions: "Public restrooms near the Cloud Gate plaza",
                latitude: 41.8826,
                longitude: -87.6226,
                features: [.bench, .park, .shadedLocation, .restroom],
                imageName: nil,
                averageRating: 4.5,
                reviewCount: 12
            ),
            RestingSpot(
                id: UUID(),
                name: "Lincoln Park Nature Boardwalk",
                address: "2400 N Cannon Dr, Chicago, IL",
                directions: "Bench seating along the boardwalk overlooking the pond",
                latitude: 41.9214,
                longitude: -87.6346,
                features: [.bench, .park, .shadedLocation, .seating],
                imageName: nil,
                averageRating: 4.8,
                reviewCount: 21
            ),
            RestingSpot(
                id: UUID(),
                name: "Grant Park Fieldhouse",
                address: "331 E Randolph St, Chicago, IL",
                directions: "Restrooms inside the fieldhouse near Buckingham Fountain",
                latitude: 41.8758,
                longitude: -87.6189,
                features: [.restroom, .accessible, .waterFountain],
                imageName: nil,
                averageRating: 4.0,
                reviewCount: 8
            ),
            RestingSpot(
                id: UUID(),
                name: "Chicago Riverwalk",
                address: "Chicago Riverwalk, Chicago, IL",
                directions: "Seating and restrooms along the river path",
                latitude: 41.8882,
                longitude: -87.6228,
                features: [.restroom, .bench, .seating, .accessible],
                imageName: nil,
                averageRating: 3.9,
                reviewCount: 5
            )
        ]

        reviews = [
            Review(
                id: UUID(),
                spotID: spots[0].id,
                authorName: "Sarah M.",
                rating: 5,
                comment: "Clean restroom and plenty of shaded benches. Great for a break!",
                createdAt: Date().addingTimeInterval(-86_400)
            ),
            Review(
                id: UUID(),
                spotID: spots[0].id,
                authorName: "James K.",
                rating: 4,
                comment: "Nice park area. Restroom was well maintained.",
                createdAt: Date().addingTimeInterval(-172_800)
            ),
            Review(
                id: UUID(),
                spotID: spots[2].id,
                authorName: "Maria L.",
                rating: 5,
                comment: "Beautiful riverside benches. Very peaceful spot to rest.",
                createdAt: Date().addingTimeInterval(-259_200)
            )
        ]
    }
}
