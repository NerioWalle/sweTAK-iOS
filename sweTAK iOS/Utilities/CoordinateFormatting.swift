import Foundation
import CoreLocation

// MARK: - Coordinate Formatting

public struct CoordinateFormatter {

    // MARK: - MGRS Formatting

    /// Convert latitude/longitude to MGRS string
    /// Note: Full MGRS implementation requires the MGRS library
    /// This is a placeholder that will need the actual library integration
    public static func toMGRS(latitude: Double, longitude: Double, precision: Int = 5) -> String {
        // Placeholder - actual implementation requires MGRS library
        // For now, return a formatted lat/lon as fallback
        return formatDecimal(latitude: latitude, longitude: longitude)
    }

    // MARK: - Decimal Degrees

    /// Format as decimal degrees (e.g., "59.329323, 18.068581")
    public static func formatDecimal(latitude: Double, longitude: Double, decimals: Int = 6) -> String {
        let format = "%.\(decimals)f"
        return String(format: "\(format), \(format)", latitude, longitude)
    }

    // MARK: - Degrees Minutes Seconds

    /// Format as DMS (e.g., "59°19'45.6\"N 18°04'06.9\"E")
    public static func formatDMS(latitude: Double, longitude: Double) -> String {
        let latDMS = decimalToDMS(latitude)
        let lonDMS = decimalToDMS(longitude)

        let latDir = latitude >= 0 ? "N" : "S"
        let lonDir = longitude >= 0 ? "E" : "W"

        return String(format: "%d°%02d'%05.2f\"%@ %d°%02d'%05.2f\"%@",
                      latDMS.degrees, latDMS.minutes, latDMS.seconds, latDir,
                      lonDMS.degrees, lonDMS.minutes, lonDMS.seconds, lonDir)
    }

    /// Convert decimal degrees to degrees, minutes, seconds
    private static func decimalToDMS(_ decimal: Double) -> (degrees: Int, minutes: Int, seconds: Double) {
        let absValue = abs(decimal)
        let degrees = Int(absValue)
        let minutesDecimal = (absValue - Double(degrees)) * 60
        let minutes = Int(minutesDecimal)
        let seconds = (minutesDecimal - Double(minutes)) * 60

        return (degrees, minutes, seconds)
    }

    // MARK: - Format Based on Mode

    /// Format coordinates based on the selected coordinate mode
    public static func format(
        latitude: Double,
        longitude: Double,
        mode: CoordMode
    ) -> String {
        switch mode {
        case .mgrs:
            return toMGRS(latitude: latitude, longitude: longitude)
        case .latLon:
            return formatDecimal(latitude: latitude, longitude: longitude)
        }
    }

    // MARK: - Distance Formatting

    /// Format distance in meters or kilometers
    public static func formatDistance(_ meters: Double, unitSystem: UnitSystem = .metric) -> String {
        switch unitSystem {
        case .metric:
            if meters < 1000 {
                return String(format: "%.0f m", meters)
            } else {
                return String(format: "%.2f km", meters / 1000)
            }
        case .imperial:
            let feet = meters * 3.28084
            if feet < 5280 {
                return String(format: "%.0f ft", feet)
            } else {
                return String(format: "%.2f mi", feet / 5280)
            }
        }
    }

    /// Format speed in appropriate units
    public static func formatSpeed(_ metersPerSecond: Double, unitSystem: UnitSystem = .metric) -> String {
        switch unitSystem {
        case .metric:
            let kmh = metersPerSecond * 3.6
            return String(format: "%.1f km/h", kmh)
        case .imperial:
            let mph = metersPerSecond * 2.23694
            return String(format: "%.1f mph", mph)
        }
    }

    /// Format altitude
    public static func formatAltitude(_ meters: Double, unitSystem: UnitSystem = .metric) -> String {
        switch unitSystem {
        case .metric:
            return String(format: "%.0f m", meters)
        case .imperial:
            let feet = meters * 3.28084
            return String(format: "%.0f ft", feet)
        }
    }
}

// MARK: - CLLocationCoordinate2D Extensions

extension CLLocationCoordinate2D {
    /// Format as decimal degrees
    public func formatDecimal(decimals: Int = 6) -> String {
        CoordinateFormatter.formatDecimal(latitude: latitude, longitude: longitude, decimals: decimals)
    }

    /// Format as DMS
    public func formatDMS() -> String {
        CoordinateFormatter.formatDMS(latitude: latitude, longitude: longitude)
    }

    /// Format as MGRS
    public func formatMGRS() -> String {
        CoordinateFormatter.toMGRS(latitude: latitude, longitude: longitude)
    }

    /// Format based on mode
    public func format(mode: CoordMode) -> String {
        CoordinateFormatter.format(latitude: latitude, longitude: longitude, mode: mode)
    }

    /// Calculate distance to another coordinate
    public func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: latitude, longitude: longitude)
        let to = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return from.distance(from: to)
    }

    /// Calculate bearing to another coordinate
    public func bearing(to other: CLLocationCoordinate2D) -> Double {
        let lat1 = latitude * .pi / 180
        let lon1 = longitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let lon2 = other.longitude * .pi / 180

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        var bearing = atan2(y, x) * 180 / .pi
        if bearing < 0 {
            bearing += 360
        }

        return bearing
    }
}
