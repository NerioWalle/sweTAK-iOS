import Foundation
import CryptoKit
import Security

// MARK: - Message Signing Protocol

/// Protocol for HMAC-SHA256 message signing
public protocol MessageSigningProtocol {
    /// Sign a message with the device's private key
    func sign(message: Data) throws -> Data

    /// Verify a message signature
    func verify(message: Data, signature: Data, publicKey: Data) throws -> Bool

    /// Get the public key for sharing
    var publicKey: Data { get }
}

// MARK: - Message Encryption Protocol

/// Protocol for AES-256-GCM + RSA-2048 hybrid encryption
public protocol MessageEncryptionProtocol {
    /// Encrypt data for a recipient's public key
    func encrypt(data: Data, recipientPublicKey: Data) throws -> EncryptedPayload

    /// Decrypt data using device's private key
    func decrypt(payload: EncryptedPayload) throws -> Data
}

// MARK: - Encrypted Payload

/// Container for encrypted message data
public struct EncryptedPayload: Codable, Equatable {
    /// AES-encrypted data (Base64)
    public let encryptedData: String

    /// RSA-encrypted AES key (Base64)
    public let encryptedKey: String

    /// AES-GCM initialization vector (Base64)
    public let iv: String

    /// AES-GCM authentication tag (Base64)
    public let tag: String

    public init(encryptedData: String, encryptedKey: String, iv: String, tag: String) {
        self.encryptedData = encryptedData
        self.encryptedKey = encryptedKey
        self.iv = iv
        self.tag = tag
    }
}

// MARK: - Certificate Manager Protocol

/// Protocol for X.509 certificate management
public protocol CertificateManagerProtocol {
    /// Generate a new self-signed certificate
    func generateCertificate() throws -> SecCertificate

    /// Get the current device certificate
    var certificate: SecCertificate? { get }

    /// Get certificate expiration date
    var expirationDate: Date? { get }

    /// Export certificate as PEM string
    func exportPEM() throws -> String

    /// Import a peer certificate
    func importPeerCertificate(_ pem: String, forDeviceId: String) throws

    /// Get peer's public key from stored certificate
    func getPeerPublicKey(deviceId: String) throws -> SecKey?
}

// MARK: - Security Errors

public enum SecurityError: Error, LocalizedError {
    case keyGenerationFailed
    case signingFailed
    case verificationFailed
    case encryptionFailed
    case decryptionFailed
    case certificateGenerationFailed
    case certificateNotFound
    case invalidPublicKey
    case invalidSignature
    case keychainError(OSStatus)
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate cryptographic keys"
        case .signingFailed:
            return "Failed to sign message"
        case .verificationFailed:
            return "Failed to verify signature"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .certificateGenerationFailed:
            return "Failed to generate certificate"
        case .certificateNotFound:
            return "Certificate not found"
        case .invalidPublicKey:
            return "Invalid public key"
        case .invalidSignature:
            return "Invalid signature"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .invalidData:
            return "Invalid data format"
        }
    }
}

// MARK: - Security Configuration

public struct SecurityConfiguration: Codable, Equatable {
    /// Enable message signing (HMAC-SHA256)
    public var signingEnabled: Bool

    /// Automatically verify incoming message signatures
    public var autoVerifySignatures: Bool

    /// Reject messages with invalid/missing signatures
    public var rejectUnsignedMessages: Bool

    /// Enable message encryption (AES-256-GCM + RSA-2048)
    public var encryptionEnabled: Bool

    /// Maximum age for accepting messages (anti-replay, in milliseconds)
    public var maxMessageAgeMs: Int64

    public init(
        signingEnabled: Bool = true,
        autoVerifySignatures: Bool = true,
        rejectUnsignedMessages: Bool = false,
        encryptionEnabled: Bool = false,
        maxMessageAgeMs: Int64 = 5 * 60 * 1000  // 5 minutes
    ) {
        self.signingEnabled = signingEnabled
        self.autoVerifySignatures = autoVerifySignatures
        self.rejectUnsignedMessages = rejectUnsignedMessages
        self.encryptionEnabled = encryptionEnabled
        self.maxMessageAgeMs = maxMessageAgeMs
    }
}

// MARK: - Keychain Keys

public enum KeychainKey {
    public static let signingPrivateKey = "com.swetak.signing.private"
    public static let signingPublicKey = "com.swetak.signing.public"
    public static let encryptionPrivateKey = "com.swetak.encryption.private"
    public static let encryptionPublicKey = "com.swetak.encryption.public"
    public static let deviceCertificate = "com.swetak.certificate"
    public static let peerCertificatePrefix = "com.swetak.peer."
}
