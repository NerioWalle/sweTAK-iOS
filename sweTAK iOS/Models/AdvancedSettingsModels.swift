import Foundation
import SwiftUI

// MARK: - Theme Mode

/// App theme mode options
public enum ThemeMode: String, CaseIterable, Codable {
    case system = "SYSTEM"
    case light = "LIGHT"
    case dark = "DARK"
    case nightVision = "NIGHT_VISION"

    public var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .nightVision: return "Night Vision"
        }
    }

    public var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .nightVision: return "eye.fill"
        }
    }

    #if canImport(UIKit)
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark, .nightVision: return .dark
        }
    }
    #endif
}

// MARK: - Night Vision Color

/// Night vision overlay color options
public enum NightVisionColor: String, CaseIterable, Codable {
    case red = "RED"
    case green = "GREEN"
    case blue = "BLUE"

    public var displayName: String {
        switch self {
        case .red: return "Red"
        case .green: return "Green"
        case .blue: return "Blue"
        }
    }

    public var color: Color {
        switch self {
        case .red: return Color(red: 0.718, green: 0.110, blue: 0.110) // #B71C1C
        case .green: return Color(red: 0.106, green: 0.369, blue: 0.125) // #1B5E20
        case .blue: return Color(red: 0.051, green: 0.278, blue: 0.631) // #0D47A1
        }
    }

    public var hexValue: UInt {
        switch self {
        case .red: return 0xB71C1C
        case .green: return 0x1B5E20
        case .blue: return 0x0D47A1
        }
    }

    public var overlayOpacity: Double {
        0.7 // Default overlay opacity
    }
}

// MARK: - Map Style

/// Available map style options
public enum MapStyle: String, CaseIterable, Codable {
    case standard = "STANDARD"
    case satellite = "SATELLITE"
    case hybrid = "HYBRID"
    case terrain = "TERRAIN"
    case outdoor = "OUTDOOR"
    case topographic = "TOPOGRAPHIC"

    public var displayName: String {
        switch self {
        case .standard: return "Street"
        case .satellite: return "Satellite"
        case .hybrid: return "Hybrid"
        case .terrain: return "Terrain"
        case .outdoor: return "Outdoor"
        case .topographic: return "Topographic"
        }
    }

