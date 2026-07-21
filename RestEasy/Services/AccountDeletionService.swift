import FirebaseFirestore
import Foundation

/// Submits account deletion requests for manual review in Firebase Console.
@MainActor
final class AccountDeletionService {
    private static let collectionName = "accountDeletionRequests"
    private static let adminEmail = "resteasyteam3@gmail.com"

    private let database = Firestore.firestore()

    /// Writes a pending deletion request for the signed-in user.
    /// - Parameters:
    ///   - userID: Firebase Auth UID for the account to delete.
    ///   - email: The user's email address, if available.
    ///   - displayName: The user's profile display name.
    func submitDeletionRequest(userID: String, email: String, displayName: String) async throws {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        let requestData: [String: Any] = [
            "userId": userID,
            "email": normalizedEmail.isEmpty ? "unknown" : normalizedEmail,
            "displayName": normalizedDisplayName.isEmpty ? "RestEasy Member" : normalizedDisplayName,
            "status": "pending",
            "adminEmail": Self.adminEmail,
            "requestedAt": FieldValue.serverTimestamp()
        ]

        try await database
            .collection(Self.collectionName)
            .document(userID)
            .setData(requestData)
    }
}
