import Foundation
import CoreLocation
import MapKit

/// A user-contributed resting spot or restroom location.
struct RestingSpot: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var address: String
    var directions: String?
    var latitude: Double
    var longitude: Double
    var features: [SpotFeature]
    var imageName: String?
    var averageRating: Double
    var reviewCount: Int

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var mapItem: MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = name
        return item
    }
}

/// Amenities available at a resting spot.
enum SpotFeature: String, Codable, CaseIterable, Identifiable {
    case bench = "Bench"
    case park = "Park"
    case shadedLocation = "Shaded Location"
    case restroom = "Restroom"
    case waterFountain = "Water Fountain"
    case accessible = "Accessible"
    case seating = "Seating"

    var id: String { rawValue }

    /// SF Symbol used on filter chips and search suggestions.
    var systemImage: String {
        switch self {
        case .bench: return "seat"
        case .park: return "leaf.fill"
        case .shadedLocation: return "cloud.sun.fill"
        case .restroom: return "toilet"
        case .waterFountain: return "drop.fill"
        case .accessible: return "figure.roll"
        case .seating: return "sofa.fill"
        }
    }

    /// Extra words users might type when searching for this amenity.
    var searchKeywords: [String] {
        switch self {
        case .bench: return ["bench", "benches"]
        case .park: return ["park", "parks", "green space"]
        case .shadedLocation: return ["shade", "shaded", "tree", "trees"]
        case .restroom: return ["restroom", "restrooms", "bathroom", "bathrooms", "toilet", "toilets"]
        case .waterFountain: return ["water", "fountain", "drink", "drinking"]
        case .accessible: return ["accessible", "accessibility", "ada", "wheelchair"]
        case .seating: return ["seat", "seating", "sit", "chairs"]
        }
    }

    /// Returns whether a free-text query refers to this amenity.
    /// - Parameter query: The user's search text.
    /// - Returns: `true` when the query matches this feature's name or keywords.
    func matches(query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return false }
        if rawValue.lowercased().contains(normalizedQuery) { return true }
        return searchKeywords.contains { keyword in
            keyword.contains(normalizedQuery) || normalizedQuery.contains(keyword)
        }
    }

    /// Features whose names/keywords match a search query.
    /// - Parameter query: The user's search text.
    /// - Returns: Matching amenities for filter suggestions.
    static func features(matching query: String) -> [SpotFeature] {
        allCases.filter { $0.matches(query: query) }
    }
}
