import XCTest
import CoreLocation
@testable import sweTAK

// MARK: - Breadcrumb Point Tests

final class BreadcrumbPointTests: XCTestCase {

    func testBreadcrumbPointInitialization() {
        let point = BreadcrumbPoint(
            latitude: 59.33,
            longitude: 18.06,
            altitude: 100.0
        )

        XCTAssertEqual(point.latitude, 59.33)
        XCTAssertEqual(point.longitude, 18.06)
        XCTAssertEqual(point.altitude, 100.0)
        XCTAssertNotNil(point.timestamp)
    }

    func testBreadcrumbPointCoordinate() {
        let point = BreadcrumbPoint(latitude: 59.33, longitude: 18.06)

        XCTAssertEqual(point.coordinate.latitude, 59.33)
        XCTAssertEqual(point.coordinate.longitude, 18.06)
    }

    func testBreadcrumbPointWithoutAltitude() {
        let point = BreadcrumbPoint(latitude: 59.33, longitude: 18.06, altitude: nil)

        XCTAssertNil(point.altitude)
    }

    func testBreadcrumbPointCodable() throws {
        let point = BreadcrumbPoint(
            latitude: 59.33,
            longitude: 18.06,
            altitude: 100.0,
            timestamp: Date()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(point)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BreadcrumbPoint.self, from: data)

        XCTAssertEqual(decoded.latitude, point.latitude)
        XCTAssertEqual(decoded.longitude, point.longitude)
        XCTAssertEqual(decoded.altitude, point.altitude)
    }

    func testBreadcrumbPointEquatable() {
        let point1 = BreadcrumbPoint(latitude: 59.33, longitude: 18.06, altitude: 100.0, timestamp: Date(timeIntervalSince1970: 1000))
        let point2 = BreadcrumbPoint(latitude: 59.33, longitude: 18.06, altitude: 100.0, timestamp: Date(timeIntervalSince1970: 1000))
        let point3 = BreadcrumbPoint(latitude: 59.34, longitude: 18.06, altitude: 100.0, timestamp: Date(timeIntervalSince1970: 1000))

        XCTAssertEqual(point1, point2)
        XCTAssertNotEqual(point1, point3)
    }
}

// MARK: - Location Tracking State Tests

final class LocationTrackingStateTests: XCTestCase {

    func testLocationTrackingStateRawValues() {
        XCTAssertEqual(LocationTrackingState.idle.rawValue, "IDLE")
        XCTAssertEqual(LocationTrackingState.tracking.rawValue, "TRACKING")
        XCTAssertEqual(LocationTrackingState.recording.rawValue, "RECORDING")
    }
}

// MARK: - Location Tracking Manager Tests

final class LocationTrackingManagerTests: XCTestCase {

    func testLocationTrackingManagerSingleton() {
        let manager1 = LocationTrackingManager.shared
        let manager2 = LocationTrackingManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    func testLocationTrackingManagerInitialState() {
        let manager = LocationTrackingManager.shared

        XCTAssertEqual(manager.state, .idle)
        XCTAssertNil(manager.currentLocation)
        XCTAssertFalse(manager.isTracking)
        XCTAssertFalse(manager.isRecording)
    }

    func testRunningDistanceConversion() {
        // Test the conversion from meters to kilometers
        let meters: Double = 2500
        let km = meters / 1000.0
        XCTAssertEqual(km, 2.5)
    }
}

// MARK: - Map Orientation Mode Tests

final class MapOrientationModeTests: XCTestCase {

    func testMapOrientationModeRawValues() {
        XCTAssertEqual(MapOrientationMode.northUp.rawValue, "NORTH_UP")
        XCTAssertEqual(MapOrientationMode.freeRotation.rawValue, "FREE_ROTATION")
        XCTAssertEqual(MapOrientationMode.headingUp.rawValue, "HEADING_UP")
    }

