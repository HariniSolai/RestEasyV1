import Foundation

/// The type of content being reported for moderation.
enum ContentReportTarget: String {
    case spot
    case review
}

/// Reasons a user can select when reporting inappropriate content.
enum ContentReportReason: String, CaseIterable, Identifiable {
    case inappropriatePhoto
    case offensiveText
    case inaccurateLocation
    case spam
    case other

    var id: String { rawValue }

    /// User-facing label shown in the report sheet.
    var displayName: String {
        switch self {
        case .inappropriatePhoto: return "Inappropriate photo"
        case .offensiveText: return "Offensive text"
        case .inaccurateLocation: return "Inaccurate location"
        case .spam: return "Spam"
        case .other: return "Other"
        }
    }
}
