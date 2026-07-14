import Foundation
import CoreLocation
import FirebaseFirestore
import FirebaseStorage

/// Provides resting spot data from seed content and shared Firestore uploads.
@MainActor
final class SpotDataService: ObservableObject {
    @Published private(set) var spots: [RestingSpot] = []
    @Published private(set) var reviews: [Review] = []
    @Published private(set) var isLoadingSpots = false
    @Published var errorMessage: String?

    private let database = Firestore.firestore()
    private let storage = Storage.storage()
    private var listener: ListenerRegistration?
    private var firestoreSpots: [RestingSpot] = []

    init() {
        reviews = SeedSpots.reviews
        spots = SeedSpots.spots
        startListening()
    }

    deinit {
        listener?.remove()
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

    /// Uploads a new resting spot so every signed-in user can see it.
    /// - Parameters:
    ///   - spot: The spot metadata to save.
    ///   - imageData: Optional JPEG/PNG data for the spot photo.
    ///   - userID: Firebase Auth UID of the contributor.
    func uploadSpot(_ spot: RestingSpot, imageData: Data?, userID: String) async throws {
        var spotToUpload = spot
        spotToUpload.createdBy = userID

        if let imageData {
            spotToUpload.imageURL = try await uploadImage(imageData, spotID: spot.id)
        }

        var documentData = spotToUpload.firestoreData
        documentData["createdAt"] = FieldValue.serverTimestamp()

        try await database
            .collection("spots")
            .document(spot.id.uuidString)
            .setData(documentData)
    }

    /// Returns reviews for a specific spot.
    /// - Parameter spotID: The resting spot identifier.
    /// - Returns: Reviews linked to that spot, newest first.
    func reviews(for spotID: UUID) -> [Review] {
        reviews
            .filter { $0.spotID == spotID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Adds a user review and refreshes the spot's rating summary.
    /// - Parameters:
    ///   - spotID: The resting spot being reviewed.
    ///   - authorName: Display name of the signed-in user.
    ///   - rating: Star rating from 1 to 5.
    ///   - comment: Optional written feedback.
    /// - Returns: The newly created review.
    @discardableResult
    func addReview(
        spotID: UUID,
        authorName: String,
        rating: Int,
        comment: String
    ) -> Review {
        let clampedRating = min(5, max(1, rating))
        let review = Review(
            id: UUID(),
            spotID: spotID,
            authorName: authorName.isEmpty ? "RestEasy User" : authorName,
            rating: clampedRating,
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date()
        )

        reviews.insert(review, at: 0)
        updateSpotRatingSummary(for: spotID)
        return review
    }

    /// Recalculates average rating and review count for a spot after a new review.
    /// - Parameter spotID: The resting spot identifier to update.
    private func updateSpotRatingSummary(for spotID: UUID) {
        let spotReviews = reviews(for: spotID)
        guard let spotIndex = spots.firstIndex(where: { $0.id == spotID }) else { return }

        let totalRating = spotReviews.reduce(0) { $0 + $1.rating }
        spots[spotIndex].reviewCount = spotReviews.count
        spots[spotIndex].averageRating = spotReviews.isEmpty
            ? 0
            : Double(totalRating) / Double(spotReviews.count)
    }

    /// Subscribes to shared Firestore spots and merges them with local seed data.
    private func startListening() {
        isLoadingSpots = true

        listener = database.collection("spots").addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoadingSpots = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let documents = snapshot?.documents else { return }
                self.firestoreSpots = documents.compactMap(RestingSpot.init(document:))
                self.mergeSpots()
            }
        }
    }

    /// Combines bundled seed spots with user-uploaded Firestore spots.
    private func mergeSpots() {
        let previousRatings = Dictionary(
            uniqueKeysWithValues: spots.map { ($0.id, ($0.averageRating, $0.reviewCount)) }
        )

        var mergedSpots = SeedSpots.spots
        let seedIDs = Set(mergedSpots.map(\.id))

        for spot in firestoreSpots where !seedIDs.contains(spot.id) {
            mergedSpots.append(spot)
        }

        for index in mergedSpots.indices {
            let spotID = mergedSpots[index].id
            let spotReviews = reviews(for: spotID)
            if !spotReviews.isEmpty {
                let totalRating = spotReviews.reduce(0) { $0 + $1.rating }
                mergedSpots[index].reviewCount = spotReviews.count
                mergedSpots[index].averageRating = Double(totalRating) / Double(spotReviews.count)
            } else if let previous = previousRatings[spotID] {
                mergedSpots[index].averageRating = previous.0
                mergedSpots[index].reviewCount = previous.1
            }
        }

        spots = mergedSpots
    }

    /// Uploads a spot photo to Firebase Storage.
    /// - Parameters:
    ///   - imageData: The image bytes selected by the user.
    ///   - spotID: The resting spot identifier used in the storage path.
    /// - Returns: A public download URL for the uploaded image.
    private func uploadImage(_ imageData: Data, spotID: UUID) async throws -> String {
        let imageReference = storage.reference().child("spots/\(spotID.uuidString)/photo.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await imageReference.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await imageReference.downloadURL()
        return downloadURL.absoluteString
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
}
