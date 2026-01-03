import Foundation
import CryptoKit
import Security

/// HMAC-SHA256 message signing implementation
@available(iOS 13.0, macOS 10.15, *)
public final class MessageSigner: MessageSigningProtocol {

    // MARK: - Singleton

    public static let shared = MessageSigner()

    // MARK: - Properties

    private var signingKey: SymmetricKey?
    private var _publicKey: Data?

    public var publicKey: Data {
        if let key = _publicKey {
            return key
        }
        // Generate key pair on first access
        do {
            try generateKeyPair()
            return _publicKey ?? Data()
        } catch {
            print("MessageSigner: Failed to generate key pair: \(error)")
            return Data()
        }
    }

    // MARK: - Initialization

    private init() {
        loadOrGenerateKeys()
    }

    // MARK: - Key Management

    private func loadOrGenerateKeys() {
        // Try to load existing key from Keychain
        if let existingKey = loadKeyFromKeychain() {
            signingKey = existingKey
            _publicKey = existingKey.withUnsafeBytes { Data($0) }
        } else {
            // Generate new key pair
            do {
                try generateKeyPair()
            } catch {
                print("MessageSigner: Failed to initialize: \(error)")
            }
        }
    }

    private func generateKeyPair() throws {
        // Generate 256-bit symmetric key for HMAC
        let key = SymmetricKey(size: .bits256)
        signingKey = key

        // Store key bytes as "public key" (shared secret in this HMAC scheme)
        _publicKey = key.withUnsafeBytes { Data($0) }

        // Save to Keychain
        try saveKeyToKeychain(key)
    }

    private func loadKeyFromKeychain() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKey.signingPrivateKey,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return SymmetricKey(data: data)
    }

    private func saveKeyToKeychain(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }

        // Delete existing key
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKey.signingPrivateKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new key
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKey.signingPrivateKey,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecurityError.keychainError(status)
        }
    }

    // MARK: - MessageSigningProtocol

    public func sign(message: Data) throws -> Data {
        guard let key = signingKey else {
            throw SecurityError.keyGenerationFailed
        }

        let signature = HMAC<SHA256>.authenticationCode(for: message, using: key)
        return Data(signature)
    }

    public func verify(message: Data, signature: Data, publicKey: Data) throws -> Bool {
        // In this HMAC scheme, "publicKey" is actually the shared secret
        let key = SymmetricKey(data: publicKey)
        return HMAC<SHA256>.isValidAuthenticationCode(signature, authenticating: message, using: key)
    }

    // MARK: - Convenience Methods

    /// Sign a message and return Base64-encoded signature
    public func signBase64(message: Data) throws -> String {
        let signature = try sign(message: message)
        return signature.base64EncodedString()
    }

    /// Verify a Base64-encoded signature
    public func verifyBase64(message: Data, signatureBase64: String, publicKeyBase64: String) throws -> Bool {
        guard let signature = Data(base64Encoded: signatureBase64),
              let publicKey = Data(base64Encoded: publicKeyBase64) else {
            throw SecurityError.invalidData
        }
        return try verify(message: message, signature: signature, publicKey: publicKey)
    }

    /// Get public key as Base64 string
    public var publicKeyBase64: String {
        publicKey.base64EncodedString()
    }
}

// MARK: - Network Message Extension

@available(iOS 13.0, macOS 10.15, *)
extension NetworkMessage {
    /// Sign this message and return a new message with signature
    public func signed(with signer: MessageSigner = .shared) throws -> NetworkMessage {
        let jsonData = try toJSONData()
        let signature = try signer.signBase64(message: jsonData)

        return NetworkMessage(
            type: type,
            deviceId: deviceId,
            timestamp: timestamp,
            payload: payload,
            signature: signature,
            publicKey: signer.publicKeyBase64,
            encrypted: encrypted,
            encryptedPayload: encryptedPayload
        )
    }

    /// Verify this message's signature
    public func verifySignature(with signer: MessageSigner = .shared) throws -> Bool {
        guard let signature = signature,
              let publicKey = publicKey else {
            return false
        }

        // Create unsigned copy for verification
        var unsignedPayload = payload
        let jsonData: Data

        // Reconstruct the original message that was signed
        var json: [String: Any] = [
            "type": type.rawValue,
            "deviceId": deviceId,
            "timestamp": timestamp,
            "payload": unsignedPayload
        ]

        jsonData = try JSONSerialization.data(withJSONObject: json, options: [])

        return try signer.verifyBase64(message: jsonData, signatureBase64: signature, publicKeyBase64: publicKey)
    }
}
