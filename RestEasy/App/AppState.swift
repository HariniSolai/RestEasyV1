import SwiftUI

/// Global application state for auth flow and user preferences.
@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var hasCompletedTutorial = false
    @Published var userDisplayName = ""
    @Published var textSizeScale: Double = 1.0
    @Published var isHighContrastEnabled = false
    @Published var mapZoomLevel: Double = AppConstants.defaultMapZoomLevel

    /// Simulates a successful login for demo purposes.
    func login(email: String, password: String) {
        guard !email.isEmpty, !password.isEmpty else { return }
        userDisplayName = email.components(separatedBy: "@").first?.capitalized ?? "User"
        isAuthenticated = true
    }

    /// Simulates account creation for demo purposes.
    func signUp(fullName: String, email: String, password: String) {
        guard !fullName.isEmpty, !email.isEmpty, password.count >= 6 else { return }
        userDisplayName = fullName
        isAuthenticated = true
    }

    func logout() {
        isAuthenticated = false
        hasCompletedTutorial = false
        userDisplayName = ""
    }
}