    func testMapOrientationModeDisplayNames() {
        XCTAssertEqual(MapOrientationMode.northUp.displayName, "North Up")
        XCTAssertEqual(MapOrientationMode.freeRotation.displayName, "Free Rotation")
        XCTAssertEqual(MapOrientationMode.headingUp.displayName, "Heading Up")
    }

    func testMapOrientationModeIcons() {
        XCTAssertEqual(MapOrientationMode.northUp.icon, "location.north.fill")
        XCTAssertEqual(MapOrientationMode.freeRotation.icon, "arrow.triangle.2.circlepath")
        XCTAssertEqual(MapOrientationMode.headingUp.icon, "location.north.line.fill")
    }

    func testMapOrientationModeCaseIterable() {
        XCTAssertEqual(MapOrientationMode.allCases.count, 3)
    }

    func testMapOrientationModeCodable() throws {
        let mode = MapOrientationMode.headingUp

        let encoder = JSONEncoder()
        let data = try encoder.encode(mode)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MapOrientationMode.self, from: data)

        XCTAssertEqual(decoded, mode)
    }
}

// MARK: - Compass Manager Tests

final class CompassManagerTests: XCTestCase {

    func testCompassManagerSingleton() {
        let manager1 = CompassManager.shared
        let manager2 = CompassManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    func testBearingToCardinal() {
        let compass = CompassManager.shared

        XCTAssertEqual(compass.bearingToCardinal(0), "N")
        XCTAssertEqual(compass.bearingToCardinal(45), "NE")
        XCTAssertEqual(compass.bearingToCardinal(90), "E")
        XCTAssertEqual(compass.bearingToCardinal(135), "SE")
        XCTAssertEqual(compass.bearingToCardinal(180), "S")
        XCTAssertEqual(compass.bearingToCardinal(225), "SW")
        XCTAssertEqual(compass.bearingToCardinal(270), "W")
        XCTAssertEqual(compass.bearingToCardinal(315), "NW")
        XCTAssertEqual(compass.bearingToCardinal(360), "N")
    }

    func testBearingToCardinalNormalization() {
        let compass = CompassManager.shared

        // Test negative bearings
        XCTAssertEqual(compass.bearingToCardinal(-90), "W")
        XCTAssertEqual(compass.bearingToCardinal(-180), "S")

        // Test bearings > 360
        XCTAssertEqual(compass.bearingToCardinal(450), "E")
        XCTAssertEqual(compass.bearingToCardinal(720), "N")
    }

    func testFormatHeading() {
        let compass = CompassManager.shared

        XCTAssertEqual(compass.formatHeading(0), "0° N")
        XCTAssertEqual(compass.formatHeading(90), "90° E")
        XCTAssertEqual(compass.formatHeading(180), "180° S")
        XCTAssertEqual(compass.formatHeading(270), "270° W")
    }

    func testBearingTo() {
        let compass = CompassManager.shared

        // Test bearing from origin to north
        let origin = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let north = CLLocationCoordinate2D(latitude: 1, longitude: 0)
        let bearingNorth = compass.bearingTo(north, from: origin)
        XCTAssertEqual(bearingNorth, 0, accuracy: 1)

        // Test bearing from origin to east
        let east = CLLocationCoordinate2D(latitude: 0, longitude: 1)
        let bearingEast = compass.bearingTo(east, from: origin)
        XCTAssertEqual(bearingEast, 90, accuracy: 1)

        // Test bearing from origin to south
        let south = CLLocationCoordinate2D(latitude: -1, longitude: 0)
        let bearingSouth = compass.bearingTo(south, from: origin)
        XCTAssertEqual(bearingSouth, 180, accuracy: 1)
    }

    func testCompassTicks() {
        let compass = CompassManager.shared
        let ticks = compass.compassTicks(count: 36)

        XCTAssertEqual(ticks.count, 36)

        // Check cardinal points
        XCTAssertEqual(ticks[0].label, "N")
        XCTAssertEqual(ticks[9].label, "E")
        XCTAssertEqual(ticks[18].label, "S")
        XCTAssertEqual(ticks[27].label, "W")
    }
}

// MARK: - Secure Storage Error Tests

final class SecureStorageErrorTests: XCTestCase {

