import Foundation
import Security
import CryptoKit
import os.log

// MARK: - Device Certificate Info

/// Information about a device certificate
public struct DeviceCertificateInfo: Equatable {
    public let deviceId: String
    public let commonName: String
    public let organization: String
    public let country: String
    public let serialNumber: String
    public let notBefore: Date
    public let notAfter: Date
    public let fingerprint: String

    public var isExpired: Bool {
        Date() > notAfter
    }

    public var isValid: Bool {
        let now = Date()
        return now >= notBefore && now <= notAfter
    }

    public var daysUntilExpiration: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: notAfter).day ?? 0
    }
}

// MARK: - Trusted Peer

/// A trusted peer with stored certificate
public struct TrustedPeer: Identifiable, Codable, Equatable {
    public let id: String
    public let deviceId: String
    public let certificatePEM: String
    public let fingerprint: String
    public let trustedAt: Date
    public var displayName: String?

    public init(
        deviceId: String,
        certificatePEM: String,
        fingerprint: String,
        trustedAt: Date = Date(),
        displayName: String? = nil
    ) {
        self.id = deviceId
        self.deviceId = deviceId
        self.certificatePEM = certificatePEM
        self.fingerprint = fingerprint
        self.trustedAt = trustedAt
        self.displayName = displayName
    }
}

// MARK: - Device Certificate Manager

/// Manages X.509 device certificates for PKI
/// Implements CertificateManagerProtocol
@available(iOS 13.0, macOS 10.15, *)
public final class DeviceCertificateManager: CertificateManagerProtocol, ObservableObject {

    // MARK: - Singleton

