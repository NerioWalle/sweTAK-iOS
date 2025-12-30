import Foundation
import Combine
import SwiftUI
import os.log

/// Coordinate format options
public enum CoordinateFormat: String, Codable, CaseIterable {
    case mgrs = "MGRS"
    case decimal = "Decimal"
    case dms = "DMS"
    case utm = "UTM"

    public var displayName: String { rawValue }
}

/// Unit system options for Settings UI
/// Note: AdvancedSettingsModels.UnitSystem is used for map calculations
public enum SettingsUnitSystem: String, Codable, CaseIterable {
    case metric = "Metric"
    case imperial = "Imperial"

    public var displayName: String { rawValue }
}

/// Map style options for Settings UI
/// Note: AdvancedSettingsModels.MapStyle has additional styles
public enum SettingsMapStyle: String, Codable, CaseIterable {
    case satellite = "Satellite"
    case terrain = "Terrain"
    case streets = "Streets"
    case dark = "Dark"

    public var displayName: String { rawValue }
}

/// GPS interval settings
public struct GPSInterval: Codable, Equatable {
    public var value: Int
    public var unit: String  // "s" for seconds, "m" for minutes

    public init(value: Int = 5, unit: String = "s") {
        self.value = value
        self.unit = unit
    }

    public var totalSeconds: Int {
        switch unit {
        case "m": return value * 60
        default: return value
        }
    }

    public var displayString: String {
        "\(value)\(unit)"
    }
}

/// Settings state model
public struct SettingsState: Codable, Equatable {
    public var isDarkMode: Bool = false
    public var unitSystem: SettingsUnitSystem = .metric
    public var coordFormat: CoordinateFormat = .mgrs
    public var gpsInterval: GPSInterval = GPSInterval()
    public var mapStyle: SettingsMapStyle = .satellite
    public var breadcrumbColorHex: String = "FF9800"  // Orange
    public var mapOrientation: MapOrientationMode = .freeRotate
    public var messageSigningEnabled: Bool = false

    public init() {}
}

/// MQTT settings model
public struct MQTTSettings: Codable, Equatable {
    public var host: String = ""
    public var port: Int = 8883
    public var username: String = ""
    public var password: String = ""
    public var useTls: Bool = true
    public var maxMessageAgeMinutes: Int = 360

    public init() {}

    public var isValid: Bool {
        !host.isEmpty && port > 0
    }
}

/// ViewModel for managing app settings
/// Mirrors Android SettingsViewModel functionality
public final class SettingsViewModel: ObservableObject {

    // MARK: - Singleton

