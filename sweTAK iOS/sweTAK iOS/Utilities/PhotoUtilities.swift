#if canImport(UIKit)
import UIKit
#endif
import Foundation
import CoreLocation

// MARK: - Photo Utilities

/// Utilities for photo encoding, validation, and management
/// Mirrors Android photo utilities from MapPersistence.kt
public enum PhotoUtilities {

    // MARK: - Constants

    /// Maximum dimension for thumbnails
    public static let maxThumbnailDimension: CGFloat = 256

    /// Maximum dimension for network transfer
    public static let maxNetworkDimension: CGFloat = 1024

    /// JPEG compression quality for network transfer (0.0 - 1.0)
    public static let networkCompressionQuality: CGFloat = 0.7

    /// JPEG compression quality for thumbnails
    public static let thumbnailCompressionQuality: CGFloat = 0.6

    /// Maximum Base64 size for network transfer (5MB)
    public static let maxBase64Size = 5 * 1024 * 1024

    /// Maximum raw file size (5MB)
    public static let maxFileSize = 5 * 1024 * 1024

    /// Minimum valid image data size (100 bytes - smaller is suspect)
    public static let minValidImageSize = 100

    // MARK: - Base64 Encoding

    #if canImport(UIKit)

    /// Encodes an image as Base64 JPEG string
    public static func encodeAsBase64(
        _ image: UIImage,
        maxDimension: CGFloat = maxNetworkDimension,
        quality: CGFloat = networkCompressionQuality
    ) -> String? {
        // Resize if needed
        let resized = resizeImage(image, maxDimension: maxDimension)

        // Compress to JPEG
        guard let jpegData = resized.jpegData(compressionQuality: quality) else {
            return nil
        }

        return jpegData.base64EncodedString()
    }

    /// Encodes an image as Base64 thumbnail
    public static func encodeThumbnail(_ image: UIImage) -> String? {
        encodeAsBase64(
            image,
            maxDimension: maxThumbnailDimension,
            quality: thumbnailCompressionQuality
        )
    }

    /// Decodes a Base64 string to UIImage
    public static func decodeBase64(_ base64String: String) -> UIImage? {
        // Clean the string (remove data URL prefix if present)
        let cleaned = cleanBase64String(base64String)

        guard let data = Data(base64Encoded: cleaned) else {
            return nil
        }

        return UIImage(data: data)
    }

    /// Resizes an image to fit within a maximum dimension
    public static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size

        // Check if resizing is needed
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        // Resize
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    #endif

    // MARK: - Base64 Validation

    /// Validates that a Base64 string is a valid image
    public static func validateBase64Image(_ base64String: String) -> Bool {
        let cleaned = cleanBase64String(base64String)

        // Check length
        guard !cleaned.isEmpty, cleaned.count <= maxBase64Size else {
            return false
        }

        // Check if it decodes
        guard let data = Data(base64Encoded: cleaned) else {
            return false
        }

        // Check magic bytes for JPEG or PNG
        if data.count >= 3 {
            let bytes = [UInt8](data.prefix(3))

            // JPEG: FF D8 FF
            if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
                return true
            }

            // PNG: 89 50 4E
            if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E {
                return true
            }
        }

