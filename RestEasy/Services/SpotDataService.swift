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
                name: "Highland Park Rest Area",
                address: "Highland Recreation Area, White Lake, MI",
                directions: "Near the main trailhead parking lot",
                latitude: 42.635,
                longitude: -83.555,
                features: [.bench, .park, .shadedLocation, .restroom],
                imageName: nil,
                averageRating: 4.5,
                reviewCount: 12
            ),
            RestingSpot(
                id: UUID(),
                name: "Farmington Hills Community Center",
                address: "28600 W 11 Mile Rd, Farmington Hills, MI",
                directions: "Public restroom on the ground floor near the lobby",
                latitude: 42.461,
                longitude: -83.378,
                features: [.restroom, .accessible, .waterFountain],
                imageName: nil,
                averageRating: 4.0,
                reviewCount: 8
            ),
            RestingSpot(
                id: UUID(),
                name: "Proud Lake State Recreation",
                address: "2100 Wixom Rd, Milford, MI",
                directions: "Bench seating along the river trail",
                latitude: 42.548,
                longitude: -83.512,
                features: [.bench, .park, .shadedLocation, .seating],
                imageName: nil,
                averageRating: 4.8,
                reviewCount: 21
            ),
            RestingSpot(
                id: UUID(),
                name: "Livonia Civic Center Park",
                address: "32150 Five Mile Rd, Livonia, MI",
                directions: "Restrooms in the pavilion building",
                latitude: 42.396,
                longitude: -83.412,
                features: [.restroom, .bench, .park, .accessible],
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
