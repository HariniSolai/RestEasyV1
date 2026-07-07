import Foundation

/// A user review for a resting spot.
struct Review: Identifiable, Codable {
    let id: UUID
    let spotID: UUID
    let authorName: String
    let rating: Int
    let comment: String
    let createdAt: Date
}