        return false
    }

    // MARK: - Enhanced Validation

    /// Result of photo validation
    public enum ValidationResult: Equatable {
        case valid
        case invalidEmpty
        case invalidTooLarge(size: Int)
        case invalidTooSmall(size: Int)
        case invalidBase64Encoding
        case invalidImageFormat
        case invalidCorruptData

        public var isValid: Bool {
            if case .valid = self { return true }
            return false
        }

        public var errorMessage: String {
            switch self {
            case .valid:
                return "Valid"
            case .invalidEmpty:
                return "Image data is empty"
            case .invalidTooLarge(let size):
                return "Image size (\(formatBytes(size))) exceeds maximum (\(formatBytes(maxBase64Size)))"
            case .invalidTooSmall(let size):
                return "Image size (\(formatBytes(size))) is suspiciously small"
            case .invalidBase64Encoding:
                return "Invalid Base64 encoding"
            case .invalidImageFormat:
                return "Unsupported image format (must be JPEG or PNG)"
            case .invalidCorruptData:
                return "Image data appears to be corrupt"
            }
        }

        private func formatBytes(_ bytes: Int) -> String {
            if bytes >= 1024 * 1024 {
                return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
            } else if bytes >= 1024 {
                return String(format: "%.1f KB", Double(bytes) / 1024.0)
            }
            return "\(bytes) bytes"
        }
    }

    /// Performs comprehensive validation of Base64 image data
    public static func validateBase64ImageComprehensive(_ base64String: String) -> ValidationResult {
        let cleaned = cleanBase64String(base64String)

        // Check empty
        if cleaned.isEmpty {
            return .invalidEmpty
        }

        // Check size
        if cleaned.count > maxBase64Size {
            return .invalidTooLarge(size: cleaned.count)
        }

        // Check Base64 decoding
        guard let data = Data(base64Encoded: cleaned) else {
            return .invalidBase64Encoding
        }

        // Check minimum size
        if data.count < minValidImageSize {
            return .invalidTooSmall(size: data.count)
        }

        // Check magic bytes
        guard data.count >= 8 else {
            return .invalidCorruptData
        }

        let bytes = [UInt8](data.prefix(8))

        // JPEG: FF D8 FF
        let isJPEG = bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF

        // PNG: 89 50 4E 47 0D 0A 1A 0A
        let isPNG = bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47

        if !isJPEG && !isPNG {
            return .invalidImageFormat
        }

        // Additional JPEG validation - check for proper end marker
        if isJPEG && data.count > 2 {
            let lastBytes = [UInt8](data.suffix(2))
            // JPEG should end with FF D9 (EOI marker)
            if lastBytes[0] != 0xFF || lastBytes[1] != 0xD9 {
                // Some JPEGs may have trailing data, so just warn but don't fail
                // return .invalidCorruptData
            }
        }

        return .valid
    }

    /// Validates raw image data (not Base64 encoded)
    public static func validateImageData(_ data: Data) -> ValidationResult {
        if data.isEmpty {
            return .invalidEmpty
        }

        if data.count > maxFileSize {
            return .invalidTooLarge(size: data.count)
        }

        if data.count < minValidImageSize {
            return .invalidTooSmall(size: data.count)
        }

        guard data.count >= 8 else {
            return .invalidCorruptData
        }

        let bytes = [UInt8](data.prefix(8))

        // JPEG: FF D8 FF
        let isJPEG = bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF

        // PNG: 89 50 4E 47 0D 0A 1A 0A
        let isPNG = bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47

        if !isJPEG && !isPNG {
            return .invalidImageFormat
        }

        return .valid
    }

    /// Cleans a Base64 string by removing data URL prefix
    public static func cleanBase64String(_ base64String: String) -> String {
        var result = base64String.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove data URL prefix if present
        if result.hasPrefix("data:") {
            if let commaIndex = result.firstIndex(of: ",") {
                result = String(result[result.index(after: commaIndex)...])
            }
        }

        return result
    }

    /// Gets the MIME type from Base64 image data
    public static func getMimeType(from base64String: String) -> String? {
        let cleaned = cleanBase64String(base64String)

        guard let data = Data(base64Encoded: cleaned), data.count >= 3 else {
            return nil
        }

        let bytes = [UInt8](data.prefix(3))

        // JPEG
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return "image/jpeg"
        }

        // PNG
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E {
            return "image/png"
        }

        return nil
    }

    // MARK: - Photo File Management

    /// Returns the photos directory URL
    public static var photosDirectory: URL? {
        let fileManager = FileManager.default
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let photosDir = documentsDir.appendingPathComponent("photos", isDirectory: true)

        // Create if needed
        if !fileManager.fileExists(atPath: photosDir.path) {
            try? fileManager.createDirectory(at: photosDir, withIntermediateDirectories: true)
        }

        return photosDir
    }

    /// Result of save operation
    public enum SaveResult {
        case success(filename: String)
        case failedValidation(ValidationResult)
        case failedWriteError(Error)

        public var filename: String? {
            if case .success(let name) = self { return name }
            return nil
        }

        public var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }

    /// Saves photo data to file and returns the filename
    public static func savePhotoToFile(_ data: Data, filename: String? = nil) -> String? {
        guard let photosDir = photosDirectory else { return nil }

        // Validate before saving
        let validation = validateImageData(data)
        guard validation.isValid else {
            print("[PhotoUtilities] Validation failed: \(validation.errorMessage)")
            return nil
        }

        let actualFilename = filename ?? "\(UUID().uuidString).jpg"
        let fileURL = photosDir.appendingPathComponent(actualFilename)

        do {
            try data.write(to: fileURL)
            return actualFilename
        } catch {
            print("[PhotoUtilities] Failed to save photo: \(error)")
            return nil
        }
    }

    /// Saves photo data with detailed result
    public static func savePhotoToFileWithResult(_ data: Data, filename: String? = nil) -> SaveResult {
        guard let photosDir = photosDirectory else {
            return .failedWriteError(NSError(domain: "PhotoUtilities", code: -1, userInfo: [NSLocalizedDescriptionKey: "Photos directory unavailable"]))
        }

        // Validate before saving
        let validation = validateImageData(data)
        guard validation.isValid else {
            return .failedValidation(validation)
        }

        let actualFilename = filename ?? "\(UUID().uuidString).jpg"
        let fileURL = photosDir.appendingPathComponent(actualFilename)

        do {
            try data.write(to: fileURL)
            return .success(filename: actualFilename)
        } catch {
            return .failedWriteError(error)
        }
    }

    #if canImport(UIKit)

    /// Saves a UIImage to file and returns the filename
    public static func saveImageToFile(_ image: UIImage, filename: String? = nil) -> String? {
        guard let jpegData = image.jpegData(compressionQuality: networkCompressionQuality) else {
            return nil
        }
        return savePhotoToFile(jpegData, filename: filename)
    }

    /// Loads a photo from file
    public static func loadPhotoFromFile(_ filename: String) -> UIImage? {
        guard let photosDir = photosDirectory else { return nil }
        let fileURL = photosDir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    #endif

    /// Deletes a photo file
    public static func deletePhotoFile(_ filename: String) -> Bool {
        guard let photosDir = photosDirectory else { return false }
        let fileURL = photosDir.appendingPathComponent(filename)

        do {
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch {
            print("[PhotoUtilities] Failed to delete photo: \(error)")
            return false
        }
    }

    /// Lists all photo files
    public static func listPhotoFiles() -> [String] {
        guard let photosDir = photosDirectory else { return [] }

        do {
            return try FileManager.default.contentsOfDirectory(atPath: photosDir.path)
                .filter { $0.hasSuffix(".jpg") || $0.hasSuffix(".jpeg") || $0.hasSuffix(".png") }
        } catch {
            print("[PhotoUtilities] Failed to list photos: \(error)")
            return []
        }
    }

    /// Gets total size of all photos in bytes
    public static func totalPhotoStorageSize() -> Int64 {
        guard let photosDir = photosDirectory else { return 0 }

        var total: Int64 = 0
        for filename in listPhotoFiles() {
            let fileURL = photosDir.appendingPathComponent(filename)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }

        return total
    }

    /// Formats storage size as human-readable string
    public static func formatStorageSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Photo Metadata

/// Extended metadata for a captured photo
public struct PhotoMetadata: Codable {
    public let id: String
    public let filename: String
    public let capturedAt: Date
    public let capturedBy: String?
    public let latitude: Double?
    public let longitude: Double?
    public let altitude: Double?
    public let heading: Double?
    public let linkedPinId: String?
    public let notes: String?

    public init(
        id: String = UUID().uuidString,
        filename: String,
        capturedAt: Date = Date(),
        capturedBy: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        altitude: Double? = nil,
        heading: Double? = nil,
        linkedPinId: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.capturedAt = capturedAt
        self.capturedBy = capturedBy
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.heading = heading
        self.linkedPinId = linkedPinId
        self.notes = notes
    }

    public var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Photo Capture Result

/// Result of a photo capture operation
public struct PhotoCaptureResult {
    public let metadata: PhotoMetadata
    public let base64Thumbnail: String?

    #if canImport(UIKit)
    public let image: UIImage?

    public init(
        metadata: PhotoMetadata,
        base64Thumbnail: String? = nil,
        image: UIImage? = nil
    ) {
        self.metadata = metadata
        self.base64Thumbnail = base64Thumbnail
        self.image = image
    }
    #else
    public init(
        metadata: PhotoMetadata,
        base64Thumbnail: String? = nil
    ) {
        self.metadata = metadata
        self.base64Thumbnail = base64Thumbnail
    }
    #endif
}