    func testSecureStorageErrorDescriptions() {
        XCTAssertNotNil(SecureStorageError.dataConversionFailed.errorDescription)
        XCTAssertNotNil(SecureStorageError.itemNotFound.errorDescription)
        XCTAssertNotNil(SecureStorageError.unexpectedData.errorDescription)
        XCTAssertNotNil(SecureStorageError.encodingFailed.errorDescription)
        XCTAssertNotNil(SecureStorageError.decodingFailed.errorDescription)
        XCTAssertNotNil(SecureStorageError.keychainError(-25300).errorDescription)
    }
}

// MARK: - Secure Storage Tests

final class SecureStorageTests: XCTestCase {

    private let testKey = "test_key_\(UUID().uuidString)"

    override func tearDown() {
        // Clean up test data
        try? SecureStorage.shared.delete(forKey: testKey)
        super.tearDown()
    }

    func testSecureStorageSingleton() {
        let storage1 = SecureStorage.shared
        let storage2 = SecureStorage.shared
        XCTAssertTrue(storage1 === storage2)
    }

    func testSecureStorageStringRoundTrip() throws {
        let storage = SecureStorage.shared
        let testValue = "Test secure string"

        try storage.setString(testValue, forKey: testKey)
        let retrieved = try storage.getString(forKey: testKey)

        XCTAssertEqual(retrieved, testValue)
    }

    func testSecureStorageDataRoundTrip() throws {
        let storage = SecureStorage.shared
        let testData = Data([0x01, 0x02, 0x03, 0x04])

        try storage.setData(testData, forKey: testKey)
        let retrieved = try storage.getData(forKey: testKey)

        XCTAssertEqual(retrieved, testData)
    }

    func testSecureStorageBoolRoundTrip() throws {
        let storage = SecureStorage.shared

        try storage.setBool(true, forKey: testKey)
        let retrieved = try storage.getBool(forKey: testKey)

        XCTAssertTrue(retrieved)
    }

    func testSecureStorageIntRoundTrip() throws {
        let storage = SecureStorage.shared
        let testValue = 42

        try storage.setInt(testValue, forKey: testKey)
        let retrieved = try storage.getInt(forKey: testKey)

        XCTAssertEqual(retrieved, testValue)
    }

    func testSecureStorageExists() throws {
        let storage = SecureStorage.shared

        XCTAssertFalse(storage.exists(forKey: testKey))

        try storage.setString("test", forKey: testKey)
        XCTAssertTrue(storage.exists(forKey: testKey))
    }

    func testSecureStorageDelete() throws {
        let storage = SecureStorage.shared

        try storage.setString("test", forKey: testKey)
        XCTAssertTrue(storage.exists(forKey: testKey))

        try storage.delete(forKey: testKey)
        XCTAssertFalse(storage.exists(forKey: testKey))
    }

    func testSecureStorageGetOrNilWhenMissing() {
        let storage = SecureStorage.shared

        let result = storage.getStringOrNil(forKey: "nonexistent_key_\(UUID().uuidString)")
        XCTAssertNil(result)
    }

    func testSecureStorageGetWithDefault() {
        let storage = SecureStorage.shared

        let result = storage.getBool(forKey: "nonexistent_key_\(UUID().uuidString)", default: true)
        XCTAssertTrue(result)
    }

    func testSecureStorageCodableRoundTrip() throws {
        struct TestStruct: Codable, Equatable {
            let name: String
            let value: Int
        }

        let storage = SecureStorage.shared
        let testValue = TestStruct(name: "Test", value: 42)

        try storage.setCodable(testValue, forKey: testKey)
        let retrieved = try storage.getCodable(TestStruct.self, forKey: testKey)

        XCTAssertEqual(retrieved, testValue)
    }
}

// MARK: - Secure Storage Keys Tests

final class SecureStorageKeysTests: XCTestCase {