    public static let shared = DeviceCertificateManager()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "Certificate")

    // MARK: - Constants

    private static let keyAlias = "swetak_device_key"
    private static let certAlias = "swetak_device_cert"
    private static let rsaKeySize = 2048
    private static let validityYears = 2

    // MARK: - Published State

    @Published public private(set) var certificateInfo: DeviceCertificateInfo?
    @Published public private(set) var trustedPeers: [TrustedPeer] = []

    // MARK: - Properties

    private var _certificate: SecCertificate?
    private var _privateKey: SecKey?
    private var _publicKey: SecKey?

    public var certificate: SecCertificate? {
        _certificate
    }

    public var expirationDate: Date? {
        certificateInfo?.notAfter
    }

    public var publicKey: SecKey? {
        _publicKey
    }

    // MARK: - Initialization

    private init() {
        loadOrGenerateCertificate()
        loadTrustedPeers()
    }

    // MARK: - CertificateManagerProtocol

    public func generateCertificate() throws -> SecCertificate {
        logger.info("Generating new device certificate")

        // Generate RSA key pair
        let privateKey = try generateKeyPair()
        _privateKey = privateKey
        _publicKey = SecKeyCopyPublicKey(privateKey)

        // Get device ID
        let deviceId = TransportCoordinator.shared.deviceId

        // Create self-signed certificate
        // Note: iOS doesn't have built-in certificate generation
        // We need to create the certificate data manually or use a library
        let certificateData = try createSelfSignedCertificate(
            privateKey: privateKey,
            deviceId: deviceId
        )

        // Import certificate
        guard let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) else {
            throw SecurityError.certificateGenerationFailed
        }

        _certificate = certificate

        // Store certificate in Keychain
        try storeCertificate(certificate)

        // Update certificate info
        updateCertificateInfo()

        logger.info("Device certificate generated successfully")

        return certificate
    }

    public func exportPEM() throws -> String {
        guard let certificate = _certificate else {
            throw SecurityError.certificateNotFound
        }

        let data = SecCertificateCopyData(certificate) as Data
        let base64 = data.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])

        return "-----BEGIN CERTIFICATE-----\n\(base64)\n-----END CERTIFICATE-----"
    }

    public func importPeerCertificate(_ pem: String, forDeviceId deviceId: String) throws {
        logger.info("Importing certificate for device: \(deviceId)")

        // Parse PEM
        let base64 = pem
            .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard let data = Data(base64Encoded: base64) else {
            throw SecurityError.invalidData
        }

        // Validate certificate
        guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else {
            throw SecurityError.invalidData
        }

        // Check expiration
        if let expirationDate = getCertificateExpirationDate(certificate) {
            guard expirationDate > Date() else {
                throw SecurityError.certificateNotFound
            }
        }

        // Calculate fingerprint
        let fingerprint = calculateFingerprint(data)

        // Create trusted peer
        let peer = TrustedPeer(
            deviceId: deviceId,
            certificatePEM: pem,
            fingerprint: fingerprint
        )

        // Store in memory and persistence
        trustedPeers.removeAll { $0.deviceId == deviceId }
        trustedPeers.append(peer)
        saveTrustedPeers()

        // Store certificate in Keychain
        try storePeerCertificate(certificate, deviceId: deviceId)

        logger.info("Certificate imported for device: \(deviceId)")
    }

    public func getPeerPublicKey(deviceId: String) throws -> SecKey? {
        guard let peer = trustedPeers.first(where: { $0.deviceId == deviceId }) else {
            return nil
        }

        // Parse PEM to get certificate
        let base64 = peer.certificatePEM
            .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard let data = Data(base64Encoded: base64),
              let certificate = SecCertificateCreateWithData(nil, data as CFData) else {
            return nil
        }

        // Extract public key from certificate
        return SecCertificateCopyKey(certificate)
    }

    // MARK: - Public API

    /// Get or create device certificate
    public func getOrCreateCertificate() -> SecCertificate? {
        if let cert = _certificate {
            return cert
        }

        do {
            return try generateCertificate()
        } catch {
            logger.error("Failed to generate certificate: \(error.localizedDescription)")
            return nil
        }
    }

    /// Export certificate as JSON for network exchange
    public func exportCertificateJSON() throws -> [String: Any] {
        guard let info = certificateInfo else {
            throw SecurityError.certificateNotFound
        }

        let pem = try exportPEM()

        return [
            "deviceId": info.deviceId,
            "certificate": pem,
            "fingerprint": info.fingerprint,
            "notBefore": Int64(info.notBefore.timeIntervalSince1970 * 1000),
            "notAfter": Int64(info.notAfter.timeIntervalSince1970 * 1000)
        ]
    }

    /// Import certificate from JSON
    public func importCertificateFromJSON(_ json: [String: Any]) throws {
        guard let deviceId = json["deviceId"] as? String,
              let pem = json["certificate"] as? String else {
            throw SecurityError.invalidData
        }

        try importPeerCertificate(pem, forDeviceId: deviceId)
    }

    /// Check if a device is trusted
    public func isDeviceTrusted(_ deviceId: String) -> Bool {
        trustedPeers.contains { $0.deviceId == deviceId }
    }

    /// Get trusted device IDs
    public func getTrustedDeviceIds() -> [String] {
        trustedPeers.map { $0.deviceId }
    }

    /// Remove trusted peer
    public func removeTrustedPeer(deviceId: String) {
        trustedPeers.removeAll { $0.deviceId == deviceId }
        saveTrustedPeers()

        // Remove from Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: "\(KeychainKey.peerCertificatePrefix)\(deviceId)"
        ]
        SecItemDelete(query as CFDictionary)

        logger.info("Removed trusted peer: \(deviceId)")
    }

    /// Sign data with device private key
    public func signData(_ data: Data) throws -> Data {
        guard let privateKey = _privateKey else {
            throw SecurityError.keyGenerationFailed
        }

        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            data as CFData,
            &error
        ) as Data? else {
            throw SecurityError.signingFailed
        }

        return signature
    }

    /// Verify signature with peer's public key
    public func verifySignature(_ signature: Data, data: Data, peerDeviceId: String) throws -> Bool {
        guard let publicKey = try getPeerPublicKey(deviceId: peerDeviceId) else {
            throw SecurityError.invalidPublicKey
        }

        var error: Unmanaged<CFError>?
        let result = SecKeyVerifySignature(
            publicKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            data as CFData,
            signature as CFData,
            &error
        )

        return result
    }

    /// Get certificate fingerprint (SHA-256)
    public func getCertificateFingerprint() -> String? {
        certificateInfo?.fingerprint
    }

    // MARK: - Private Methods

    private func loadOrGenerateCertificate() {
        // Try to load existing certificate
        if let certificate = loadCertificateFromKeychain(),
           let privateKey = loadPrivateKeyFromKeychain() {
            _certificate = certificate
            _privateKey = privateKey
            _publicKey = SecKeyCopyPublicKey(privateKey)
            updateCertificateInfo()

            // Check if certificate is expired
            if let info = certificateInfo, info.isExpired {
                logger.warning("Device certificate expired, generating new one")
                do {
                    _ = try generateCertificate()
                } catch {
                    logger.error("Failed to regenerate expired certificate: \(error.localizedDescription)")
                }
            } else {
                logger.info("Loaded existing device certificate")
            }
        } else {
            // Generate new certificate
            do {
                _ = try generateCertificate()
            } catch {
                logger.error("Failed to generate device certificate: \(error.localizedDescription)")
            }
        }
    }

    private func generateKeyPair() throws -> SecKey {
        // Delete existing key if any
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Self.keyAlias.data(using: .utf8)!
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Generate new RSA key pair
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: Self.rsaKeySize,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: Self.keyAlias.data(using: .utf8)!,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw SecurityError.keyGenerationFailed
        }

        return privateKey
    }

    private func createSelfSignedCertificate(privateKey: SecKey, deviceId: String) throws -> Data {
        // Note: iOS doesn't have built-in X.509 certificate creation
        // This is a simplified implementation that creates a basic DER structure
        // For production, consider using a library like OpenSSL or ASN1Kit

        guard let publicKey = SecKeyCopyPublicKey(privateKey),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            throw SecurityError.keyGenerationFailed
        }

        // Calculate validity period
        let notBefore = Date()
        let notAfter = Calendar.current.date(byAdding: .year, value: Self.validityYears, to: notBefore)!

        // Build a minimal self-signed certificate
        // This is a simplified structure - real X.509 requires ASN.1 DER encoding
        var certBuilder = Data()

        // For now, we'll store the public key and metadata in a custom format
        // and rely on the Keychain for actual certificate handling
        let certInfo: [String: Any] = [
            "version": 3,
            "serial": Int64(Date().timeIntervalSince1970 * 1000),
            "subject": [
                "CN": deviceId,
                "O": "sweTAK",
                "C": "SE"
            ],
            "issuer": [
                "CN": deviceId,
                "O": "sweTAK",
                "C": "SE"
            ],
            "notBefore": Int64(notBefore.timeIntervalSince1970),
            "notAfter": Int64(notAfter.timeIntervalSince1970),
            "publicKey": publicKeyData.base64EncodedString()
        ]

        // For a proper implementation, we'd use ASN.1 DER encoding here
        // Since iOS Security framework doesn't expose certificate creation,
        // we store the raw public key and create a "pseudo-certificate"
        certBuilder.append(publicKeyData)

        // Sign the certificate data
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            publicKeyData as CFData,
            &error
        ) as Data? else {
            throw SecurityError.signingFailed
        }

        // Store certificate metadata separately
        storeCertificateMetadata(certInfo)

        // Return just the public key data for now
        // In production, this would be proper DER-encoded X.509
        return publicKeyData
    }

    private func storeCertificateMetadata(_ metadata: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: metadata) {
            UserDefaults.standard.set(data, forKey: "swetak.certificate.metadata")
        }
    }

    private func loadCertificateMetadata() -> [String: Any]? {
        guard let data = UserDefaults.standard.data(forKey: "swetak.certificate.metadata"),
              let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return metadata
    }

    private func storeCertificate(_ certificate: SecCertificate) throws {
        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: Self.certAlias
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: Self.certAlias
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess && status != errSecDuplicateItem {
            throw SecurityError.keychainError(status)
        }
    }

    private func storePeerCertificate(_ certificate: SecCertificate, deviceId: String) throws {
        let label = "\(KeychainKey.peerCertificatePrefix)\(deviceId)"

        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: label
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: label
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess && status != errSecDuplicateItem {
            throw SecurityError.keychainError(status)
        }
    }

    private func loadCertificateFromKeychain() -> SecCertificate? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: Self.certAlias,
            kSecReturnRef as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }

        return result as! SecCertificate?
    }

    private func loadPrivateKeyFromKeychain() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Self.keyAlias.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecReturnRef as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }

        return result as! SecKey?
    }

    private func updateCertificateInfo() {
        guard let metadata = loadCertificateMetadata() else {
            // Create info from certificate if no metadata
            if let cert = _certificate {
                let certData = SecCertificateCopyData(cert) as Data
                let fingerprint = calculateFingerprint(certData)
                let deviceId = TransportCoordinator.shared.deviceId

                certificateInfo = DeviceCertificateInfo(
                    deviceId: deviceId,
                    commonName: deviceId,
                    organization: "sweTAK",
                    country: "SE",
                    serialNumber: String(Int64(Date().timeIntervalSince1970 * 1000)),
                    notBefore: Date(),
                    notAfter: Calendar.current.date(byAdding: .year, value: Self.validityYears, to: Date())!,
                    fingerprint: fingerprint
                )
            }
            return
        }

        let subject = metadata["subject"] as? [String: String] ?? [:]
        let notBeforeTimestamp = metadata["notBefore"] as? Int64 ?? Int64(Date().timeIntervalSince1970)
        let notAfterTimestamp = metadata["notAfter"] as? Int64 ?? Int64(Date().timeIntervalSince1970)

        var fingerprint = ""
        if let cert = _certificate {
            let certData = SecCertificateCopyData(cert) as Data
            fingerprint = calculateFingerprint(certData)
        }

        certificateInfo = DeviceCertificateInfo(
            deviceId: subject["CN"] ?? "",
            commonName: subject["CN"] ?? "",
            organization: subject["O"] ?? "sweTAK",
            country: subject["C"] ?? "SE",
            serialNumber: String(metadata["serial"] as? Int64 ?? 0),
            notBefore: Date(timeIntervalSince1970: TimeInterval(notBeforeTimestamp)),
            notAfter: Date(timeIntervalSince1970: TimeInterval(notAfterTimestamp)),
            fingerprint: fingerprint
        )
    }

    private func getCertificateExpirationDate(_ certificate: SecCertificate) -> Date? {
        // Try to extract expiration from certificate
        // This is a simplified check - real implementation would parse X.509
        if let metadata = loadCertificateMetadata(),
           let notAfterTimestamp = metadata["notAfter"] as? Int64 {
            return Date(timeIntervalSince1970: TimeInterval(notAfterTimestamp))
        }
        return nil
    }

    private func calculateFingerprint(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    // MARK: - Trusted Peers Persistence

    private let trustedPeersKey = "swetak.trusted.peers"

    private func loadTrustedPeers() {
        guard let data = UserDefaults.standard.data(forKey: trustedPeersKey),
              let peers = try? JSONDecoder().decode([TrustedPeer].self, from: data) else {
            trustedPeers = []
            return
        }
        trustedPeers = peers
        logger.info("Loaded \(peers.count) trusted peers")
    }

    private func saveTrustedPeers() {
        guard let data = try? JSONEncoder().encode(trustedPeers) else {
            return
        }
        UserDefaults.standard.set(data, forKey: trustedPeersKey)
    }
}
