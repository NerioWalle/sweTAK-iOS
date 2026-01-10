import Foundation

// MARK: - Coordinate Mode

public enum CoordMode: String, Codable, CaseIterable {
    case mgrs = "MGRS"
    case latLon = "LATLON"

    public var displayName: String {
        switch self {
        case .mgrs: return "MGRS"
        case .latLon: return "Lat/Lon"
        }
    }
}

// MARK: - Position Update Interval

public enum PositionUnit: String, Codable, CaseIterable {
    case sec = "SEC"
    case min = "MIN"
    case hour = "H"

    public var displayName: String {
        switch self {
        case .sec: return "Seconds"
        case .min: return "Minutes"
        case .hour: return "Hours"
        }
    }

    /// Convert value to milliseconds
    public func toMillis(_ value: Int) -> Int64 {
        switch self {
        case .sec: return Int64(value) * 1_000
        case .min: return Int64(value) * 60_000
        case .hour: return Int64(value) * 3_600_000
        }
    }
}

// Note: UnitSystem, ThemeMode, NightVisionColor, LayersMenuLevel, MessagingMenuLevel
// are defined in AdvancedSettingsModels.swift

// MARK: - Breadcrumb and Route models are defined in LocationManager.swift
