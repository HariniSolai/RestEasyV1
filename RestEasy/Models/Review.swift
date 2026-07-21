import FirebaseFirestore
import Foundation

/// A user review for a resting spot.
struct Review: Identifiable, Codable {
    let id: UUID
    let spotID: UUID
    let authorName: String
    let authorUserID: String?
    let rating: Int
    let comment: String
    let createdAt: Date
}

extension Review {
    /// Builds a review from a Firestore document.
    /// - Parameter document: A document from the `reviews` collection.
    /// - Returns: A decoded review, or `nil` when required fields are missing.
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let spotIDString = data["spotID"] as? String,
              let spotID = UUID(uuidString: spotIDString),
              let authorName = data["authorName"] as? String,
              let rating = data["rating"] as? Int,
              let comment = data["comment"] as? String else {
            return nil
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        self.init(
            id: id,
            spotID: spotID,
            authorName: authorName,
            authorUserID: data["authorUserID"] as? String,
            rating: rating,
            comment: comment,
            createdAt: createdAt
        )
    }

    /// Serializes the review for Firestore storage.
    /// - Returns: A dictionary suitable for `setData`.
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id.uuidString,
            "spotID": spotID.uuidString,
            "authorName": authorName,
            "rating": rating,
            "comment": comment,
            "createdAt": FieldValue.serverTimestamp()
        ]

        if let authorUserID {
            data["authorUserID"] = authorUserID
        }

        return data
    }
}
