import Contacts
import Foundation
import MapKit
import CoreLocation

/// Provides Apple Maps-style area search with autocomplete suggestions.
@MainActor
final class MapSearchService: NSObject, ObservableObject {
    @Published private(set) var completions: [MKLocalSearchCompletion] = []
    @Published private(set) var searchError: String?

    private let completer = MKLocalSearchCompleter()

    /// Region used to bias both autocomplete and free-text search toward the user.
    private var searchRegion: MKCoordinateRegion = AppConstants.defaultMapRegion

    /// Results farther than this from the preferred point trigger a local retry.
    private let farResultThresholdMeters: CLLocationDistance = 100_000

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.region = searchRegion
    }

    /// Biases autocomplete and free-text results toward the given map region.
    /// - Parameter region: The region to prioritize for suggestions and Enter search.
    func updateSearchRegion(_ region: MKCoordinateRegion) {
        searchRegion = region
        completer.region = region
    }

    /// Updates autocomplete suggestions for the current query fragment.
    /// - Parameter query: The text the user has typed in the search field.
    func updateQuery(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            completions = []
            return
        }
        completer.queryFragment = trimmedQuery
    }

    /// Clears autocomplete suggestions and any prior search error.
    func clearCompletions() {
        completions = []
        searchError = nil
    }

    /// Resolves a map coordinate into a human-readable mailing address.
    /// - Parameter coordinate: The latitude/longitude to reverse geocode.
    /// - Returns: A formatted address string suitable for display in a text field.
    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> String {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else {
            return "Unknown location"
        }
        return formattedAddress(from: placemark)
    }

    /// Resolves an autocomplete suggestion to a map region near the preferred point.
    /// - Parameters:
    ///   - completion: The selected autocomplete result.
    ///   - preferredCoordinate: Location used to pick the nearest match (usually the user).
    /// - Returns: A map region centered on the resolved location, if found.
    func region(
        for completion: MKLocalSearchCompletion,
        near preferredCoordinate: CLLocationCoordinate2D? = nil
    ) async -> MKCoordinateRegion? {
        let request = MKLocalSearch.Request(completion: completion)
        applyLocationBias(to: request, near: preferredCoordinate)
        return await performSearch(request: request, near: preferredCoordinate)
    }

    /// Geocodes a free-form search query into the nearest matching map region.
    /// - Parameters:
    ///   - query: The place name or address to search for.
    ///   - preferredCoordinate: Location used to prefer nearby duplicates (usually the user).
    /// - Returns: A map region centered on the closest relevant result, if found.
    func region(
        for query: String,
        near preferredCoordinate: CLLocationCoordinate2D? = nil
    ) async -> MKCoordinateRegion? {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return nil }

        let preferredCenter = preferredCoordinate ?? searchRegion.center

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmedQuery
        applyLocationBias(to: request, near: preferredCenter)

        if let region = await performSearch(request: request, near: preferredCenter) {
            let resultLocation = CLLocation(
                latitude: region.center.latitude,
                longitude: region.center.longitude
            )
            let preferredLocation = CLLocation(
                latitude: preferredCenter.latitude,
                longitude: preferredCenter.longitude
            )

            if resultLocation.distance(from: preferredLocation) <= farResultThresholdMeters {
                return region
            }
        }

        // If MapKit still ranked a far-away duplicate first, retry with a local hint.
        let localRetry = MKLocalSearch.Request()
        localRetry.naturalLanguageQuery = localBiasedQuery(from: trimmedQuery, near: preferredCenter)
        applyLocationBias(to: localRetry, near: preferredCenter)
        return await performSearch(request: localRetry, near: preferredCenter)
    }

    /// Applies the current map/user region so MapKit prefers nearby places.
    /// - Parameters:
    ///   - request: The MapKit search request to update.
    ///   - preferredCoordinate: Optional override for the bias center.
    private func applyLocationBias(
        to request: MKLocalSearch.Request,
        near preferredCoordinate: CLLocationCoordinate2D?
    ) {
        let center = preferredCoordinate ?? searchRegion.center
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 80_000,
            longitudinalMeters: 80_000
        )
        request.resultTypes = [.pointOfInterest, .address]
    }

    /// Runs a MapKit search and returns a region for the nearest matching place.
    /// - Parameters:
    ///   - request: The configured local search request.
    ///   - preferredCoordinate: Location used to choose among duplicate names.
    /// - Returns: A camera region for the closest result, if any.
    private func performSearch(
        request: MKLocalSearch.Request,
        near preferredCoordinate: CLLocationCoordinate2D?
    ) async -> MKCoordinateRegion? {
        searchError = nil
        let search = MKLocalSearch(request: request)
        let preferredCenter = preferredCoordinate ?? searchRegion.center

        do {
            let response = try await search.start()
            guard !response.mapItems.isEmpty else {
                searchError = "No results found for that search."
                return nil
            }

            let mapItem = nearestMapItem(in: response.mapItems, to: preferredCenter)
                ?? response.mapItems[0]
            return coordinateRegion(for: mapItem)
        } catch {
            searchError = error.localizedDescription
            return nil
        }
    }

    /// Picks the map item closest to a preferred coordinate.
    /// - Parameters:
    ///   - mapItems: Candidate places returned by MapKit.
    ///   - coordinate: The user's (or map) location.
    /// - Returns: The nearest map item, if the list is non-empty.
    private func nearestMapItem(
        in mapItems: [MKMapItem],
        to coordinate: CLLocationCoordinate2D
    ) -> MKMapItem? {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        return mapItems.min { leftItem, rightItem in
            let leftLocation = CLLocation(
                latitude: leftItem.placemark.coordinate.latitude,
                longitude: leftItem.placemark.coordinate.longitude
            )
            let rightLocation = CLLocation(
                latitude: rightItem.placemark.coordinate.latitude,
                longitude: rightItem.placemark.coordinate.longitude
            )
            return origin.distance(from: leftLocation) < origin.distance(from: rightLocation)
        }
    }

    /// Builds a locally biased query when the first search lands too far away.
    /// - Parameters:
    ///   - query: The original search text.
    ///   - coordinate: The preferred nearby coordinate.
    /// - Returns: A query string that nudges MapKit toward the local city.
    private func localBiasedQuery(
        from query: String,
        near coordinate: CLLocationCoordinate2D
    ) -> String {
        let chicago = AppConstants.defaultMapCenter
        let isNearChicagoDefault =
            abs(coordinate.latitude - chicago.latitude) < 0.5 &&
            abs(coordinate.longitude - chicago.longitude) < 0.5

        if isNearChicagoDefault {
            return "\(query), Chicago, IL"
        }

        return "\(query) near \(coordinate.latitude), \(coordinate.longitude)"
    }

    /// Converts a MapKit placemark region into an `MKCoordinateRegion`.
    /// - Parameter mapItem: The map item returned by a local search.
    /// - Returns: A coordinate region suitable for updating the map camera.
    private func coordinateRegion(for mapItem: MKMapItem) -> MKCoordinateRegion {
        let coordinate = mapItem.placemark.coordinate

        if let circularRegion = mapItem.placemark.region as? CLCircularRegion {
            let metersPerDegree = 111_000.0
            let delta = max(circularRegion.radius / metersPerDegree * 2.5, 0.02)
            return MKCoordinateRegion(
                center: circularRegion.center,
                span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
            )
        }

        return MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    }

    /// Formats a geocoded placemark into a single-line address.
    /// - Parameter placemark: The reverse-geocoding result.
    /// - Returns: A mailing-style address, or a fallback label when fields are missing.
    private func formattedAddress(from placemark: CLPlacemark) -> String {
        if let postalAddress = placemark.postalAddress {
            return CNPostalAddressFormatter.string(from: postalAddress, style: .mailingAddress)
                .replacingOccurrences(of: "\n", with: ", ")
        }

        var parts: [String] = []
        if let subThoroughfare = placemark.subThoroughfare,
           let thoroughfare = placemark.thoroughfare {
            parts.append("\(subThoroughfare) \(thoroughfare)")
        } else if let thoroughfare = placemark.thoroughfare {
            parts.append(thoroughfare)
        }
        if let locality = placemark.locality {
            parts.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            parts.append(administrativeArea)
        }
        if let postalCode = placemark.postalCode {
            parts.append(postalCode)
        }

        return parts.isEmpty ? "Unknown location" : parts.joined(separator: ", ")
    }
}

extension MapSearchService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            completions = completer.results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            completions = []
            searchError = error.localizedDescription
        }
    }
}
