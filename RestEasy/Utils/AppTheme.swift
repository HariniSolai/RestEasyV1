import SwiftUI

/// Centralized color palette matching the RestEasy mockups.
enum AppTheme {
    static let forestGreen = Color(red: 0.24, green: 0.36, blue: 0.24)
    static let sageGreen = Color(red: 0.51, green: 0.59, blue: 0.49)
    static let lightSage = Color(red: 0.53, green: 0.63, blue: 0.51)
    /// Muted green (#779B7F) used behind unselected segmented-control options.
    static let mutedGreen = Color(red: 119 / 255, green: 155 / 255, blue: 127 / 255)
    static let primaryButton = Color(red: 0.53, green: 0.82, blue: 0.54)
    static let cream = Color(red: 0.95, green: 0.94, blue: 0.89)
    static let linkGreen = Color(red: 0.35, green: 0.56, blue: 0.36)
    static let accentBlue = Color(red: 0.35, green: 0.65, blue: 1.0)
    static let inputText = Color.black
    static let inputPlaceholder = Color.black.opacity(0.45)
}
