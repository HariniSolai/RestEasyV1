import FirebaseFirestore
import Foundation

/// Submits content reports for manual review in Firebase Console.
@MainActor
final class ContentReportService {
    private static let collectionName = "contentReports"
    private static let adminEmail = "resteasyteam3@gmail.com"

    private let database = Firestore.firestore()

    /// Writes a pending content report for admin review.
    /// - Parameters:
    ///   - target: Whether the report targets a spot or a review.
    ///   - spotID: The resting spot identifier.
    ///   - spotName: Display name of the resting spot.
    ///   - reviewID: Optional review identifier when reporting a review.
    ///   - reviewComment: Optional snapshot of the reported review text.
    ///   - reason: The selected report reason.
    ///   - details: Optional additional notes from the reporter.
    ///   - reporterUserID: Firebase Auth UID when the reporter is signed in.
    func submitReport(
        target: ContentReportTarget,
        spotID: UUID,
        spotName: String,
        reviewID: UUID?,
        reviewComment: String?,
        reason: ContentReportReason,
        details: String,
        reporterUserID: String?
    ) async throws {
        let normalizedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        var reportData: [String: Any] = [
            "contentType": target.rawValue,
            "spotID": spotID.uuidString,
            "spotName": spotName,
            "reason": reason.rawValue,
            "status": "pending",
            "adminEmail": Self.adminEmail,
            "reportedAt": FieldValue.serverTimestamp()
        ]

        if let reviewID {
            reportData["reviewID"] = reviewID.uuidString
        }
        if let reviewComment, !reviewComment.isEmpty {
            reportData["reviewComment"] = reviewComment
        }
        if !normalizedDetails.isEmpty {
            reportData["details"] = normalizedDetails
        }
        if let reporterUserID {
            reportData["reporterUserID"] = reporterUserID
        }

        try await database
            .collection(Self.collectionName)
            .document(UUID().uuidString)
            .setData(reportData)
    }
}
