import Foundation
import Combine
import os.log

// MARK: - Settings Key Protocol

/// Protocol for type-safe settings keys
public protocol SettingsKey {
    associatedtype Value: Codable

    /// Storage key
    var key: String { get }

    /// Default value
    var defaultValue: Value { get }
}

// MARK: - Settings Keys

/// Type-safe keys for all app settings
/// Mirrors Android SettingsDataStore preference keys
public enum SettingsKeys {

    // MARK: - Profile Keys

    public struct Callsign: SettingsKey {
        public typealias Value = String
        public let key = "swetak.profile.callsign"
        public let defaultValue = ""
    }

    public struct CallsignHint: SettingsKey {
        public typealias Value = String
        public let key = "swetak.profile.callsign_hint"
        public let defaultValue = ""
    }

    public struct Nickname: SettingsKey {
        public typealias Value = String
        public let key = "swetak.profile.nickname"
        public let defaultValue = ""
    }

    public struct DeviceId: SettingsKey {
        public typealias Value = String
        public let key = "swetak.device_id"
        public let defaultValue = ""
    }

    // MARK: - Display Keys

    public struct DarkMode: SettingsKey {
        public typealias Value = Bool
        public let key = "swetak.display.dark_mode"
        public let defaultValue = false
    }

    public struct CoordinateFormat: SettingsKey {
        public typealias Value = String
        public let key = "swetak.display.coord_format"
        public let defaultValue = "MGRS"
    }

    public struct UnitSystem: SettingsKey {
        public typealias Value = String
        public let key = "swetak.display.unit_system"
        public let defaultValue = "Metric"
    }

    public struct MapStyleKey: SettingsKey {
        public typealias Value = String
        public let key = "swetak.display.map_style"
        public let defaultValue = "Satellite"
    }

    public struct BreadcrumbColor: SettingsKey {
        public typealias Value = String
        public let key = "swetak.display.breadcrumb_color"
        public let defaultValue = "FF9800"
    }

    public struct MapOrientation: SettingsKey {
        public typealias Value = String
        public let key = "swetak.display.map_orientation"
        public let defaultValue = "freeRotate"
    }

    // MARK: - GPS Keys

    public struct GpsIntervalValue: SettingsKey {
        public typealias Value = Int
        public let key = "swetak.gps.interval_value"
        public let defaultValue = 5
    }

    public struct GpsIntervalUnit: SettingsKey {
        public typealias Value = String
        public let key = "swetak.gps.interval_unit"
        public let defaultValue = "s"
    }

    public struct GpsEnabled: SettingsKey {
        public typealias Value = Bool
        public let key = "swetak.gps.enabled"
        public let defaultValue = true
    }

    // MARK: - Network Keys

    public struct TransportModeKey: SettingsKey {
        public typealias Value = String
        public let key = "swetak.network.transport_mode"
        public let defaultValue = "localUDP"
    }

    public struct MqttHost: SettingsKey {
        public typealias Value = String
        public let key = "swetak.mqtt.host"
        public let defaultValue = ""
    }

    public struct MqttPort: SettingsKey {
        public typealias Value = Int
        public let key = "swetak.mqtt.port"
        public let defaultValue = 8883
    }

    public struct MqttUsername: SettingsKey {
        public typealias Value = String
        public let key = "swetak.mqtt.username"
        public let defaultValue = ""
    }

    public struct MqttPassword: SettingsKey {
        public typealias Value = String
        public let key = "swetak.mqtt.password"
        public let defaultValue = ""
    }

    public struct MqttUseTls: SettingsKey {
        public typealias Value = Bool
        public let key = "swetak.mqtt.use_tls"
        public let defaultValue = true
    }

    public struct MqttClientId: SettingsKey {
        public typealias Value = String
        public let key = "swetak.mqtt.client_id"
        public let defaultValue = ""
    }

    public struct MqttMaxMessageAgeMinutes: SettingsKey {
        public typealias Value = Int
        public let key = "swetak.mqtt.max_message_age_minutes"
        public let defaultValue = 360
    }

    // MARK: - UDP Keys

    public struct UdpPort: SettingsKey {
        public typealias Value = Int
        public let key = "swetak.udp.port"
        public let defaultValue = 4242
    }

    public struct UdpBroadcastEnabled: SettingsKey {
        public typealias Value = Bool
        public let key = "swetak.udp.broadcast_enabled"
        public let defaultValue = true
    }

    // MARK: - Security Keys