    public var icon: String {
        switch self {
        case .standard: return "map"
        case .satellite: return "globe.americas"
        case .hybrid: return "map.fill"
        case .terrain: return "mountain.2"
        case .outdoor: return "figure.hiking"
        case .topographic: return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - Breadcrumb Trail Color

/// Colors available for breadcrumb trails
public enum BreadcrumbColor: String, CaseIterable, Codable {
    case orange = "ORANGE"
    case red = "RED"
    case blue = "BLUE"
    case green = "GREEN"
    case yellow = "YELLOW"
    case white = "WHITE"

    public var displayName: String {
        switch self {
        case .orange: return "Orange"
        case .red: return "Red"
        case .blue: return "Blue"
        case .green: return "Green"
        case .yellow: return "Yellow"
        case .white: return "White"
        }
    }

    public var color: Color {
        switch self {
        case .orange: return .orange
        case .red: return .red
        case .blue: return .blue
        case .green: return .green
        case .yellow: return .yellow
        case .white: return .white
        }
    }
}

// MARK: - Position Broadcast Unit

/// Units for position broadcast interval
public enum PositionBroadcastUnit: String, CaseIterable, Codable {
    case seconds = "SEC"
    case minutes = "MIN"
    case hours = "H"

    public var displayName: String {
        switch self {
        case .seconds: return "Seconds"
        case .minutes: return "Minutes"
        case .hours: return "Hours"
        }
    }

    public var abbreviation: String {
        switch self {
        case .seconds: return "sec"
        case .minutes: return "min"
        case .hours: return "hr"
        }
    }

    /// Convert value to seconds
    public func toSeconds(_ value: Int) -> Int {
        switch self {
        case .seconds: return value
        case .minutes: return value * 60
        case .hours: return value * 3600
        }
    }

    /// Convert seconds to this unit
    public func fromSeconds(_ seconds: Int) -> Int {
        switch self {
        case .seconds: return seconds
        case .minutes: return seconds / 60
        case .hours: return seconds / 3600
        }
    }
}

// MARK: - Unit System

/// Measurement unit system
public enum UnitSystem: String, CaseIterable, Codable {
    case metric = "METRIC"
    case imperial = "IMPERIAL"

    public var displayName: String {
        switch self {
        case .metric: return "Metric"
        case .imperial: return "Imperial"
        }
    }

    public var distanceUnit: String {
        switch self {
        case .metric: return "km"
        case .imperial: return "mi"
        }
    }

    public var speedUnit: String {
        switch self {
        case .metric: return "km/h"
        case .imperial: return "mph"
        }
    }

    public var altitudeUnit: String {
        switch self {
        case .metric: return "m"
        case .imperial: return "ft"
        }
    }

    /// Convert meters to display distance
    public func formatDistance(_ meters: Double) -> String {
        switch self {
        case .metric:
            if meters >= 1000 {
                return String(format: "%.1f km", meters / 1000)
            } else {
                return String(format: "%.0f m", meters)
            }
        case .imperial:
            let feet = meters * 3.28084
            if feet >= 5280 {
                return String(format: "%.1f mi", feet / 5280)
            } else {
                return String(format: "%.0f ft", feet)
            }
        }
    }

    /// Convert meters to display altitude
    public func formatAltitude(_ meters: Double) -> String {
        switch self {
        case .metric:
            return String(format: "%.0f m", meters)
        case .imperial:
            return String(format: "%.0f ft", meters * 3.28084)
        }
    }
}

// MARK: - Layers Menu Level

/// Navigation level for layers dropdown menu
public enum LayersMenuLevel: String, CaseIterable {
    case root = "ROOT"
    case mapStyles = "MAP_STYLES"
    case recordedRoutes = "RECORDED_ROUTES"
    case plannedRoutes = "PLANNED_ROUTES"
}

// MARK: - Messaging Menu Level

/// Navigation level for messaging dropdown menu
public enum MessagingMenuLevel: String, CaseIterable {
    case root = "ROOT"
    case ordersSubmenu = "ORDERS_SUBMENU"
    case reportsSubmenu = "REPORTS_SUBMENU"
    case pedarsSubmenu = "PEDARS_SUBMENU"
    case medevacSubmenu = "MEDEVAC_SUBMENU"
    case requestsSubmenu = "REQUESTS_SUBMENU"
    case methaneSubmenu = "METHANE_SUBMENU"
}

// MARK: - Advanced Settings

/// Comprehensive app settings model
public struct AdvancedSettings: Codable, Equatable {

    // MARK: - Appearance

    /// Current theme mode
    public var themeMode: ThemeMode

    /// Night vision overlay color
    public var nightVisionColor: NightVisionColor

    // MARK: - Map

    /// Default map style on startup
    public var defaultMapStyle: MapStyle

    /// Coordinate display mode
    public var coordMode: CoordMode

    /// Map orientation mode
    public var orientationMode: MapOrientationMode

    /// Unit system for distances
    public var unitSystem: UnitSystem

    // MARK: - Tracking

    /// Breadcrumb trail color
    public var breadcrumbColor: BreadcrumbColor

    /// Show breadcrumb trails on map
    public var showBreadcrumbs: Bool

    /// Show other users on map
    public var showOtherUsers: Bool

    // MARK: - Broadcasting

    /// Position broadcast interval value
    public var positionBroadcastValue: Int

    /// Position broadcast interval unit
    public var positionBroadcastUnit: PositionBroadcastUnit

    // MARK: - MQTT

    /// MQTT broker host
    public var mqttHost: String

    /// MQTT broker port
    public var mqttPort: Int

    /// MQTT client ID (optional)
    public var mqttClientId: String?

    /// MQTT username (optional)
    public var mqttUsername: String?

    /// Enable TLS/SSL for MQTT
    public var mqttUseTLS: Bool

    /// Maximum message age in minutes (0 = no limit)
    public var mqttMaxMessageAgeMinutes: Int

    // MARK: - Security

    /// Enable message signing
    public var messageSigningEnabled: Bool

    /// Reject unsigned messages
    public var rejectUnsignedMessages: Bool

    // MARK: - Defaults

    public init(
        themeMode: ThemeMode = .system,
        nightVisionColor: NightVisionColor = .green,
        defaultMapStyle: MapStyle = .standard,
        coordMode: CoordMode = .latLon,
        orientationMode: MapOrientationMode = .northUp,
        unitSystem: UnitSystem = .metric,
        breadcrumbColor: BreadcrumbColor = .orange,
        showBreadcrumbs: Bool = true,
        showOtherUsers: Bool = true,
        positionBroadcastValue: Int = 30,
        positionBroadcastUnit: PositionBroadcastUnit = .seconds,
        mqttHost: String = "",
        mqttPort: Int = 1883,
        mqttClientId: String? = nil,
        mqttUsername: String? = nil,
        mqttUseTLS: Bool = false,
        mqttMaxMessageAgeMinutes: Int = 5,
        messageSigningEnabled: Bool = true,
        rejectUnsignedMessages: Bool = false
    ) {
        self.themeMode = themeMode
        self.nightVisionColor = nightVisionColor
        self.defaultMapStyle = defaultMapStyle
        self.coordMode = coordMode
        self.orientationMode = orientationMode
        self.unitSystem = unitSystem
        self.breadcrumbColor = breadcrumbColor
        self.showBreadcrumbs = showBreadcrumbs
        self.showOtherUsers = showOtherUsers
        self.positionBroadcastValue = positionBroadcastValue
        self.positionBroadcastUnit = positionBroadcastUnit
        self.mqttHost = mqttHost
        self.mqttPort = mqttPort
        self.mqttClientId = mqttClientId
        self.mqttUsername = mqttUsername
        self.mqttUseTLS = mqttUseTLS
        self.mqttMaxMessageAgeMinutes = mqttMaxMessageAgeMinutes
        self.messageSigningEnabled = messageSigningEnabled
        self.rejectUnsignedMessages = rejectUnsignedMessages
    }

    // MARK: - Computed Properties

    /// Position broadcast interval in seconds
    public var positionBroadcastIntervalSeconds: Int {
        positionBroadcastUnit.toSeconds(positionBroadcastValue)
    }

    /// MQTT port adjusted for TLS
    public var effectiveMqttPort: Int {
        if mqttUseTLS && mqttPort == 1883 {
            return 8883
        } else if !mqttUseTLS && mqttPort == 8883 {
            return 1883
        }
        return mqttPort
    }
}

// Note: IncomingChatNotification, RemoteMarker, and Friend are defined in:
// - ChatMessage.swift (IncomingChatNotification)
// - ContactProfile.swift (RemoteMarker, Friend)
