import Foundation
import CryptoKit
import Security

/// AES-256-GCM + RSA-2048 hybrid encryption implementation
@available(iOS 13.0, macOS 10.15, *)
public final class MessageEncryptor: MessageEncryptionProtocol {

    // MARK: - Singleton

    public static let shared = MessageEncryptor()

    // MARK: - Properties

    private var privateKey: SecKey?
    private var _publicKey: SecKey?

    public var publicKeyData: Data? {
        guard let publicKey = _publicKey else { return nil }
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }
        return data
    }

    // MARK: - Initialization

    private init() {
        loadOrGenerateKeyPair()
    }

    // MARK: - Key Management

    private func loadOrGenerateKeyPair() {
        // Try to load existing keys from Keychain
        if let existingPrivateKey = loadPrivateKeyFromKeychain() {
            privateKey = existingPrivateKey
            _publicKey = SecKeyCopyPublicKey(existingPrivateKey)
        } else {
            // Generate new key pair
            do {
                try generateKeyPair()
            } catch {
                print("MessageEncryptor: Failed to initialize: \(error)")
            }
        }
    }

    private func generateKeyPair() throws {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: KeychainKey.encryptionPrivateKey.data(using: .utf8)!,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
        ]

        var error: Unmanaged<CFError>?
        guard let newPrivateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw SecurityError.keyGenerationFailed
        }

        privateKey = newPrivateKey
        _publicKey = SecKeyCopyPublicKey(newPrivateKey)
    }

    private func loadPrivateKeyFromKeychain() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: KeychainKey.encryptionPrivateKey.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecReturnRef as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        return result as! SecKey?
    }

    // MARK: - MessageEncryptionProtocol

    public func encrypt(data: Data, recipientPublicKey: Data) throws -> EncryptedPayload {
        // 1. Generate random AES-256 key
        let aesKey = SymmetricKey(size: .bits256)

        // 2. Generate random IV
        var ivBytes = [UInt8](repeating: 0, count: 12)
        _ = SecRandomCopyBytes(kSecRandomDefault, 12, &ivBytes)
        let iv = Data(ivBytes)

        // 3. Encrypt data with AES-GCM
        let nonce = try AES.GCM.Nonce(data: iv)
        let sealedBox = try AES.GCM.seal(data, using: aesKey, nonce: nonce)

        // 4. Extract ciphertext and tag
        guard let ciphertext = sealedBox.ciphertext as Data?,
              let tag = sealedBox.tag as Data? else {
            throw SecurityError.encryptionFailed
        }

        // 5. Encrypt AES key with recipient's RSA public key
        let recipientKey = try importPublicKey(recipientPublicKey)
        let aesKeyData = aesKey.withUnsafeBytes { Data($0) }

        guard SecKeyIsAlgorithmSupported(recipientKey, .encrypt, .rsaEncryptionOAEPSHA256) else {
            throw SecurityError.encryptionFailed
        }

        var error: Unmanaged<CFError>?
        guard let encryptedKey = SecKeyCreateEncryptedData(
            recipientKey,
            .rsaEncryptionOAEPSHA256,
            aesKeyData as CFData,
            &error
        ) as Data? else {
            throw SecurityError.encryptionFailed
        }

        return EncryptedPayload(
            encryptedData: ciphertext.base64EncodedString(),
            encryptedKey: encryptedKey.base64EncodedString(),
            iv: iv.base64EncodedString(),
            tag: tag.base64EncodedString()
        )
    }

    public func decrypt(payload: EncryptedPayload) throws -> Data {
        guard let privateKey = privateKey else {
            throw SecurityError.keyGenerationFailed
        }

        // 1. Decode Base64 components
        guard let encryptedData = Data(base64Encoded: payload.encryptedData),
              let encryptedKey = Data(base64Encoded: payload.encryptedKey),
              let iv = Data(base64Encoded: payload.iv),
              let tag = Data(base64Encoded: payload.tag) else {
            throw SecurityError.invalidData
        }

        // 2. Decrypt AES key with RSA private key
        var error: Unmanaged<CFError>?
        guard let aesKeyData = SecKeyCreateDecryptedData(
            privateKey,
            .rsaEncryptionOAEPSHA256,
            encryptedKey as CFData,
            &error
        ) as Data? else {
            throw SecurityError.decryptionFailed
        }

        let aesKey = SymmetricKey(data: aesKeyData)

        // 3. Decrypt data with AES-GCM
        let nonce = try AES.GCM.Nonce(data: iv)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: encryptedData, tag: tag)
        let decryptedData = try AES.GCM.open(sealedBox, using: aesKey)

        return decryptedData
    }

    // MARK: - Helper Methods

    private func importPublicKey(_ data: Data) throws -> SecKey {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 2048
        ]

        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(data as CFData, attributes as CFDictionary, &error) else {
            throw SecurityError.invalidPublicKey
        }

        return key
    }

    /// Get public key as Base64 string
    public var publicKeyBase64: String? {
        publicKeyData?.base64EncodedString()
    }

    /// Import a public key from Base64 string
    public func importPublicKeyBase64(_ base64: String) throws -> SecKey {
        guard let data = Data(base64Encoded: base64) else {
            throw SecurityError.invalidData
        }
        return try importPublicKey(data)
    }
}

// MARK: - Network Message Extension

@available(iOS 13.0, macOS 10.15, *)
extension NetworkMessage {
    /// Encrypt this message for specific recipients
    public func encrypted(for recipientPublicKeys: [String: Data], with encryptor: MessageEncryptor = .shared) throws -> [String: NetworkMessage] {
        var encryptedMessages: [String: NetworkMessage] = [:]

        let jsonData = try toJSONData()

        for (deviceId, publicKey) in recipientPublicKeys {
            let encryptedPayload = try encryptor.encrypt(data: jsonData, recipientPublicKey: publicKey)
            let payloadJSON = try JSONEncoder().encode(encryptedPayload)
            let payloadString = String(data: payloadJSON, encoding: .utf8) ?? ""

            let encryptedMessage = NetworkMessage(
                type: type,
                deviceId: self.deviceId,
                timestamp: timestamp,
                payload: [:],  // Original payload is encrypted
                signature: signature,
                publicKey: self.publicKey,
                encrypted: true,
                encryptedPayload: payloadString
            )

            encryptedMessages[deviceId] = encryptedMessage
        }

        return encryptedMessages
    }

    /// Decrypt this message
    public func decrypted(with encryptor: MessageEncryptor = .shared) throws -> NetworkMessage {
        guard encrypted,
              let encryptedPayloadString = encryptedPayload,
              let encryptedPayloadData = encryptedPayloadString.data(using: .utf8) else {
            return self  // Not encrypted
        }

        let payload = try JSONDecoder().decode(EncryptedPayload.self, from: encryptedPayloadData)
        let decryptedData = try encryptor.decrypt(payload: payload)

        // Parse decrypted JSON
        guard let decryptedJSON = try JSONSerialization.jsonObject(with: decryptedData) as? [String: Any] else {
            throw SecurityError.invalidData
        }

        // Reconstruct message from decrypted payload
        return try NetworkMessage.fromJSONData(decryptedData)
    }
}