    public static let shared = SettingsViewModel()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "SettingsViewModel")

    // MARK: - Published State

    @Published public private(set) var settings = SettingsState()
    @Published public private(set) var transportMode: TransportMode = .localUDP
    @Published public private(set) var mqttSettings = MQTTSettings()
    @Published public private(set) var profile = LocalProfile()

    // MARK: - Device ID

    public var deviceId: String {
        if let stored = UserDefaults.standard.string(forKey: Keys.deviceId), !stored.isEmpty {
            return stored
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: Keys.deviceId)
        return newId
    }

    /// Shorthand for callsign from profile
    public var callsign: String {
        profile.callsign.isEmpty ? "Unknown" : profile.callsign
    }

    // MARK: - Storage Keys

    private enum Keys {
        static let settings = "swetak_settings"
        static let transportMode = "swetak_transport_mode"
        static let mqttSettings = "swetak_mqtt_settings"
        static let profile = "swetak_profile"
        static let deviceId = "swetak_device_id"
    }

    // MARK: - Initialization

    private init() {
        loadFromStorage()
    }

    // MARK: - Storage

    private func loadFromStorage() {
        // Load settings
        if let data = UserDefaults.standard.data(forKey: Keys.settings),
           let stored = try? JSONDecoder().decode(SettingsState.self, from: data) {
            settings = stored
        }

        // Load transport mode
        if let modeString = UserDefaults.standard.string(forKey: Keys.transportMode),
           let mode = TransportMode(rawValue: modeString) {
            transportMode = mode
        }

        // Load MQTT settings
        if let data = UserDefaults.standard.data(forKey: Keys.mqttSettings),
           let stored = try? JSONDecoder().decode(MQTTSettings.self, from: data) {
            mqttSettings = stored
        }

        // Load profile
        if let data = UserDefaults.standard.data(forKey: Keys.profile),
           let stored = try? JSONDecoder().decode(LocalProfile.self, from: data) {
            profile = stored
        }

        logger.info("Loaded settings: transport=\(self.transportMode.rawValue), callsign=\(self.profile.callsign)")
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Keys.settings)
        }
    }

    private func saveTransportMode() {
        UserDefaults.standard.set(transportMode.rawValue, forKey: Keys.transportMode)
    }

    private func saveMQTTSettings() {
        if let data = try? JSONEncoder().encode(mqttSettings) {
            UserDefaults.standard.set(data, forKey: Keys.mqttSettings)
        }
    }

    private func saveProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Keys.profile)
        }
    }

    // MARK: - Profile Management

    /// Update the user's profile
    public func updateProfile(_ newProfile: LocalProfile) {
        profile = newProfile
        saveProfile()

        // Publish profile update over network
        TransportCoordinator.shared.publishProfile(profile)

        logger.info("Profile updated: callsign=\(newProfile.callsign)")
    }

    /// Update individual profile fields
    public func updateCallsign(_ callsign: String) {
        profile.callsign = callsign
        saveProfile()
    }

    public func updateNickname(_ nickname: String) {
        profile.nickname = nickname
        saveProfile()
    }

    // MARK: - Display Settings

    /// Set dark mode
    public func setDarkMode(_ isDark: Bool) {
        settings.isDarkMode = isDark
        saveSettings()
    }

    /// Set unit system
    public func setUnitSystem(_ unit: SettingsUnitSystem) {
        settings.unitSystem = unit
        saveSettings()
    }

    /// Set coordinate format
    public func setCoordFormat(_ format: CoordinateFormat) {
        settings.coordFormat = format
        saveSettings()
    }

    /// Set GPS interval
    public func setGpsInterval(value: Int, unit: String) {
        settings.gpsInterval = GPSInterval(value: value, unit: unit)
        saveSettings()
    }

    /// Set map style
    public func setMapStyle(_ style: SettingsMapStyle) {
        settings.mapStyle = style
        saveSettings()
        logger.debug("Map style set to: \(style.rawValue)")
    }

    /// Set breadcrumb color
    public func setBreadcrumbColor(_ color: Color) {
        // Convert Color to hex string
        if let components = color.cgColor?.components, components.count >= 3 {
            let r = Int(components[0] * 255)
            let g = Int(components[1] * 255)
            let b = Int(components[2] * 255)
            settings.breadcrumbColorHex = String(format: "%02X%02X%02X", r, g, b)
            saveSettings()
        }
    }

    /// Get breadcrumb color
    public var breadcrumbColor: Color {
        Color(hex: UInt64(settings.breadcrumbColorHex, radix: 16) ?? 0xFF9800)
    }

    /// Set map orientation
    public func setMapOrientation(_ mode: MapOrientationMode) {
        settings.mapOrientation = mode
        saveSettings()
        MapViewModel.shared.setMapOrientation(mode)
    }

    /// Set message signing
    public func setMessageSigningEnabled(_ enabled: Bool) {
        settings.messageSigningEnabled = enabled
        saveSettings()
    }

    // MARK: - Transport Settings

    /// Set transport mode
    public func setTransportMode(_ mode: TransportMode) {
        transportMode = mode
        saveTransportMode()

        // Apply to TransportCoordinator
        TransportCoordinator.shared.setMode(mode)

        logger.info("Transport mode changed to: \(mode.rawValue)")
    }

    /// Update MQTT settings
    public func updateMqttSettings(_ newSettings: MQTTSettings) {
        mqttSettings = newSettings
        saveMQTTSettings()

        // Apply to TransportCoordinator if MQTT is active
        if transportMode == .mqtt && mqttSettings.isValid {
            let config = MQTTConfiguration(
                host: mqttSettings.host,
                port: mqttSettings.port,
                useTLS: mqttSettings.useTls,
                username: mqttSettings.username.isEmpty ? nil : mqttSettings.username,
                password: mqttSettings.password.isEmpty ? nil : mqttSettings.password
            )
            TransportCoordinator.shared.mqttConfiguration = config
        }

        logger.info("MQTT settings updated: host=\(newSettings.host)")
    }

    /// Connect to MQTT with current settings
    public func connectMQTT() {
        guard mqttSettings.isValid else {
            logger.warning("Cannot connect MQTT: invalid settings")
            return
        }

        let config = MQTTConfiguration(
            host: mqttSettings.host,
            port: mqttSettings.port,
            useTLS: mqttSettings.useTls,
            username: mqttSettings.username.isEmpty ? nil : mqttSettings.username,
            password: mqttSettings.password.isEmpty ? nil : mqttSettings.password
        )

        TransportCoordinator.shared.mqttConfiguration = config
        setTransportMode(.mqtt)
    }

    /// Disconnect MQTT and switch to UDP
    public func disconnectMQTT() {
        setTransportMode(.localUDP)
    }

    // MARK: - Computed Properties

    /// GPS interval in seconds
    public var gpsIntervalSeconds: Int {
        settings.gpsInterval.totalSeconds
    }

    /// Check if currently connected
    public var isConnected: Bool {
        TransportCoordinator.shared.connectionState == .connected
    }

    /// Current connection state description
    public var connectionStateDescription: String {
        switch TransportCoordinator.shared.connectionState {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}
