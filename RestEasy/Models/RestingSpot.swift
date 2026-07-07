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
}
