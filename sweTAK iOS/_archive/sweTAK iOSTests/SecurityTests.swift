import XCTest
@testable import sweTAK

final class SecurityTests: XCTestCase {

    // MARK: - Message Signing Tests

    func testMessageSigning() throws {
        let signer = MessageSigner.shared
        let message = "Test message for signing".data(using: .utf8)!

        let signature = try signer.sign(message: message)

        XCTAssertFalse(signature.isEmpty)
        XCTAssertEqual(signature.count, 32) // SHA256 produces 32 bytes
    }

    func testSignatureVerification() throws {
        let signer = MessageSigner.shared
        let message = "Test message for signing".data(using: .utf8)!

        let signature = try signer.sign(message: message)
        let isValid = try signer.verify(message: message, signature: signature, publicKey: signer.publicKey)

        XCTAssertTrue(isValid)
    }

    func testSignatureInvalidForModifiedMessage() throws {
        let signer = MessageSigner.shared
        let originalMessage = "Original message".data(using: .utf8)!
        let modifiedMessage = "Modified message".data(using: .utf8)!

        let signature = try signer.sign(message: originalMessage)
        let isValid = try signer.verify(message: modifiedMessage, signature: signature, publicKey: signer.publicKey)

        XCTAssertFalse(isValid)
    }

    func testBase64Signing() throws {
        let signer = MessageSigner.shared
        let message = "Test message".data(using: .utf8)!

        let signatureBase64 = try signer.signBase64(message: message)

        XCTAssertFalse(signatureBase64.isEmpty)
        XCTAssertNotNil(Data(base64Encoded: signatureBase64))
    }

    // MARK: - Network Message Signing Tests

    func testNetworkMessageSigning() throws {
        let message = NetworkMessage(
            type: .position,
            deviceId: "test-device",
            payload: [
                "lat": 59.329323,
                "lon": 18.068581,
                "callsign": "Alpha-1"
            ]
        )

        let signedMessage = try message.signed()

        XCTAssertNotNil(signedMessage.signature)
        XCTAssertNotNil(signedMessage.publicKey)
    }

    // MARK: - Encrypted Payload Tests

    func testEncryptedPayloadCodable() throws {
        let payload = EncryptedPayload(
            encryptedData: "SGVsbG8gV29ybGQ=",
            encryptedKey: "a2V5ZGF0YQ==",
            iv: "aXZkYXRh",
            tag: "dGFnZGF0YQ=="
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(EncryptedPayload.self, from: data)

        XCTAssertEqual(decoded.encryptedData, payload.encryptedData)
        XCTAssertEqual(decoded.encryptedKey, payload.encryptedKey)
        XCTAssertEqual(decoded.iv, payload.iv)
        XCTAssertEqual(decoded.tag, payload.tag)
    }

    // MARK: - Security Configuration Tests

    func testSecurityConfigurationDefaults() {
        let config = SecurityConfiguration()

        XCTAssertTrue(config.signingEnabled)
        XCTAssertTrue(config.autoVerifySignatures)
        XCTAssertFalse(config.rejectUnsignedMessages)
        XCTAssertFalse(config.encryptionEnabled)
        XCTAssertEqual(config.maxMessageAgeMs, 5 * 60 * 1000)
    }

    func testSecurityConfigurationCodable() throws {
        let config = SecurityConfiguration(
            signingEnabled: true,
            autoVerifySignatures: true,
            rejectUnsignedMessages: true,
            encryptionEnabled: true,
            maxMessageAgeMs: 10 * 60 * 1000
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SecurityConfiguration.self, from: data)

        XCTAssertEqual(decoded.signingEnabled, config.signingEnabled)
        XCTAssertEqual(decoded.rejectUnsignedMessages, config.rejectUnsignedMessages)
        XCTAssertEqual(decoded.encryptionEnabled, config.encryptionEnabled)
        XCTAssertEqual(decoded.maxMessageAgeMs, config.maxMessageAgeMs)
    }
}