    func testSecureStorageKeysExist() {
        XCTAssertEqual(SecureStorageKeys.deviceId, "device_id")
        XCTAssertEqual(SecureStorageKeys.hmacKey, "hmac_signing_key")
        XCTAssertEqual(SecureStorageKeys.authToken, "auth_token")
        XCTAssertEqual(SecureStorageKeys.mqttUsername, "mqtt_username")
        XCTAssertEqual(SecureStorageKeys.mqttPassword, "mqtt_password")
    }
}

// MARK: - Message Signer Tests

@available(iOS 13.0, macOS 10.15, *)
final class MessageSignerTests: XCTestCase {

    func testMessageSignerSingleton() {
        let signer1 = MessageSigner.shared
        let signer2 = MessageSigner.shared
        XCTAssertTrue(signer1 === signer2)
    }

    func testMessageSignerHasPublicKey() {
        let signer = MessageSigner.shared
        let publicKey = signer.publicKey
        XCTAssertFalse(publicKey.isEmpty)
    }

    func testMessageSignerSignData() throws {
        let signer = MessageSigner.shared
        let message = "Test message".data(using: .utf8)!

        let signature = try signer.sign(message: message)

        XCTAssertFalse(signature.isEmpty)
    }

    func testMessageSignerSignBase64() throws {
        let signer = MessageSigner.shared
        let message = "Test message".data(using: .utf8)!

        let signatureBase64 = try signer.signBase64(message: message)

        XCTAssertFalse(signatureBase64.isEmpty)
        // Should be valid Base64
        XCTAssertNotNil(Data(base64Encoded: signatureBase64))
    }

    func testMessageSignerPublicKeyBase64() {
        let signer = MessageSigner.shared
        let publicKeyBase64 = signer.publicKeyBase64

        XCTAssertFalse(publicKeyBase64.isEmpty)
        // Should be valid Base64
        XCTAssertNotNil(Data(base64Encoded: publicKeyBase64))
    }

    func testMessageSignerVerifyValidSignature() throws {
        let signer = MessageSigner.shared
        let message = "Test message".data(using: .utf8)!

        let signature = try signer.sign(message: message)
        let isValid = try signer.verify(message: message, signature: signature, publicKey: signer.publicKey)

        XCTAssertTrue(isValid)
    }

    func testMessageSignerVerifyInvalidSignature() throws {
        let signer = MessageSigner.shared
        let message = "Test message".data(using: .utf8)!
        let tamperedMessage = "Tampered message".data(using: .utf8)!

        let signature = try signer.sign(message: message)
        let isValid = try signer.verify(message: tamperedMessage, signature: signature, publicKey: signer.publicKey)

        XCTAssertFalse(isValid)
    }

    func testMessageSignerVerifyBase64() throws {
        let signer = MessageSigner.shared
        let message = "Test message".data(using: .utf8)!

        let signatureBase64 = try signer.signBase64(message: message)
        let isValid = try signer.verifyBase64(
            message: message,
            signatureBase64: signatureBase64,
            publicKeyBase64: signer.publicKeyBase64
        )

        XCTAssertTrue(isValid)
    }

    func testMessageSignerConsistentKey() throws {
        let signer = MessageSigner.shared

        // Sign multiple messages
        let message1 = "Message 1".data(using: .utf8)!
        let message2 = "Message 2".data(using: .utf8)!

        let signature1 = try signer.sign(message: message1)
        let signature2 = try signer.sign(message: message2)

        // Both should be verifiable with the same public key
        let valid1 = try signer.verify(message: message1, signature: signature1, publicKey: signer.publicKey)
        let valid2 = try signer.verify(message: message2, signature: signature2, publicKey: signer.publicKey)

        XCTAssertTrue(valid1)
        XCTAssertTrue(valid2)
    }
}

// MARK: - Security Configuration Tests

final class SecurityConfigurationTests: XCTestCase {

