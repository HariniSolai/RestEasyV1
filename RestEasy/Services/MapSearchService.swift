import Foundation
import MapKit
import CoreLocation

/// Provides Apple Maps-style area search with autocomplete suggestions.
@MainActor
final class MapSearchService: NSObject, ObservableObject {
    @Published private(set) var completions: [MKLocalSearchCompletion] = []
    @Published private(set) var searchError: String?

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    /// Biases autocomplete results toward the given map region.
    /// - Parameter region: The region to prioritize for suggestions.
    func updateSearchRegion(_ region: MKCoordinateRegion) {
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

    /// Resolves an autocomplete suggestion to a map region.
    /// - Parameter completion: The selected autocomplete result.
    /// - Returns: A map region centered on the resolved location, if found.
    func region(for completion: MKLocalSearchCompletion) async -> MKCoordinateRegion? {
        await performSearch(request: MKLocalSearch.Request(completion: completion))
    }

    /// Geocodes a free-form search query into a map region.
    /// - Parameter query: The place name or address to search for.
    /// - Returns: A map region centered on the resolved location, if found.
    func region(for query: String) async -> MKCoordinateRegion? {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return nil }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmedQuery
        return await performSearch(request: request)
    }

    private func performSearch(request: MKLocalSearch.Request) async -> MKCoordinateRegion? {
        searchError = nil
        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            guard let mapItem = response.mapItems.first else {
                searchError = "No results found for that search."
                return nil
            }

            return coordinateRegion(for: mapItem)
        } catch {
            searchError = error.localizedDescription
            return nil
        }
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