    public struct MessageSigningEnabled: SettingsKey {
        public typealias Value = Bool
        public let key = "swetak.security.message_signing"
        public let defaultValue = false
    }

    public struct CertificateVerificationEnabled: SettingsKey {
        public typealias Value = Bool
        public let key = "swetak.security.cert_verification"
        public let defaultValue = true
    }

    // MARK: - Feature Flags

    public struct ChatEnabled: SettingsKey {
        public typealias Value = Bool
        public let key = "swetak.features.chat_enabled"
        public let defaultValue = true
    }

    public struct OrdersEnabled: SettingsKey {
        public typealias Value = Bool
        public let key = "swetak.features.orders_enabled"
        public let defaultValue = true
    }

    public struct ReportsEnabled: SettingsKey {
        public typealias Value = Bool
        public let key = "swetak.features.reports_enabled"
        public let defaultValue = true
    }

    public struct PhotoPinsEnabled: SettingsKey {
        public typealias Value = Bool
        public let key = "swetak.features.photo_pins_enabled"
        public let defaultValue = true
    }

    // MARK: - Cache Keys

    public struct LastSyncTimestamp: SettingsKey {
        public typealias Value = Int64
        public let key = "swetak.cache.last_sync"
        public let defaultValue: Int64 = 0
    }

    public struct SettingsVersion: SettingsKey {
        public typealias Value = Int
        public let key = "swetak.settings_version"
        public let defaultValue = 1
    }
}

// MARK: - Settings Data Store

/// Type-safe settings data store using UserDefaults
/// Provides Combine publishers for reactive settings access
public final class SettingsDataStore: ObservableObject {

    // MARK: - Singleton

    public static let shared = SettingsDataStore()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "SettingsStore")

    // MARK: - Storage

    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Change Publishers

    private let changeSubject = PassthroughSubject<String, Never>()

    /// Publisher that emits key names when settings change
    public var changes: AnyPublisher<String, Never> {
        changeSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateIfNeeded()
    }

    // MARK: - Generic Access

    /// Get a setting value
    public func get<K: SettingsKey>(_ key: K) -> K.Value {
        guard let data = defaults.data(forKey: key.key) else {
            return key.defaultValue
        }

        do {
            return try JSONDecoder().decode(K.Value.self, from: data)
        } catch {
            logger.warning("Failed to decode \(key.key): \(error.localizedDescription)")
            return key.defaultValue
        }
    }

    /// Set a setting value
    public func set<K: SettingsKey>(_ key: K, value: K.Value) {
        do {
            let data = try JSONEncoder().encode(value)
            defaults.set(data, forKey: key.key)
            changeSubject.send(key.key)
            logger.debug("Set \(key.key)")
        } catch {
            logger.error("Failed to encode \(key.key): \(error.localizedDescription)")
        }
    }

    /// Observe a setting value
    public func observe<K: SettingsKey>(_ key: K) -> AnyPublisher<K.Value, Never> {
        changeSubject
            .filter { $0 == key.key }
            .map { [weak self] _ in self?.get(key) ?? key.defaultValue }
            .prepend(get(key))
            .eraseToAnyPublisher()
    }

    /// Remove a setting
    public func remove<K: SettingsKey>(_ key: K) {
        defaults.removeObject(forKey: key.key)
        changeSubject.send(key.key)
    }

    /// Check if a setting exists
    public func exists<K: SettingsKey>(_ key: K) -> Bool {
        defaults.object(forKey: key.key) != nil
    }

    // MARK: - Primitive Access (for simple types)

    /// Get string setting
    public func getString(_ key: String, default defaultValue: String = "") -> String {
        defaults.string(forKey: key) ?? defaultValue
    }

    /// Set string setting
    public func setString(_ key: String, value: String) {
        defaults.set(value, forKey: key)
        changeSubject.send(key)
    }

    /// Get int setting
    public func getInt(_ key: String, default defaultValue: Int = 0) -> Int {
        defaults.object(forKey: key) != nil ? defaults.integer(forKey: key) : defaultValue
    }

    /// Set int setting
    public func setInt(_ key: String, value: Int) {
        defaults.set(value, forKey: key)
        changeSubject.send(key)
    }

    /// Get bool setting
    public func getBool(_ key: String, default defaultValue: Bool = false) -> Bool {
        defaults.object(forKey: key) != nil ? defaults.bool(forKey: key) : defaultValue
    }

    /// Set bool setting
    public func setBool(_ key: String, value: Bool) {
        defaults.set(value, forKey: key)
        changeSubject.send(key)
    }

    // MARK: - Migration

    private static let currentVersion = 1

    private func migrateIfNeeded() {
        let versionKey = SettingsKeys.SettingsVersion()
        let currentStoredVersion = get(versionKey)

        if currentStoredVersion < Self.currentVersion {
            performMigration(from: currentStoredVersion, to: Self.currentVersion)
            set(versionKey, value: Self.currentVersion)
        }
    }

    private func performMigration(from oldVersion: Int, to newVersion: Int) {
        logger.info("Migrating settings from v\(oldVersion) to v\(newVersion)")

        // Add migration logic here as versions increase
        // Example:
        // if oldVersion < 2 {
        //     // Migrate v1 -> v2
        // }
    }

    // MARK: - Bulk Operations

    /// Export all settings as dictionary
    public func exportAll() -> [String: Any] {
        var result: [String: Any] = [:]

        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix("swetak.") {
                result[key] = defaults.object(forKey: key)
            }
        }

        return result
    }

    /// Import settings from dictionary
    public func importAll(_ settings: [String: Any]) {
        for (key, value) in settings {
            if key.hasPrefix("swetak.") {
                defaults.set(value, forKey: key)
                changeSubject.send(key)
            }
        }
        logger.info("Imported \(settings.count) settings")
    }

    /// Reset all settings to defaults
    public func resetAll() {
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix("swetak.") {
                defaults.removeObject(forKey: key)
            }
        }
        logger.info("All settings reset to defaults")
    }
}