    func testSecurityConfigurationDefaults() {
        let config = SecurityConfiguration()

        XCTAssertTrue(config.signingEnabled)
        XCTAssertTrue(config.autoVerifySignatures)
        XCTAssertFalse(config.rejectUnsignedMessages)
        XCTAssertFalse(config.encryptionEnabled)
        XCTAssertEqual(config.maxMessageAgeMs, 5 * 60 * 1000)
    }

    func testSecurityConfigurationCustomValues() {
        let config = SecurityConfiguration(
            signingEnabled: false,
            autoVerifySignatures: false,
            rejectUnsignedMessages: true,
            encryptionEnabled: true,
            maxMessageAgeMs: 10 * 60 * 1000
        )

        XCTAssertFalse(config.signingEnabled)
        XCTAssertFalse(config.autoVerifySignatures)
        XCTAssertTrue(config.rejectUnsignedMessages)
        XCTAssertTrue(config.encryptionEnabled)
        XCTAssertEqual(config.maxMessageAgeMs, 10 * 60 * 1000)
    }

    func testSecurityConfigurationCodable() throws {
        let config = SecurityConfiguration(signingEnabled: true, encryptionEnabled: true)

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SecurityConfiguration.self, from: data)

        XCTAssertEqual(decoded, config)
    }
}

// MARK: - Security Error Tests

final class SecurityErrorTests: XCTestCase {

    func testSecurityErrorDescriptions() {
        XCTAssertNotNil(SecurityError.keyGenerationFailed.errorDescription)
        XCTAssertNotNil(SecurityError.signingFailed.errorDescription)
        XCTAssertNotNil(SecurityError.verificationFailed.errorDescription)
        XCTAssertNotNil(SecurityError.encryptionFailed.errorDescription)
        XCTAssertNotNil(SecurityError.decryptionFailed.errorDescription)
        XCTAssertNotNil(SecurityError.certificateGenerationFailed.errorDescription)
        XCTAssertNotNil(SecurityError.certificateNotFound.errorDescription)
        XCTAssertNotNil(SecurityError.invalidPublicKey.errorDescription)
        XCTAssertNotNil(SecurityError.invalidSignature.errorDescription)
        XCTAssertNotNil(SecurityError.keychainError(-25300).errorDescription)
        XCTAssertNotNil(SecurityError.invalidData.errorDescription)
    }
}

// MARK: - Keychain Key Tests

final class KeychainKeyTests: XCTestCase {

    func testKeychainKeyConstants() {
        XCTAssertEqual(KeychainKey.signingPrivateKey, "com.swetak.signing.private")
        XCTAssertEqual(KeychainKey.signingPublicKey, "com.swetak.signing.public")
        XCTAssertEqual(KeychainKey.encryptionPrivateKey, "com.swetak.encryption.private")
        XCTAssertEqual(KeychainKey.encryptionPublicKey, "com.swetak.encryption.public")
        XCTAssertEqual(KeychainKey.deviceCertificate, "com.swetak.certificate")
        XCTAssertTrue(KeychainKey.peerCertificatePrefix.hasPrefix("com.swetak.peer"))
    }
}

// MARK: - Date Extension Tests

final class DateExtensionTests: XCTestCase {

    func testCurrentMillis() {
        let millis = Date.currentMillis
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        // Should be within 100ms
        XCTAssertEqual(Double(millis), Double(now), accuracy: 100)
    }

    func testCurrentMillisIsPositive() {
        XCTAssertGreaterThan(Date.currentMillis, 0)
    }

    func testCurrentMillisIncreases() {
        let first = Date.currentMillis
        Thread.sleep(forTimeInterval: 0.01) // 10ms
        let second = Date.currentMillis

        XCTAssertGreaterThan(second, first)
    }
}
