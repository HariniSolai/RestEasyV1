import UIKit

/// Utilities for preparing user-selected photos before Firebase Storage upload.
enum ImageUploadHelper {
    /// Converts arbitrary image bytes from the photo picker into JPEG data.
    /// - Parameters:
    ///   - imageData: Raw image bytes from `PhotosPicker`.
    ///   - compressionQuality: JPEG quality from 0.0 to 1.0.
    /// - Returns: JPEG-encoded bytes, or `nil` when the source data is not a valid image.
    static func jpegData(from imageData: Data, compressionQuality: CGFloat = 0.8) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        return image.jpegData(compressionQuality: compressionQuality)
    }
}
