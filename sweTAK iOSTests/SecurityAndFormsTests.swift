import XCTest
@testable import sweTAK

/// Tests for Phase 23: Security Framework and Linked Forms
final class SecurityAndFormsTests: XCTestCase {

    // MARK: - Message Signing Tests

    func testSignMessage() {
        let original: [String: Any] = [
            "type": "test",
            "value": 42,
            "nested": ["a": 1, "b": 2]
        ]

        guard let signed = MessageSigning.signMessage(original) else {
            XCTFail("Failed to sign message")
            return
        }

        // Should have signature fields
        XCTAssertNotNil(signed["_sig"] as? String)
        XCTAssertNotNil(signed["_sigTs"] as? Int64)
        XCTAssertEqual(signed["_sigVer"] as? Int, 1)

        // Original fields preserved
        XCTAssertEqual(signed["type"] as? String, "test")
        XCTAssertEqual(signed["value"] as? Int, 42)
    }

    func testVerifyValidSignature() {
        let original: [String: Any] = [
            "action": "ping",
            "id": "123"
        ]

        guard let signed = MessageSigning.signMessage(original) else {
            XCTFail("Failed to sign message")
            return
        }

        let result = MessageSigning.verifyMessage(signed)
        XCTAssertTrue(result.isValid, "Expected valid, got: \(result.description)")
    }

    func testVerifyTamperedMessage() {
        var original: [String: Any] = [
            "action": "ping",
            "id": "123"
        ]

        guard var signed = MessageSigning.signMessage(original) else {
            XCTFail("Failed to sign message")
            return
        }

        // Tamper with the message
        signed["id"] = "456"

        let result = MessageSigning.verifyMessage(signed)
        XCTAssertEqual(result, .invalidSignature)
    }

    func testVerifyMissingSignature() {
        let message: [String: Any] = [
            "action": "ping",
            "_sigTs": Date.currentMillis,
            "_sigVer": 1
        ]

        let result = MessageSigning.verifyMessage(message)
        XCTAssertEqual(result, .missingSignature)
    }

    func testVerifyMissingTimestamp() {
        let message: [String: Any] = [
            "action": "ping",
            "_sig": "abc123",
            "_sigVer": 1
        ]

        let result = MessageSigning.verifyMessage(message)
        XCTAssertEqual(result, .missingTimestamp)
    }

    func testVerifyExpiredSignature() {
        var message: [String: Any] = [
            "action": "ping",
            "_sigTs": Date.currentMillis - (10 * 60 * 1000), // 10 minutes ago
            "_sigVer": 1,
            "_sig": "placeholder"
        ]

        // Sign with old timestamp
        let result = MessageSigning.verifyMessage(message, checkTimestamp: true)
        XCTAssertEqual(result, .expired)
    }

    func testSigningKeyExportImport() {
        guard let exported = MessageSigning.exportSigningKey() else {
            XCTFail("Failed to export signing key")
            return
        }

        // Key should be Base64 encoded 32-byte key
        guard let keyData = Data(base64Encoded: exported) else {
            XCTFail("Invalid Base64 key")
            return
        }
        XCTAssertEqual(keyData.count, 32)
    }

    // MARK: - Linked Form Model Tests

    func testLinkedFormCreation() {
        let form = LinkedForm(
            id: 12345,
            opPinId: 1,
            opOriginDeviceId: "device-123",
            formType: "CFF",
            formData: "{\"test\": true}",
            authorCallsign: "ALPHA-1",
            targetLat: 59.3293,
            targetLon: 18.0686
        )

        XCTAssertEqual(form.id, 12345)
        XCTAssertEqual(form.formType, "CFF")
        XCTAssertEqual(form.targetLat, 59.3293)
        XCTAssertEqual(form.targetLon, 18.0686)
    }

    func testLinkedFormExtensions() {
        let form = LinkedForm(
            id: 12345,
            opPinId: 1,
            opOriginDeviceId: "device-123",
            formType: "CFF",
            formData: "{\"test\": true}",
            authorCallsign: "ALPHA-1",
            targetLat: 59.3293,
            targetLon: 18.0686,
            observerLat: 59.330,
            observerLon: 18.070
        )

        XCTAssertNotNil(form.targetCoordinate)
        XCTAssertEqual(form.targetCoordinate?.latitude ?? 0, 59.3293, accuracy: 0.0001)
        XCTAssertNotNil(form.observerCoordinate)
        XCTAssertNotNil(form.submittedAt)
    }

    func testLinkedFormTypes() {
        XCTAssertEqual(LinkedFormType.callForFire.rawValue, "CFF")
        XCTAssertEqual(LinkedFormType.medevac.displayName, "9-Line MEDEVAC")
        XCTAssertEqual(LinkedFormType.spot.abbreviation, "SPOT")
    }

