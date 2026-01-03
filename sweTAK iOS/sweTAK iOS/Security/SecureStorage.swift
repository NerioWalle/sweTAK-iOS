import Foundation
import Security

// MARK: - Secure Storage Error

/// Errors that can occur during secure storage operations
public enum SecureStorageError: Error, LocalizedError {
    case dataConversionFailed
    case keychainError(OSStatus)
    case itemNotFound
    case unexpectedData
    case encodingFailed
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .dataConversionFailed:
            return "Failed to convert data for storage"
        case .keychainError(let status):
            return "Keychain error: \(SecureStorage.keychainErrorMessage(status))"
        case .itemNotFound:
            return "Item not found in secure storage"
        case .unexpectedData:
            return "Unexpected data format in secure storage"
        case .encodingFailed:
            return "Failed to encode data for storage"
        case .decodingFailed:
            return "Failed to decode data from storage"
        }
    }
}

// MARK: - Secure Storage

/// Secure storage using iOS Keychain
/// Mirrors Android SecurePreferences/EncryptedSharedPreferences functionality
public final class SecureStorage {

    // MARK: - Singleton

    public static let shared = SecureStorage()

    // MARK: - Constants

    private let serviceName = "com.swetak.securestorage"

    // MARK: - Init

    private init() {}

    // MARK: - String Storage

    /// Store a string value securely
    public func setString(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw SecureStorageError.dataConversionFailed
        }
        try setData(data, forKey: key)
    }

    /// Retrieve a string value
    public func getString(forKey key: String) throws -> String {
        let data = try getData(forKey: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw SecureStorageError.unexpectedData
        }
        return string
    }

    /// Retrieve a string value or nil if not found
    public func getStringOrNil(forKey key: String) -> String? {
        try? getString(forKey: key)
    }

    // MARK: - Data Storage

    /// Store raw data securely
    public func setData(_ data: Data, forKey key: String) throws {
        // First try to delete any existing item
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecureStorageError.keychainError(status)
        }
    }

    /// Retrieve raw data
    public func getData(forKey key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw SecureStorageError.itemNotFound
            }
            throw SecureStorageError.keychainError(status)
        }

        guard let data = result as? Data else {
            throw SecureStorageError.unexpectedData
        }

        return data
    }

    /// Retrieve data or nil if not found
    public func getDataOrNil(forKey key: String) -> Data? {
        try? getData(forKey: key)
    }

    // MARK: - Codable Storage

    /// Store a Codable object securely
    public func setCodable<T: Encodable>(_ value: T, forKey key: String) throws {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(value) else {
            throw SecureStorageError.encodingFailed
        }
        try setData(data, forKey: key)
    }

    /// Retrieve a Codable object
    public func getCodable<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T {
        let data = try getData(forKey: key)
        let decoder = JSONDecoder()
        guard let value = try? decoder.decode(type, from: data) else {
            throw SecureStorageError.decodingFailed
        }
        return value
    }

    /// Retrieve a Codable object or nil if not found
    public func getCodableOrNil<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        try? getCodable(type, forKey: key)
    }

    // MARK: - Boolean Storage

    /// Store a boolean value
    public func setBool(_ value: Bool, forKey key: String) throws {
        let data = Data([value ? 1 : 0])
        try setData(data, forKey: key)
    }

    /// Retrieve a boolean value
    public func getBool(forKey key: String) throws -> Bool {
        let data = try getData(forKey: key)
        guard let byte = data.first else {
            throw SecureStorageError.unexpectedData
        }
        return byte != 0
    }

    /// Retrieve a boolean value with default
    public func getBool(forKey key: String, default defaultValue: Bool) -> Bool {
        (try? getBool(forKey: key)) ?? defaultValue
    }

    // MARK: - Integer Storage

    /// Store an integer value
    public func setInt(_ value: Int, forKey key: String) throws {
        var intValue = value
        let data = Data(bytes: &intValue, count: MemoryLayout<Int>.size)
        try setData(data, forKey: key)
    }

    /// Retrieve an integer value
    public func getInt(forKey key: String) throws -> Int {
        let data = try getData(forKey: key)
        guard data.count == MemoryLayout<Int>.size else {
            throw SecureStorageError.unexpectedData
        }
        return data.withUnsafeBytes { $0.load(as: Int.self) }
    }

    /// Retrieve an integer value with default
    public func getInt(forKey key: String, default defaultValue: Int) -> Int {
        (try? getInt(forKey: key)) ?? defaultValue
    }

    // MARK: - Delete

    /// Delete a value from secure storage
    public func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStorageError.keychainError(status)
        }
    }

    /// Delete all values for this service
    public func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStorageError.keychainError(status)
        }
    }

    // MARK: - Existence Check

    /// Check if a key exists in secure storage
    public func exists(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Error Messages

    static func keychainErrorMessage(_ status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            return "Success"
        case errSecItemNotFound:
            return "Item not found"
        case errSecDuplicateItem:
            return "Duplicate item"
        case errSecAuthFailed:
            return "Authentication failed"
        case errSecInteractionNotAllowed:
            return "Interaction not allowed (device locked)"
        case errSecDecode:
            return "Decode error"
        case errSecParam:
            return "Invalid parameter"
        default:
            return "Unknown error (\(status))"
        }
    }
}

// MARK: - Secure Storage Keys

/// Common keys for secure storage
public enum SecureStorageKeys {
    public static let deviceId = "device_id"
    public static let hmacKey = "hmac_signing_key"
    public static let authToken = "auth_token"
    public static let mqttUsername = "mqtt_username"
    public static let mqttPassword = "mqtt_password"
    public static let certificateData = "certificate_data"
    public static let privateKeyData = "private_key_data"
}

// MARK: - Convenience Extensions

extension SecureStorage {

    /// Get or generate a device ID
    public func getOrCreateDeviceId() -> String {
        if let existingId = getStringOrNil(forKey: SecureStorageKeys.deviceId) {
            return existingId
        }

        let newId = UUID().uuidString
        try? setString(newId, forKey: SecureStorageKeys.deviceId)
        return newId
    }

    /// Store MQTT credentials
    public func setMqttCredentials(username: String, password: String) throws {
        try setString(username, forKey: SecureStorageKeys.mqttUsername)
        try setString(password, forKey: SecureStorageKeys.mqttPassword)
    }

    /// Get MQTT credentials
    public func getMqttCredentials() -> (username: String, password: String)? {
        guard let username = getStringOrNil(forKey: SecureStorageKeys.mqttUsername),
              let password = getStringOrNil(forKey: SecureStorageKeys.mqttPassword) else {
            return nil
        }
        return (username, password)
    }

    /// Clear MQTT credentials
    public func clearMqttCredentials() {
        try? delete(forKey: SecureStorageKeys.mqttUsername)
        try? delete(forKey: SecureStorageKeys.mqttPassword)
    }
}
