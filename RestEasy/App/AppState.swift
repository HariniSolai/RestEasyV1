import Combine
import SwiftUI

/// Global application state for auth flow and user preferences.
@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var hasCompletedTutorial = false
    @Published var userDisplayName = ""
    @Published var userEmail = ""
    @Published var userPhotoURL: URL?
    @Published var authErrorMessage: String?
    @Published var isAuthLoading = false
    @Published var isSubmittingReport = false
    @Published var reportErrorMessage: String?
    @Published var textSizeScale: Double = 1.0
    @Published var isHighContrastEnabled = false
    @Published var mapZoomLevel: Double = AppConstants.defaultMapZoomLevel

    private let authService: AuthService
    private let accountDeletionService = AccountDeletionService()
    private let contentReportService = ContentReportService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        authService = AuthService()
        bindAuthService()
    }

    /// Firebase Auth UID for the signed-in user.
    var currentUserID: String? {
        authService.currentUserID
    }

    /// Signs in with email and password.
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's password.
    func login(email: String, password: String) async {
        await authService.signIn(email: email, password: password)
        authErrorMessage = authService.errorMessage
    }

    /// Creates a new account with email and password.
    /// - Parameters:
    ///   - fullName: The display name shown in the app.
    ///   - email: The user's email address.
    ///   - password: The user's password.
    func signUp(fullName: String, email: String, password: String) async {
        await authService.signUp(fullName: fullName, email: email, password: password)
        authErrorMessage = authService.errorMessage
    }

    /// Signs in with Google.
    func signInWithGoogle() async {
        await authService.signInWithGoogle()
        authErrorMessage = authService.errorMessage
    }

    /// Signs in with Apple.
    func signInWithApple() async {
        await authService.signInWithApple()
        authErrorMessage = authService.errorMessage
    }

    /// Sends a password reset email.
    /// - Parameter email: The account email address.
    func sendPasswordReset(email: String) async {
        await authService.sendPasswordReset(email: email)
        authErrorMessage = authService.errorMessage
    }

    /// Updates the signed-in user's display name.
    /// - Parameter displayName: The new name shown on profile and reviews.
    func updateDisplayName(_ displayName: String) async {
        await authService.updateDisplayName(displayName)
        authErrorMessage = authService.errorMessage
    }

    /// Uploads a new profile photo for the signed-in user.
    /// - Parameter imageData: Raw image bytes from the photo picker.
    func updateProfilePhoto(imageData: Data) async {
        await authService.updateProfilePhoto(imageData: imageData)
        authErrorMessage = authService.errorMessage
    }

    /// Signs the current user out.
    func logout() {
        authService.signOut()
        hasCompletedTutorial = false
        authErrorMessage = authService.errorMessage
    }

    /// Submits a manual account deletion request to Firestore for admin review.
    /// - Returns: `true` when the request was saved successfully.
    func requestAccountDeletion() async -> Bool {
        guard let userID = currentUserID else {
            authErrorMessage = "You must be signed in to request account deletion."
            return false
        }

        isAuthLoading = true
        authErrorMessage = nil
        defer { isAuthLoading = false }

        do {
            try await accountDeletionService.submitDeletionRequest(
                userID: userID,
                email: userEmail,
                displayName: userDisplayName
            )
            return true
        } catch {
            authErrorMessage = error.localizedDescription
            return false
        }
    }

    /// Submits a content report for manual review in Firebase Console.
    /// - Parameters:
    ///   - target: Whether the report targets a spot or a review.
    ///   - spot: The resting spot being reported.
    ///   - review: Optional review being reported.
    ///   - reason: The selected report reason.
    ///   - details: Optional additional notes from the reporter.
    /// - Returns: `true` when the report was saved successfully.
    func submitContentReport(
        target: ContentReportTarget,
        spot: RestingSpot,
        review: Review?,
        reason: ContentReportReason,
        details: String
    ) async -> Bool {
        isSubmittingReport = true
        reportErrorMessage = nil
        defer { isSubmittingReport = false }

        do {
            try await contentReportService.submitReport(
                target: target,
                spotID: spot.id,
                spotName: spot.name,
                reviewID: review?.id,
                reviewComment: review?.comment,
                reason: reason,
                details: details,
                reporterUserID: currentUserID
            )
            return true
        } catch {
            reportErrorMessage = error.localizedDescription
            return false
        }
    }

    /// Mirrors auth state from `AuthService` into view-friendly published properties.
    private func bindAuthService() {
        authService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAuthenticated)

        authService.$userDisplayName
            .receive(on: DispatchQueue.main)
            .assign(to: &$userDisplayName)

        authService.$userEmail
            .receive(on: DispatchQueue.main)
            .assign(to: &$userEmail)

        authService.$userPhotoURL
            .receive(on: DispatchQueue.main)
            .assign(to: &$userPhotoURL)

        authService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAuthLoading)

        authService.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$authErrorMessage)
    }
}
