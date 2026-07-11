import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

/// Handles Firebase Authentication for email, Google, and Apple sign-in.
@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var userDisplayName = ""
    @Published private(set) var currentUserID: String?
    @Published var errorMessage: String?
    @Published var isLoading = false

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var appleSignInCoordinator: AppleSignInCoordinator?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.updateSession(with: user)
            }
        }
        updateSession(with: Auth.auth().currentUser)
    }

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
    }

    /// Signs in with email and password.
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's password.
    func signIn(email: String, password: String) async {
        await performAuthOperation {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        }
    }

    /// Creates a new account with email and password.
    /// - Parameters:
    ///   - fullName: The display name shown in the app.
    ///   - email: The user's email address.
    ///   - password: The user's password (minimum 6 characters).
    func signUp(fullName: String, email: String, password: String) async {
        await performAuthOperation {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = fullName
            try await changeRequest.commitChanges()
        }
    }

    /// Signs in with the user's Google account.
    func signInWithGoogle() async {
        await performAuthOperation {
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw AuthServiceError.missingGoogleClientID
            }

            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            guard let presentingViewController = Self.topViewController() else {
                throw AuthServiceError.missingPresentationContext
            }

            let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            guard let idToken = signInResult.user.idToken?.tokenString else {
                throw AuthServiceError.missingGoogleToken
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: signInResult.user.accessToken.tokenString
            )
            _ = try await Auth.auth().signIn(with: credential)
        }
    }

    /// Signs in with the user's Apple ID.
    func signInWithApple() async {
        await performAuthOperation {
            let appleCredential = try await self.requestAppleCredential()
            let credential = OAuthProvider.appleCredential(
                withIDToken: appleCredential.idToken,
                rawNonce: appleCredential.nonce,
                fullName: appleCredential.fullName
            )

            let result = try await Auth.auth().signIn(with: credential)
            if result.user.displayName?.isEmpty != false,
               let fullName = appleCredential.fullName {
                let displayName = PersonNameComponentsFormatter().string(from: fullName)
                guard !displayName.isEmpty else { return }

                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()
            }
        }
    }

    /// Sends a password reset email to the given address.
    /// - Parameter email: The account email address.
    func sendPasswordReset(email: String) async {
        await performAuthOperation {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        }
    }

    /// Signs the current user out of Firebase.
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Updates published auth state from the current Firebase user.
    /// - Parameter user: The signed-in Firebase user, if any.
    private func updateSession(with user: User?) {
        isAuthenticated = user != nil
        currentUserID = user?.uid
        userDisplayName = user?.displayName
            ?? user?.email?.components(separatedBy: "@").first?.capitalized
            ?? ""
    }

    /// Runs an auth operation with shared loading and error handling.
    /// - Parameter operation: The Firebase auth work to perform.
    private func performAuthOperation(_ operation: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil

        do {
            try await operation()
        } catch {
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                // User dismissed the Apple sheet; no alert needed.
            } else if (error as NSError).code == GIDSignInError.canceled.rawValue {
                // User dismissed the Google sheet; no alert needed.
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    /// Presents Sign in with Apple and returns the credential payload.
    /// - Returns: Token, nonce, and optional full name for Firebase.
    private func requestAppleCredential() async throws -> AppleCredentialPayload {
        try await withCheckedThrowingContinuation { continuation in
            let coordinator = AppleSignInCoordinator { result in
                continuation.resume(with: result)
            }
            self.appleSignInCoordinator = coordinator
            coordinator.startSignIn()
        }
    }

    /// Returns the top-most view controller for presenting Google Sign-In.
    /// - Returns: A view controller suitable for modal presentation.
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes
            .flatMap(\.windows)
            .first { $0.isKeyWindow }

        var controller = keyWindow?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}

private enum AuthServiceError: LocalizedError {
    case missingGoogleClientID
    case missingPresentationContext
    case missingGoogleToken
    case missingAppleToken

    var errorDescription: String? {
        switch self {
        case .missingGoogleClientID:
            return "Google Sign-In is not configured for this app."
        case .missingPresentationContext:
            return "Unable to present the sign-in screen."
        case .missingGoogleToken:
            return "Google did not return a valid sign-in token."
        case .missingAppleToken:
            return "Apple did not return a valid sign-in token."
        }
    }
}

private struct AppleCredentialPayload {
    let idToken: String
    let nonce: String
    let fullName: PersonNameComponents?
}

/// Coordinates the native Sign in with Apple sheet.
private final class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    private let completion: (Result<AppleCredentialPayload, Error>) -> Void
    private var currentNonce = ""

    init(completion: @escaping (Result<AppleCredentialPayload, Error>) -> Void) {
        self.completion = completion
    }

    /// Starts the Sign in with Apple authorization flow.
    func startSignIn() {
        currentNonce = Self.randomNonceString()
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(currentNonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            completion(.failure(AuthServiceError.missingAppleToken))
            return
        }

        completion(.success(
            AppleCredentialPayload(
                idToken: idToken,
                nonce: currentNonce,
                fullName: credential.fullName
            )
        ))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }

    /// Generates a random nonce string for Apple Sign-In.
    /// - Parameter length: Number of characters to generate.
    /// - Returns: A cryptographically random nonce.
    private static func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            if errorCode != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with code \(errorCode)")
            }

            randomBytes.forEach { byte in
                guard remainingLength > 0 else { return }
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    /// Returns the SHA-256 hash of the input string.
    /// - Parameter input: The nonce to hash.
    /// - Returns: A lowercase hex-encoded SHA-256 digest.
    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }
}
