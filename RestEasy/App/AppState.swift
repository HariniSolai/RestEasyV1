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
    @Published var textSizeScale: Double = 1.0
    @Published var isHighContrastEnabled = false
    @Published var mapZoomLevel: Double = AppConstants.defaultMapZoomLevel

    private let authService: AuthService
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
