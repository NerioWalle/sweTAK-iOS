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

/// Appearance mode options
public enum AppearanceMode: String, Codable, CaseIterable {
    case system = "System"
    case dark = "Dark"
    case light = "Light"

    public var displayName: String {
        switch self {
        case .system: return "System setting"
        case .dark: return "Dark mode"
        case .light: return "Light mode"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
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
    public var appearanceMode: AppearanceMode = .system
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

/// MapTiler Cloud settings
public struct MapTilerSettings: Codable, Equatable {
    public var apiKey: String = ""

    public init() {}

    public var isValid: Bool {
        !apiKey.isEmpty
    }

    /// Get tile URL for a given style
    public func tileURL(for style: MapTilerStyle) -> String? {
        guard isValid else { return nil }
        return "https://api.maptiler.com/maps/\(style.rawValue)/{z}/{x}/{y}.png?key=\(apiKey)"
    }
}

/// MapTiler map styles
public enum MapTilerStyle: String {
    case streets = "streets-v2"
    case satellite = "satellite"
    case hybrid = "hybrid"
    case terrain = "terrain"
    case outdoor = "outdoor-v2"
    case topographic = "topo-v2"
}

/// Map provider options
public enum MapProvider: String, Codable, CaseIterable {
    case appleMaps = "apple"
    case mapTiler = "maptiler"

    public var displayName: String {
        switch self {
        case .appleMaps: return "Apple Maps"
        case .mapTiler: return "MapTiler"
        }
    }

    public var icon: String {
        switch self {
        case .appleMaps: return "apple.logo"
        case .mapTiler: return "map"
        }
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
    @Published public private(set) var mapTilerSettings = MapTilerSettings()
    @Published public private(set) var mapProvider: MapProvider = .appleMaps
    @Published public private(set) var profile = LocalProfile()

    // MARK: - Lighting State

    @Published public var themeMode: ThemeMode = .dark
    @Published public var nightVisionColor: NightVisionColor = .red
    @Published public var nightDimmerAlpha: Float = 0.5

    // MARK: - Connection State (Observable)

    @Published public private(set) var connectionState: ConnectionState = .disconnected
    private var cancellables = Set<AnyCancellable>()

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
        static let mapTilerSettings = "swetak_maptiler_settings"
        static let mapProvider = "swetak_map_provider"
        static let profile = "swetak_profile"
        static let deviceId = "swetak_device_id"
    }

    // MARK: - Initialization

    private init() {
        loadFromStorage()
        setupConnectionStateObserver()

        // Sync profile to ContactsViewModel after a short delay to ensure it's initialized
        DispatchQueue.main.async { [weak self] in
            self?.syncProfileToContacts()
        }
    }

    private func setupConnectionStateObserver() {
        TransportCoordinator.shared.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
                self?.logger.debug("Connection state changed: \(String(describing: state))")
            }
            .store(in: &cancellables)
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

        // Load MapTiler settings
        if let data = UserDefaults.standard.data(forKey: Keys.mapTilerSettings),
           let stored = try? JSONDecoder().decode(MapTilerSettings.self, from: data) {
            mapTilerSettings = stored
        }

        // Load map provider
        if let storedProvider = UserDefaults.standard.string(forKey: Keys.mapProvider),
           let provider = MapProvider(rawValue: storedProvider) {
            mapProvider = provider
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

    private func saveMapTilerSettings() {
        if let data = try? JSONEncoder().encode(mapTilerSettings) {
            UserDefaults.standard.set(data, forKey: Keys.mapTilerSettings)
        }
    }

    private func saveMapProvider() {
        UserDefaults.standard.set(mapProvider.rawValue, forKey: Keys.mapProvider)
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

        // Sync to ContactsViewModel
        syncProfileToContacts()

        // Publish profile update over network
        TransportCoordinator.shared.publishProfile(profile)

        logger.info("Profile updated: callsign=\(newProfile.callsign)")
    }

    /// Update individual profile fields
    public func updateCallsign(_ callsign: String) {
        profile.callsign = callsign
        saveProfile()
        syncProfileToContacts()
    }

    public func updateNickname(_ nickname: String) {
        profile.nickname = nickname
        saveProfile()
        syncProfileToContacts()
    }

    /// Sync local profile to ContactsViewModel for network operations
    private func syncProfileToContacts() {
        let contactProfile = ContactProfile(
            deviceId: deviceId,
            nickname: profile.nickname.isEmpty ? nil : profile.nickname,
            callsign: profile.callsign.isEmpty ? nil : profile.callsign,
            firstName: profile.firstName.isEmpty ? nil : profile.firstName,
            lastName: profile.lastName.isEmpty ? nil : profile.lastName,
            company: profile.company.isEmpty ? nil : profile.company,
            platoon: profile.platoon.isEmpty ? nil : profile.platoon,
            squad: profile.squad.isEmpty ? nil : profile.squad,
            mobile: profile.phone.isEmpty ? nil : profile.phone,
            email: profile.email.isEmpty ? nil : profile.email,
            role: profile.role
        )
        ContactsViewModel.shared.setMyProfile(contactProfile)
    }

    // MARK: - Display Settings

    /// Set appearance mode
    public func setAppearanceMode(_ mode: AppearanceMode) {
        settings.appearanceMode = mode
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

    /// Set map style (legacy)
    public func setMapStyle(_ style: SettingsMapStyle) {
        settings.mapStyle = style
        saveSettings()
        logger.debug("Map style set to: \(style.rawValue)")
    }

    // MARK: - Full Map Style Support

    /// Current full map style
    @Published public var currentMapStyle: MapStyle = .standard

    /// Set full map style (all 6 options)
    public func setFullMapStyle(_ style: MapStyle) {
        currentMapStyle = style
        // Also update the legacy setting for compatibility
        switch style {
        case .satellite, .hybrid:
            settings.mapStyle = .satellite
        case .terrain, .outdoor, .topographic:
            settings.mapStyle = .terrain
        case .standard:
            settings.mapStyle = .streets
        }
        saveSettings()
        logger.debug("Full map style set to: \(style.rawValue)")
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
        logger.info("setTransportMode() called with mode: \(mode.rawValue)")
        transportMode = mode
        saveTransportMode()

        // Apply to TransportCoordinator
        logger.info("Calling TransportCoordinator.setMode(\(mode.rawValue))")
        TransportCoordinator.shared.setMode(mode)

        logger.info("Transport mode changed to: \(mode.rawValue), coordinator activeMode: \(TransportCoordinator.shared.activeMode.rawValue)")
    }

    /// Update MQTT settings
    public func updateMqttSettings(_ newSettings: MQTTSettings) {
        mqttSettings = newSettings
        saveMQTTSettings()

        // If MQTT is active and settings changed, reconnect with new settings
        if transportMode == .mqtt && mqttSettings.isValid {
            logger.info("MQTT settings changed while connected - reconnecting...")
            let config = MQTTConfiguration(
                host: mqttSettings.host,
                port: mqttSettings.port,
                useTLS: mqttSettings.useTls,
                username: mqttSettings.username.isEmpty ? nil : mqttSettings.username,
                password: mqttSettings.password.isEmpty ? nil : mqttSettings.password
            )
            TransportCoordinator.shared.mqttConfiguration = config
            // Force reconnection by switching modes
            TransportCoordinator.shared.setMode(.localUDP)
            TransportCoordinator.shared.setMode(.mqtt)
        }

        logger.info("MQTT settings updated: host=\(newSettings.host)")
    }

    /// Update MapTiler settings
    public func updateMapTilerSettings(_ newSettings: MapTilerSettings) {
        mapTilerSettings = newSettings
        saveMapTilerSettings()
        logger.info("MapTiler settings updated: apiKey=\(newSettings.apiKey.isEmpty ? "(empty)" : "(set)")")
    }

    /// Update MapTiler API key
    public func setMapTilerApiKey(_ apiKey: String) {
        mapTilerSettings.apiKey = apiKey
        saveMapTilerSettings()
        logger.info("MapTiler API key updated")
    }

    /// Set map provider
    public func setMapProvider(_ provider: MapProvider) {
        mapProvider = provider
        saveMapProvider()
        logger.info("Map provider set to: \(provider.displayName)")
    }

    /// Get the MapTiler style URL for a given map style
    public func mapTilerURL(for style: MapStyle) -> String? {
        guard mapTilerSettings.isValid else { return nil }

        let tilerStyle: MapTilerStyle
        switch style {
        case .standard:
            tilerStyle = .streets
        case .satellite:
            tilerStyle = .satellite
        case .hybrid:
            tilerStyle = .hybrid
        case .terrain:
            tilerStyle = .terrain
        case .outdoor:
            tilerStyle = .outdoor
        case .topographic:
            tilerStyle = .topographic
        }

        return mapTilerSettings.tileURL(for: tilerStyle)
    }

    /// Connect to MQTT with current settings
    public func connectMQTT() {
        logger.info("connectMQTT() called - host: \(self.mqttSettings.host), port: \(self.mqttSettings.port), useTLS: \(self.mqttSettings.useTls)")

        guard mqttSettings.isValid else {
            logger.warning("Cannot connect MQTT: invalid settings (host empty or port invalid)")
            return
        }

        let config = MQTTConfiguration(
            host: mqttSettings.host,
            port: mqttSettings.port,
            useTLS: mqttSettings.useTls,
            username: mqttSettings.username.isEmpty ? nil : mqttSettings.username,
            password: mqttSettings.password.isEmpty ? nil : mqttSettings.password
        )

        logger.info("Setting MQTT configuration and switching to MQTT mode")
        TransportCoordinator.shared.mqttConfiguration = config
        setTransportMode(.mqtt)
        logger.info("connectMQTT() completed - transport mode is now: \(self.transportMode.rawValue)")
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
        connectionState == .connected
    }

    /// Current connection state description
    public var connectionStateDescription: String {
        switch connectionState {
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
