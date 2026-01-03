import Foundation
import CoreLocation

// MARK: - Map String Utilities

/// String and formatting utilities for map-related data
/// Mirrors Android MapStringUtils.kt functionality
public enum MapStringUtilities {

    // MARK: - Military DateTime Formatting

    /// Formats a timestamp as military DTG (Date Time Group): DDHHMM'Z'
    /// Example: 251430Z for 25th day, 14:30 UTC
    public static func formatMilitaryDateTime(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ddHHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date) + "Z"
    }

    /// Formats a timestamp in milliseconds as military DTG
    public static func formatMilitaryDateTime(millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(millis) / 1000.0)
        return formatMilitaryDateTime(date)
    }

    /// Formats a full military date time: DD MMM YYYY HHMM'Z'
    /// Example: 25 DEC 2024 1430Z
    public static func formatFullMilitaryDateTime(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy HHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date).uppercased() + "Z"
    }

    // MARK: - Relative Time Formatting

    /// Formats a timestamp as relative time (e.g., "5m ago", "2h ago")
    public static func formatRelativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 0 {
            return "In the future"
        } else if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }

    /// Formats a timestamp in milliseconds as relative time
    public static func formatRelativeTime(millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(millis) / 1000.0)
        return formatRelativeTime(date)
    }

    // MARK: - Route Info Formatting

    /// Formats breadcrumb route info string
    /// Example: "12 pts • 2.5 km • 45m ago"
    public static func formatBreadcrumbInfo(
        pointCount: Int,
        totalDistanceMeters: Double,
        lastUpdateDate: Date?
    ) -> String {
        var parts: [String] = []

        // Point count
        parts.append("\(pointCount) pt\(pointCount == 1 ? "" : "s")")

        // Distance
        if totalDistanceMeters >= 1000 {
            let km = totalDistanceMeters / 1000.0
            parts.append(String(format: "%.1f km", km))
        } else {
            parts.append(String(format: "%.0f m", totalDistanceMeters))
        }

        // Last update
        if let lastUpdate = lastUpdateDate {
            parts.append(formatRelativeTime(lastUpdate))
        }

        return parts.joined(separator: " • ")
    }

    /// Formats planned route info string
    /// Example: "5 waypoints • 10.2 km"
    public static func formatPlannedRouteInfo(
        waypointCount: Int,
        totalDistanceMeters: Double
    ) -> String {
        var parts: [String] = []

        // Waypoint count
        parts.append("\(waypointCount) waypoint\(waypointCount == 1 ? "" : "s")")

        // Distance
        if totalDistanceMeters >= 1000 {
            let km = totalDistanceMeters / 1000.0
            parts.append(String(format: "%.1f km", km))
        } else {
            parts.append(String(format: "%.0f m", totalDistanceMeters))
        }

        return parts.joined(separator: " • ")
    }

    // MARK: - Distance Formatting

    /// Formats distance in meters to human-readable string
    public static func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000.0)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    /// Formats distance with bearing
    public static func formatDistanceWithBearing(_ meters: Double, bearing: Double) -> String {
        let cardinalDirection = bearingToCardinal(bearing)
        return "\(formatDistance(meters)) \(cardinalDirection)"
    }

    /// Converts bearing in degrees to cardinal direction
    public static func bearingToCardinal(_ bearing: Double) -> String {
        let normalized = ((bearing.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)

        switch normalized {
        case 0..<22.5, 337.5..<360:
            return "N"
        case 22.5..<67.5:
            return "NE"
        case 67.5..<112.5:
            return "E"
        case 112.5..<157.5:
            return "SE"
        case 157.5..<202.5:
            return "S"
        case 202.5..<247.5:
            return "SW"
        case 247.5..<292.5:
            return "W"
        case 292.5..<337.5:
            return "NW"
        default:
            return "N"
        }
    }

    // MARK: - String Normalization

    /// Returns nil if the string is a literal "null", "NULL", empty, or whitespace-only
    public static func nullIfLiteral(_ value: String?) -> String? {
        guard let value = value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.lowercased() == "null" {
            return nil
        }
        return trimmed
    }

    /// Returns nil if the string is "Unknown" (case-insensitive)
    public static func nullIfUnknown(_ value: String?) -> String? {
        guard let value = value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.lowercased() == "unknown" {
            return nil
        }
        return trimmed
    }

    /// Cleans a string for profile display - removes null, unknown, and empty values
    public static func cleanForProfile(_ value: String?) -> String? {
        guard let value = value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()
        if trimmed.isEmpty || lower == "null" || lower == "unknown" {
            return nil
        }
        return trimmed
    }

    // MARK: - Identifier Detection

    /// Checks if a string looks like a UUID or hex identifier
    /// These should not be displayed as nicknames/callsigns
    public static func looksLikeIdentifierHex(_ value: String?) -> Bool {
        guard let value = value, !value.isEmpty else { return false }

        // Check for UUID format (8-4-4-4-12 hex digits)
        let uuidPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        if let uuidRegex = try? NSRegularExpression(pattern: uuidPattern),
           uuidRegex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil {
            return true
        }

        // Check for plain hex string (16+ chars, only hex digits and dashes)
        let hexPattern = "^[0-9a-fA-F-]{16,}$"
        if let hexRegex = try? NSRegularExpression(pattern: hexPattern),
           hexRegex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil {
            return true
        }

        return false
    }

    /// Returns a display-friendly nickname, filtering out identifier-like strings
    public static func displayNickname(_ raw: String?) -> String? {
        guard let raw = cleanForProfile(raw) else { return nil }
        if looksLikeIdentifierHex(raw) {
            return nil
        }
        return raw
    }

    // MARK: - Coordinate Formatting

    /// Formats coordinates as lat/lon decimal degrees
    public static func formatLatLon(_ coordinate: CLLocationCoordinate2D, precision: Int = 5) -> String {
        String(format: "%.\(precision)f, %.\(precision)f", coordinate.latitude, coordinate.longitude)
    }

    /// Formats coordinates with hemisphere indicators
    public static func formatLatLonWithHemisphere(_ coordinate: CLLocationCoordinate2D, precision: Int = 5) -> String {
        let latHemi = coordinate.latitude >= 0 ? "N" : "S"
        let lonHemi = coordinate.longitude >= 0 ? "E" : "W"
        return String(format: "%.\(precision)f°%@ %.\(precision)f°%@",
                      abs(coordinate.latitude), latHemi,
                      abs(coordinate.longitude), lonHemi)
    }

    /// Formats coordinates in degrees, minutes, seconds
    public static func formatDMS(_ coordinate: CLLocationCoordinate2D) -> String {
        let latDMS = decimalToDMS(coordinate.latitude, isLatitude: true)
        let lonDMS = decimalToDMS(coordinate.longitude, isLatitude: false)
        return "\(latDMS) \(lonDMS)"
    }

    /// Converts decimal degrees to DMS string
    private static func decimalToDMS(_ decimal: Double, isLatitude: Bool) -> String {
        let absolute = abs(decimal)
        let degrees = Int(absolute)
        let minutesDecimal = (absolute - Double(degrees)) * 60
        let minutes = Int(minutesDecimal)
        let seconds = (minutesDecimal - Double(minutes)) * 60

        let direction: String
        if isLatitude {
            direction = decimal >= 0 ? "N" : "S"
        } else {
            direction = decimal >= 0 ? "E" : "W"
        }

        return String(format: "%d°%02d'%05.2f\"%@", degrees, minutes, seconds, direction)
    }

    // MARK: - Callsign Formatting

    /// Formats a callsign for display, with optional unit info
    public static func formatCallsignDisplay(
        callsign: String?,
        nickname: String? = nil,
        unit: String? = nil
    ) -> String {
        var parts: [String] = []

        if let cs = cleanForProfile(callsign) {
            parts.append(cs)
        }

        if let nick = displayNickname(nickname) {
            if parts.isEmpty {
                parts.append(nick)
            } else {
                parts.append("(\(nick))")
            }
        }

        if let u = cleanForProfile(unit) {
            parts.append("[\(u)]")
        }

        return parts.isEmpty ? "Unknown" : parts.joined(separator: " ")
    }

    // MARK: - Grid Reference

    /// Formats a basic 6-figure grid reference from coordinates
    /// Note: This is a simplified version - real MGRS requires proper zone calculation
    public static func formatBasicGrid(_ coordinate: CLLocationCoordinate2D) -> String {
        // Simple placeholder - real implementation would use proper MGRS library
        let eastings = Int(abs(coordinate.longitude * 10000)) % 1000000
        let northings = Int(abs(coordinate.latitude * 10000)) % 1000000
        return String(format: "%06d %06d", eastings, northings)
    }
}

// MARK: - Haversine Distance Calculation

extension MapStringUtilities {

    /// Calculates distance between two coordinates in meters using Haversine formula
    public static func haversineDistance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let earthRadius: Double = 6371000 // meters

        let lat1Rad = from.latitude * .pi / 180
        let lat2Rad = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLon / 2) * sin(deltaLon / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadius * c
    }

    /// Calculates bearing from one coordinate to another in degrees
    public static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1Rad = from.latitude * .pi / 180
        let lat2Rad = to.latitude * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180

        let y = sin(deltaLon) * cos(lat2Rad)
        let x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(deltaLon)

        let bearingRad = atan2(y, x)
        let bearingDeg = bearingRad * 180 / .pi

        return (bearingDeg + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Calculates total distance of a route (array of coordinates) in meters
    public static func totalRouteDistance(_ coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 2 else { return 0 }

        var total: Double = 0
        for i in 0..<(coordinates.count - 1) {
            total += haversineDistance(from: coordinates[i], to: coordinates[i + 1])
        }
        return total
    }
}
