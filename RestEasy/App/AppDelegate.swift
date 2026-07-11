import GoogleSignIn
import UIKit

/// Handles app lifecycle callbacks required by Google Sign-In.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Routes Google Sign-In callback URLs back to the SDK.
    /// - Returns: `true` when Google Sign-In handled the URL.
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}