    func testCallForFireDataSerialization() {
        let cff = CallForFireData(
            observerId: "OBSERVER-1",
            targetLocation: "12ABC1234567890",
            targetDescription: "Enemy position, 3 vehicles",
            methodOfEngagement: "ADJUST FIRE",
            remarks: "Priority target"
        )

        guard let json = cff.toJSONString() else {
            XCTFail("Failed to serialize CFF")
            return
        }

        guard let decoded = CallForFireData.fromJSONString(json) else {
            XCTFail("Failed to deserialize CFF")
            return
        }

        XCTAssertEqual(decoded.observerId, "OBSERVER-1")
        XCTAssertEqual(decoded.targetLocation, "12ABC1234567890")
        XCTAssertEqual(decoded.targetDescription, "Enemy position, 3 vehicles")
    }

    func testSpotReportDataSerialization() {
        let spot = SpotReportData(
            size: "Squad-sized element (~10)",
            activity: "Establishing defensive positions",
            location: "Grid 12345678",
            unit: "Unknown, wearing dark uniforms",
            time: "1430Z",
            equipment: "Small arms, 1 RPG observed"
        )

        guard let json = spot.toJSONString() else {
            XCTFail("Failed to serialize spot report")
            return
        }

        guard let decoded = SpotReportData.fromJSONString(json) else {
            XCTFail("Failed to deserialize spot report")
            return
        }

        XCTAssertEqual(decoded.size, "Squad-sized element (~10)")
        XCTAssertTrue(decoded.saluteSummary.contains("S: Squad-sized"))
    }

    func testContactReportDataSerialization() {
        let contact = ContactReportData(
            contactType: .directFire,
            location: "Grid 12345678",
            enemySize: "Platoon",
            enemyActivity: "Ambush from treeline",
            friendlyCasualties: "1 WIA",
            friendlyActions: "Returning fire, maneuvering",
            supportRequest: "CAS requested",
            status: .ongoing
        )

        guard let json = contact.toJSONString() else {
            XCTFail("Failed to serialize contact report")
            return
        }

        guard let decoded = ContactReportData.fromJSONString(json) else {
            XCTFail("Failed to deserialize contact report")
            return
        }

        XCTAssertEqual(decoded.contactType, .directFire)
        XCTAssertEqual(decoded.status, .ongoing)
        XCTAssertEqual(decoded.friendlyCasualties, "1 WIA")
    }

    func testObservationNoteDataSerialization() {
        let obs = ObservationNoteData(
            content: "Movement detected on ridge line",
            priority: .priority,
            weatherConditions: "Clear",
            visibility: "Good, 5km+"
        )

        guard let json = obs.toJSONString() else {
            XCTFail("Failed to serialize observation")
            return
        }

        guard let decoded = ObservationNoteData.fromJSONString(json) else {
            XCTFail("Failed to deserialize observation")
            return
        }

        XCTAssertEqual(decoded.content, "Movement detected on ridge line")
        XCTAssertEqual(decoded.priority, .priority)
    }

    func testFireAdjustmentDataSerialization() {
        let adj = FireAdjustmentData(
            originalFormId: 12345,
            adjustmentType: .right,
            direction: "100 mils",
            distance: 50,
            vertical: "ADD 25",
            fireCommand: "FIRE FOR EFFECT"
        )

        guard let json = adj.toJSONString() else {
            XCTFail("Failed to serialize fire adjustment")
            return
        }

        guard let decoded = FireAdjustmentData.fromJSONString(json) else {
            XCTFail("Failed to deserialize fire adjustment")
            return
        }

        XCTAssertEqual(decoded.adjustmentType, .right)
        XCTAssertEqual(decoded.distance, 50)
    }

    // MARK: - Form ID Generation

    func testFormIdGeneration() {
        let id1 = Int64(Date().timeIntervalSince1970 * 1000)
        Thread.sleep(forTimeInterval: 0.001) // 1ms
        let id2 = Int64(Date().timeIntervalSince1970 * 1000)

        XCTAssertGreaterThanOrEqual(id2, id1)
    }

    // MARK: - Encryption Tests (RSA Key Generation)

    func testRSAKeyPairGeneration() {
        // Clean up any existing keys first
        _ = MessageEncryption.deleteKeyPair()

        guard let keyPair = MessageEncryption.getOrCreateKeyPair() else {
            XCTFail("Failed to generate RSA key pair")
            return
        }

        // Verify we can export the public key
        guard let exportedKey = MessageEncryption.exportPublicKey() else {
            XCTFail("Failed to export public key")
            return
        }

        XCTAssertFalse(exportedKey.isEmpty)

        // Verify we can re-import the public key
        guard let reimported = MessageEncryption.importPublicKey(exportedKey) else {
            XCTFail("Failed to re-import public key")
            return
        }

        XCTAssertNotNil(reimported)
    }

