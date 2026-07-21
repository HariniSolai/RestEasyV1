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
    private let storage = Storage.storage(url: "gs://resteasy-be034.firebasestorage.app")
    private var spotsListener: ListenerRegistration?
    private var reviewsListener: ListenerRegistration?
    private var firestoreSpots: [RestingSpot] = []
    private var firestoreReviews: [Review] = []

    init() {
        spots = SeedSpots.spots
        mergeReviews()
        startListening()
        startReviewsListening()
    }

    deinit {
        spotsListener?.remove()
        reviewsListener?.remove()
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
    ///   - imagesData: Optional image bytes for one or more spot photos.
    ///   - userID: Firebase Auth UID of the contributor.
    func uploadSpot(_ spot: RestingSpot, imagesData: [Data], userID: String) async throws {
        var spotToUpload = spot
        spotToUpload.createdBy = userID

        if !imagesData.isEmpty {
            spotToUpload.imageURLs = try await uploadImages(imagesData, spotID: spot.id)
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

    /// Saves a user review to Firestore and refreshes the spot's rating summary.
    /// - Parameters:
    ///   - spotID: The resting spot being reviewed.
    ///   - authorName: Display name of the signed-in user.
    ///   - authorUserID: Firebase Auth UID of the reviewer, if available.
    ///   - rating: Star rating from 1 to 5.
    ///   - comment: Written feedback from the user.
    /// - Returns: The newly created review.
    @discardableResult
    func addReview(
        spotID: UUID,
        authorName: String,
        authorUserID: String?,
        rating: Int,
        comment: String
    ) async throws -> Review {
        let clampedRating = min(5, max(1, rating))
        let review = Review(
            id: UUID(),
            spotID: spotID,
            authorName: authorName.isEmpty ? "RestEasy User" : authorName,
            authorUserID: authorUserID,
            rating: clampedRating,
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date()
        )

        try await database
            .collection("reviews")
            .document(review.id.uuidString)
            .setData(review.firestoreData)

        if firestoreReviews.contains(where: { $0.id == review.id }) == false {
            firestoreReviews.insert(review, at: 0)
        }
        mergeReviews()
        try await syncSpotRatingSummaryToFirestore(for: spotID)

        return review
    }

    /// Persists updated rating metadata for user-uploaded Firestore spots.
    /// - Parameter spotID: The resting spot identifier to sync.
    private func syncSpotRatingSummaryToFirestore(for spotID: UUID) async throws {
        guard firestoreSpots.contains(where: { $0.id == spotID }),
              let spotIndex = spots.firstIndex(where: { $0.id == spotID }) else {
            return
        }

        let spot = spots[spotIndex]
        try await database
            .collection("spots")
            .document(spotID.uuidString)
            .updateData([
                "averageRating": spot.averageRating,
                "reviewCount": spot.reviewCount
            ])
    }

    /// Subscribes to shared Firestore spots and merges them with local seed data.
    private func startListening() {
        isLoadingSpots = true

        spotsListener = database.collection("spots").addSnapshotListener { [weak self] snapshot, error in
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

    /// Subscribes to shared Firestore reviews and merges them with bundled seed reviews.
    private func startReviewsListening() {
        reviewsListener = database.collection("reviews").addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let documents = snapshot?.documents else { return }
                self.firestoreReviews = documents.compactMap(Review.init(document:))
                self.mergeReviews()
            }
        }
    }

    /// Combines Firestore reviews with bundled seed reviews.
    private func mergeReviews() {
        var mergedReviews = firestoreReviews
        let firestoreReviewIDs = Set(firestoreReviews.map(\.id))

        for seedReview in SeedSpots.reviews where !firestoreReviewIDs.contains(seedReview.id) {
            mergedReviews.append(seedReview)
        }

        reviews = mergedReviews.sorted { $0.createdAt > $1.createdAt }
        mergeSpots()
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

    /// Uploads one or more spot photos to Firebase Storage.
    /// - Parameters:
    ///   - imagesData: The image bytes selected by the user.
    ///   - spotID: The resting spot identifier used in the storage path.
    /// - Returns: Public download URLs for the uploaded images.
    private func uploadImages(_ imagesData: [Data], spotID: UUID) async throws -> [String] {
        var downloadURLs: [String] = []

        for (index, imageData) in imagesData.enumerated() {
            guard let jpegData = ImageUploadHelper.jpegData(from: imageData) else { continue }

            let imageReference = storage.reference().child("spots/\(spotID.uuidString)/photo_\(index).jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            _ = try await imageReference.putDataAsync(jpegData, metadata: metadata)
            let downloadURL = try await imageReference.downloadURL()
            downloadURLs.append(downloadURL.absoluteString)
        }

        return downloadURLs
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