// MARK: - Convenience Extensions

extension SettingsDataStore {

    // MARK: - Profile Shortcuts

    public var callsign: String {
        get { get(SettingsKeys.Callsign()) }
        set { set(SettingsKeys.Callsign(), value: newValue) }
    }

    public var nickname: String {
        get { get(SettingsKeys.Nickname()) }
        set { set(SettingsKeys.Nickname(), value: newValue) }
    }

    public var deviceId: String {
        get {
            let key = SettingsKeys.DeviceId()
            var id = get(key)
            if id.isEmpty {
                id = UUID().uuidString
                set(key, value: id)
            }
            return id
        }
    }

    // MARK: - Display Shortcuts

    public var isDarkMode: Bool {
        get { get(SettingsKeys.DarkMode()) }
        set { set(SettingsKeys.DarkMode(), value: newValue) }
    }

    public var coordinateFormat: CoordinateFormat {
        get {
            CoordinateFormat(rawValue: get(SettingsKeys.CoordinateFormat())) ?? .mgrs
        }
        set {
            set(SettingsKeys.CoordinateFormat(), value: newValue.rawValue)
        }
    }

    public var unitSystem: UnitSystem {
        get {
            UnitSystem(rawValue: get(SettingsKeys.UnitSystem())) ?? .metric
        }
        set {
            set(SettingsKeys.UnitSystem(), value: newValue.rawValue)
        }
    }

    public var mapStyle: MapStyle {
        get {
            MapStyle(rawValue: get(SettingsKeys.MapStyleKey())) ?? .satellite
        }
        set {
            set(SettingsKeys.MapStyleKey(), value: newValue.rawValue)
        }
    }

    // MARK: - Network Shortcuts

    public var transportMode: TransportMode {
        get {
            TransportMode(rawValue: get(SettingsKeys.TransportModeKey())) ?? .localUDP
        }
        set {
            set(SettingsKeys.TransportModeKey(), value: newValue.rawValue)
        }
    }

    public var mqttHost: String {
        get { get(SettingsKeys.MqttHost()) }
        set { set(SettingsKeys.MqttHost(), value: newValue) }
    }

    public var mqttPort: Int {
        get { get(SettingsKeys.MqttPort()) }
        set { set(SettingsKeys.MqttPort(), value: newValue) }
    }

    public var mqttUseTls: Bool {
        get { get(SettingsKeys.MqttUseTls()) }
        set { set(SettingsKeys.MqttUseTls(), value: newValue) }
    }

    // MARK: - Feature Shortcuts

    public var isChatEnabled: Bool {
        get { get(SettingsKeys.ChatEnabled()) }
        set { set(SettingsKeys.ChatEnabled(), value: newValue) }
    }

    public var isMessageSigningEnabled: Bool {
        get { get(SettingsKeys.MessageSigningEnabled()) }
        set { set(SettingsKeys.MessageSigningEnabled(), value: newValue) }
    }
}
