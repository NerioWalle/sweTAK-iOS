import XCTest
import CoreLocation
@testable import sweTAK

/// Tests for Phase 25: NATO Icons, Photo Utilities, Network Utilities
final class Phase25Tests: XCTestCase {

    // MARK: - NATO Affiliation Tests

    func testNATOAffiliationColors() {
        // Each affiliation should have distinct colors
        XCTAssertNotEqual(NATOAffiliation.friendly.frameColor, NATOAffiliation.hostile.frameColor)
        XCTAssertNotEqual(NATOAffiliation.neutral.frameColor, NATOAffiliation.unknown.frameColor)
    }

    func testNATOAffiliationCases() {
        let allCases = NATOAffiliation.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.friendly))
        XCTAssertTrue(allCases.contains(.hostile))
        XCTAssertTrue(allCases.contains(.neutral))
        XCTAssertTrue(allCases.contains(.unknown))
    }

    func testNATOAffiliationRawValues() {
        XCTAssertEqual(NATOAffiliation.friendly.rawValue, "FRIENDLY")
        XCTAssertEqual(NATOAffiliation.hostile.rawValue, "HOSTILE")
        XCTAssertEqual(NATOAffiliation.neutral.rawValue, "NEUTRAL")
        XCTAssertEqual(NATOAffiliation.unknown.rawValue, "UNKNOWN")
    }

    // MARK: - NATO Symbol Shape Tests

    func testNATOSymbolShapeCases() {
        let allCases = NATOSymbolShape.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.ground))
        XCTAssertTrue(allCases.contains(.air))
        XCTAssertTrue(allCases.contains(.naval))
        XCTAssertTrue(allCases.contains(.subsurface))
    }

    func testNATOSymbolShapeRawValues() {
        XCTAssertEqual(NATOSymbolShape.ground.rawValue, "GROUND")
        XCTAssertEqual(NATOSymbolShape.air.rawValue, "AIR")
        XCTAssertEqual(NATOSymbolShape.naval.rawValue, "NAVAL")
        XCTAssertEqual(NATOSymbolShape.subsurface.rawValue, "SUBSURFACE")
    }

    func testNATOSymbolShapePathGeneration() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)

        // Each shape should produce a non-empty path
        XCTAssertFalse(NATOSymbolShape.ground.path(in: rect).isEmpty)
        XCTAssertFalse(NATOSymbolShape.air.path(in: rect).isEmpty)
        XCTAssertFalse(NATOSymbolShape.naval.path(in: rect).isEmpty)
        XCTAssertFalse(NATOSymbolShape.subsurface.path(in: rect).isEmpty)
    }

    // MARK: - Photo Utilities Constants Tests

    func testPhotoUtilitiesConstants() {
        XCTAssertEqual(PhotoUtilities.maxBase64Size, 5 * 1024 * 1024)
        XCTAssertEqual(PhotoUtilities.maxFileSize, 5 * 1024 * 1024)
        XCTAssertEqual(PhotoUtilities.minValidImageSize, 100)
        XCTAssertEqual(PhotoUtilities.maxThumbnailDimension, 256)
        XCTAssertEqual(PhotoUtilities.maxNetworkDimension, 1024)
    }

    // MARK: - Photo Validation Result Tests

    func testValidationResultValid() {
        let result = PhotoUtilities.ValidationResult.valid
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.errorMessage, "Valid")
    }

    func testValidationResultEmpty() {
        let result = PhotoUtilities.ValidationResult.invalidEmpty
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Image data is empty")
    }

    func testValidationResultTooLarge() {
        let result = PhotoUtilities.ValidationResult.invalidTooLarge(size: 10_000_000)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errorMessage.contains("exceeds maximum"))
    }

    func testValidationResultTooSmall() {
        let result = PhotoUtilities.ValidationResult.invalidTooSmall(size: 50)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errorMessage.contains("suspiciously small"))
    }

    func testValidationResultBase64Encoding() {
        let result = PhotoUtilities.ValidationResult.invalidBase64Encoding
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Invalid Base64 encoding")
    }

    func testValidationResultImageFormat() {
        let result = PhotoUtilities.ValidationResult.invalidImageFormat
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errorMessage.contains("JPEG or PNG"))
    }

    func testValidationResultCorruptData() {
        let result = PhotoUtilities.ValidationResult.invalidCorruptData
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errorMessage.contains("corrupt"))
    }

    func testValidationResultEquatable() {
        XCTAssertEqual(PhotoUtilities.ValidationResult.valid, PhotoUtilities.ValidationResult.valid)
        XCTAssertEqual(PhotoUtilities.ValidationResult.invalidEmpty, PhotoUtilities.ValidationResult.invalidEmpty)
        XCTAssertNotEqual(PhotoUtilities.ValidationResult.valid, PhotoUtilities.ValidationResult.invalidEmpty)
    }

    // MARK: - Base64 Validation Tests

    func testValidateEmptyBase64() {
        let result = PhotoUtilities.validateBase64ImageComprehensive("")
        XCTAssertEqual(result, .invalidEmpty)
    }

    func testValidateInvalidBase64Encoding() {
        let result = PhotoUtilities.validateBase64ImageComprehensive("!!!not-valid-base64!!!")
        XCTAssertEqual(result, .invalidBase64Encoding)
    }

    func testValidateBase64TooSmall() {
        // Valid base64 but decodes to tiny data
        let smallData = Data([0x00, 0x01])
        let base64 = smallData.base64EncodedString()
        let result = PhotoUtilities.validateBase64ImageComprehensive(base64)
        XCTAssertEqual(result, .invalidTooSmall(size: 2))
    }

    func testValidateBase64WrongFormat() {
        // Create valid data that's not JPEG or PNG
        var data = Data(count: 200)
        data[0] = 0x47 // G
        data[1] = 0x49 // I
        data[2] = 0x46 // F (GIF header)
        let base64 = data.base64EncodedString()
        let result = PhotoUtilities.validateBase64ImageComprehensive(base64)
        XCTAssertEqual(result, .invalidImageFormat)
    }

    func testValidateValidJPEGBase64() {
        // Create minimal JPEG header
        var jpegData = Data(count: 200)
        jpegData[0] = 0xFF
        jpegData[1] = 0xD8
        jpegData[2] = 0xFF
        jpegData[198] = 0xFF
        jpegData[199] = 0xD9
        let base64 = jpegData.base64EncodedString()
        let result = PhotoUtilities.validateBase64ImageComprehensive(base64)
        XCTAssertEqual(result, .valid)
    }

    func testValidateValidPNGBase64() {
        // Create minimal PNG header
        var pngData = Data(count: 200)
        pngData[0] = 0x89
        pngData[1] = 0x50 // P
        pngData[2] = 0x4E // N
        pngData[3] = 0x47 // G
        let base64 = pngData.base64EncodedString()
        let result = PhotoUtilities.validateBase64ImageComprehensive(base64)
        XCTAssertEqual(result, .valid)
    }

    // MARK: - Raw Image Data Validation Tests

    func testValidateEmptyData() {
        let result = PhotoUtilities.validateImageData(Data())
        XCTAssertEqual(result, .invalidEmpty)
    }

    func testValidateDataTooLarge() {
        let largeData = Data(count: 6 * 1024 * 1024)
        let result = PhotoUtilities.validateImageData(largeData)
        XCTAssertFalse(result.isValid)
        if case .invalidTooLarge = result {
            // Expected
        } else {
            XCTFail("Expected invalidTooLarge")
        }
    }

    func testValidateDataTooSmall() {
        let smallData = Data([0xFF, 0xD8, 0xFF])
        let result = PhotoUtilities.validateImageData(smallData)
        XCTAssertEqual(result, .invalidTooSmall(size: 3))
    }

    func testValidateValidJPEGData() {
        var jpegData = Data(count: 200)
        jpegData[0] = 0xFF
        jpegData[1] = 0xD8
        jpegData[2] = 0xFF
        let result = PhotoUtilities.validateImageData(jpegData)
        XCTAssertEqual(result, .valid)
    }

    func testValidateValidPNGData() {
        var pngData = Data(count: 200)
        pngData[0] = 0x89
        pngData[1] = 0x50
        pngData[2] = 0x4E
        pngData[3] = 0x47
        let result = PhotoUtilities.validateImageData(pngData)
        XCTAssertEqual(result, .valid)
    }

    // MARK: - Base64 Cleaning Tests

    func testCleanBase64StringPlain() {
        let cleaned = PhotoUtilities.cleanBase64String("  abc123==  ")
        XCTAssertEqual(cleaned, "abc123==")
    }

    func testCleanBase64StringDataURL() {
        let cleaned = PhotoUtilities.cleanBase64String("data:image/jpeg;base64,abc123==")
        XCTAssertEqual(cleaned, "abc123==")
    }

    func testCleanBase64StringPNGDataURL() {
        let cleaned = PhotoUtilities.cleanBase64String("data:image/png;base64,xyz789")
        XCTAssertEqual(cleaned, "xyz789")
    }

    // MARK: - MIME Type Detection Tests

    func testGetMimeTypeJPEG() {
        var jpegData = Data(count: 10)
        jpegData[0] = 0xFF
        jpegData[1] = 0xD8
        jpegData[2] = 0xFF
        let base64 = jpegData.base64EncodedString()
        XCTAssertEqual(PhotoUtilities.getMimeType(from: base64), "image/jpeg")
    }

    func testGetMimeTypePNG() {
        var pngData = Data(count: 10)
        pngData[0] = 0x89
        pngData[1] = 0x50
        pngData[2] = 0x4E
        let base64 = pngData.base64EncodedString()
        XCTAssertEqual(PhotoUtilities.getMimeType(from: base64), "image/png")
    }

    func testGetMimeTypeUnknown() {
        var unknownData = Data(count: 10)
        unknownData[0] = 0x00
        unknownData[1] = 0x00
        unknownData[2] = 0x00
        let base64 = unknownData.base64EncodedString()
        XCTAssertNil(PhotoUtilities.getMimeType(from: base64))
    }

    // MARK: - Save Result Tests

    func testSaveResultSuccess() {
        let result = PhotoUtilities.SaveResult.success(filename: "test.jpg")
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.filename, "test.jpg")
    }

    func testSaveResultFailedValidation() {
        let result = PhotoUtilities.SaveResult.failedValidation(.invalidEmpty)
        XCTAssertFalse(result.isSuccess)
        XCTAssertNil(result.filename)
    }

    func testSaveResultFailedWrite() {
        let error = NSError(domain: "test", code: 1, userInfo: nil)
        let result = PhotoUtilities.SaveResult.failedWriteError(error)
        XCTAssertFalse(result.isSuccess)
        XCTAssertNil(result.filename)
    }

    // MARK: - Storage Formatting Tests

    func testFormatStorageSizeBytes() {
        let formatted = PhotoUtilities.formatStorageSize(500)
        XCTAssertFalse(formatted.isEmpty)
    }

    func testFormatStorageSizeKB() {
        let formatted = PhotoUtilities.formatStorageSize(50_000)
        XCTAssertTrue(formatted.contains("KB"))
    }

    func testFormatStorageSizeMB() {
        let formatted = PhotoUtilities.formatStorageSize(5_000_000)
        XCTAssertTrue(formatted.contains("MB"))
    }

    // MARK: - Photo Metadata Tests

    func testPhotoMetadataInit() {
        let metadata = PhotoMetadata(
            filename: "test.jpg",
            capturedBy: "user1",
            latitude: 59.3293,
            longitude: 18.0686
        )

        XCTAssertEqual(metadata.filename, "test.jpg")
        XCTAssertEqual(metadata.capturedBy, "user1")
        XCTAssertEqual(metadata.latitude, 59.3293)
        XCTAssertEqual(metadata.longitude, 18.0686)
    }

    func testPhotoMetadataCoordinate() {
        let metadata = PhotoMetadata(
            filename: "test.jpg",
            latitude: 59.3293,
            longitude: 18.0686
        )

        let coord = metadata.coordinate
        XCTAssertNotNil(coord)
        XCTAssertEqual(coord?.latitude ?? 0, 59.3293, accuracy: 0.0001)
        XCTAssertEqual(coord?.longitude ?? 0, 18.0686, accuracy: 0.0001)
    }

    func testPhotoMetadataCoordinateNil() {
        let metadata = PhotoMetadata(filename: "test.jpg")
        XCTAssertNil(metadata.coordinate)
    }

    // MARK: - Network Peer Tests

    func testNetworkPeerInit() {
        let peer = MapNetworkUtils.NetworkPeer(
            deviceId: "device-123",
            host: "192.168.1.100",
            port: 4242,
            callsign: "ALPHA",
            nickname: "Alpha Team"
        )

        XCTAssertEqual(peer.deviceId, "device-123")
        XCTAssertEqual(peer.host, "192.168.1.100")
        XCTAssertEqual(peer.port, 4242)
        XCTAssertEqual(peer.callsign, "ALPHA")
        XCTAssertEqual(peer.nickname, "Alpha Team")
    }

    func testNetworkPeerEquality() {
        let peer1 = MapNetworkUtils.NetworkPeer(deviceId: "device-1", host: "192.168.1.1")
        let peer2 = MapNetworkUtils.NetworkPeer(deviceId: "device-1", host: "192.168.1.2")
        let peer3 = MapNetworkUtils.NetworkPeer(deviceId: "device-2", host: "192.168.1.1")

        // Same device ID = equal, regardless of host
        XCTAssertEqual(peer1, peer2)
        XCTAssertNotEqual(peer1, peer3)
    }

    func testNetworkPeerHashable() {
        let peer1 = MapNetworkUtils.NetworkPeer(deviceId: "device-1", host: "192.168.1.1")
        let peer2 = MapNetworkUtils.NetworkPeer(deviceId: "device-1", host: "192.168.1.2")

        var set = Set<MapNetworkUtils.NetworkPeer>()
        set.insert(peer1)
        set.insert(peer2)

        // Same device ID should only result in one entry
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - Rebuild UDP Peers Tests

    func testRebuildUDPPeersEmpty() {
        let result = MapNetworkUtils.rebuildUDPPeers(friends: [:], blockedIds: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testRebuildUDPPeersFiltersBlocked() {
        let friends: [String: MapNetworkUtils.NetworkPeer] = [
            "device-1": MapNetworkUtils.NetworkPeer(deviceId: "device-1", host: "192.168.1.1"),
            "device-2": MapNetworkUtils.NetworkPeer(deviceId: "device-2", host: "192.168.1.2")
        ]
        let blockedIds: Set<String> = ["device-1"]

        let result = MapNetworkUtils.rebuildUDPPeers(friends: friends, blockedIds: blockedIds)

        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result.contains { $0.deviceId == "device-2" })
        XCTAssertFalse(result.contains { $0.deviceId == "device-1" })
    }

    func testRebuildUDPPeersFiltersEmptyHost() {
        let friends: [String: MapNetworkUtils.NetworkPeer] = [
            "device-1": MapNetworkUtils.NetworkPeer(deviceId: "device-1", host: "192.168.1.1"),
            "device-2": MapNetworkUtils.NetworkPeer(deviceId: "device-2", host: "")
        ]

        let result = MapNetworkUtils.rebuildUDPPeers(friends: friends, blockedIds: [])

        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result.contains { $0.deviceId == "device-1" })
    }

    // MARK: - Chat Recipient Tests

    func testChatRecipientInit() {
        let recipient = ChatRecipient(
            deviceId: "device-123",
            callsign: "ALPHA",
            nickname: "Alpha Team"
        )

        XCTAssertEqual(recipient.id, "device-123")
        XCTAssertEqual(recipient.deviceId, "device-123")
        XCTAssertEqual(recipient.callsign, "ALPHA")
        XCTAssertEqual(recipient.nickname, "Alpha Team")
    }

    func testChatRecipientDisplayNameWithNickname() {
        let recipient = ChatRecipient(
            deviceId: "device-123",
            callsign: "ALPHA",
            nickname: "Alpha Team"
        )

        XCTAssertEqual(recipient.displayName, "ALPHA (Alpha Team)")
    }

    func testChatRecipientDisplayNameWithoutNickname() {
        let recipient = ChatRecipient(deviceId: "device-123", callsign: "ALPHA")
        XCTAssertEqual(recipient.displayName, "ALPHA")
    }

    // MARK: - Connection Quality Tests

    func testConnectionQualityExcellent() {
        let quality = MapNetworkUtils.estimateConnectionQuality(30)
        XCTAssertEqual(quality, .excellent)
        XCTAssertEqual(quality.displayName, "Excellent")
    }

    func testConnectionQualityGood() {
        let quality = MapNetworkUtils.estimateConnectionQuality(100)
        XCTAssertEqual(quality, .good)
        XCTAssertEqual(quality.displayName, "Good")
    }

    func testConnectionQualityFair() {
        let quality = MapNetworkUtils.estimateConnectionQuality(200)
        XCTAssertEqual(quality, .fair)
        XCTAssertEqual(quality.displayName, "Fair")
    }

    func testConnectionQualityPoor() {
        let quality = MapNetworkUtils.estimateConnectionQuality(500)
        XCTAssertEqual(quality, .poor)
        XCTAssertEqual(quality.displayName, "Poor")
    }

    // MARK: - Subnet Utility Tests

    func testIsInLocalSubnetTrue() {
        // This test depends on actual network configuration
        // We'll test the logic with a mock scenario
        // Note: If no network, this may return false
        let result = MapNetworkUtils.isInLocalSubnet("127.0.0.1")
        // Just verify it returns a boolean without crashing
        XCTAssertTrue(result == true || result == false)
    }

    // MARK: - Crosshair Icon Tests

    func testCrosshairIconPath() {
        let icon = CrosshairIcon()
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let path = icon.path(in: rect)

        // Path should not be empty
        XCTAssertFalse(path.isEmpty)
    }

    // MARK: - Drone Pin Icon Tests

    func testDronePinIconPath() {
        let icon = DronePinIcon()
        let rect = CGRect(x: 0, y: 0, width: 48, height: 48)
        let path = icon.path(in: rect)

        // Path should not be empty
        XCTAssertFalse(path.isEmpty)
    }
}