    func testEncryptDecryptRoundTrip() throws {
        // Get or create key pair
        guard let keyPair = MessageEncryption.getOrCreateKeyPair() else {
            XCTFail("Failed to get key pair")
            return
        }

        let plaintext = "Secret message for testing encryption"

        // Encrypt
        let encrypted = try MessageEncryption.encryptMessage(
            plaintext,
            recipientPublicKey: keyPair.publicKey
        )

        XCTAssertFalse(encrypted.encryptedKey.isEmpty)
        XCTAssertFalse(encrypted.iv.isEmpty)
        XCTAssertFalse(encrypted.ciphertext.isEmpty)
        XCTAssertFalse(encrypted.tag.isEmpty)
        XCTAssertEqual(encrypted.version, 1)

        // Decrypt
        let decrypted: String = try MessageEncryption.decryptMessage(
            encrypted,
            privateKey: keyPair.privateKey
        )

        XCTAssertEqual(decrypted, plaintext)
    }

    func testEncryptDecryptJSON() throws {
        guard let keyPair = MessageEncryption.getOrCreateKeyPair() else {
            XCTFail("Failed to get key pair")
            return
        }

        let original: [String: Any] = [
            "type": "secret",
            "data": [
                "value": 123,
                "flag": true
            ]
        ]

        // Encrypt
        let encrypted = try MessageEncryption.encryptJSON(
            original,
            recipientPublicKey: keyPair.publicKey
        )

        // Decrypt
        let decrypted = try MessageEncryption.decryptJSON(
            encrypted,
            privateKey: keyPair.privateKey
        )

        XCTAssertEqual(decrypted["type"] as? String, "secret")
        let nestedData = decrypted["data"] as? [String: Any]
        XCTAssertEqual(nestedData?["value"] as? Int, 123)
        XCTAssertEqual(nestedData?["flag"] as? Bool, true)
    }

    func testEncryptedMessageCodable() throws {
        let message = MessageEncryption.EncryptedMessage(
            encryptedKey: "base64key==",
            iv: "base64iv==",
            ciphertext: "base64cipher==",
            tag: "base64tag=="
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MessageEncryption.EncryptedMessage.self, from: data)

        XCTAssertEqual(decoded.encryptedKey, message.encryptedKey)
        XCTAssertEqual(decoded.iv, message.iv)
        XCTAssertEqual(decoded.ciphertext, message.ciphertext)
        XCTAssertEqual(decoded.tag, message.tag)
        XCTAssertEqual(decoded.version, 1)
    }

    // MARK: - Verification Result Tests

    func testVerificationResultEquality() {
        XCTAssertEqual(MessageSigning.VerificationResult.valid, .valid)
        XCTAssertEqual(MessageSigning.VerificationResult.invalidSignature, .invalidSignature)
        XCTAssertNotEqual(MessageSigning.VerificationResult.valid, .expired)
    }

    func testVerificationResultDescription() {
        XCTAssertEqual(
            MessageSigning.VerificationResult.valid.description,
            "Valid signature"
        )
        XCTAssertEqual(
            MessageSigning.VerificationResult.expired.description,
            "Signature expired"
        )
        XCTAssertTrue(
            MessageSigning.VerificationResult.error("test").description.contains("test")
        )
    }

    // MARK: - Contact Types Tests

    func testContactTypes() {
        XCTAssertEqual(
            ContactReportData.ContactType.directFire.displayName,
            "Direct Fire"
        )
        XCTAssertEqual(
            ContactReportData.ContactType.ied.displayName,
            "IED/UXO"
        )
        XCTAssertEqual(ContactReportData.ContactType.allCases.count, 7)
    }

    func testContactStatus() {
        XCTAssertEqual(
            ContactReportData.ContactStatus.ongoing.displayName,
            "Ongoing"
        )
        XCTAssertEqual(
            ContactReportData.ContactStatus.breaking.displayName,
            "Breaking Contact"
        )
    }

    // MARK: - Observation Priority Tests

    func testObservationPriority() {
        XCTAssertEqual(
            ObservationNoteData.Priority.routine.displayName,
            "Routine"
        )
        XCTAssertEqual(
            ObservationNoteData.Priority.flash.displayName,
            "Flash"
        )
        XCTAssertEqual(ObservationNoteData.Priority.allCases.count, 4)
    }

    // MARK: - Fire Adjustment Types Tests

    func testFireAdjustmentTypes() {
        XCTAssertEqual(FireAdjustmentData.AdjustmentType.add.rawValue, "ADD")
        XCTAssertEqual(FireAdjustmentData.AdjustmentType.fireForEffect.rawValue, "FFE")
        XCTAssertEqual(FireAdjustmentData.AdjustmentType.endOfMission.rawValue, "EOM")
    }
}
