import Foundation
import CoreLocation

// MARK: - Military Time Formatting

/// Format timestamp as military DDHHMM format
/// Example: 11 Nov 15:24 -> "111524"
public func formatMilitaryDDHHMM(_ date: Date = Date()) -> String {
    let calendar = Calendar.current
    let day = calendar.component(.day, from: date)
    let hour = calendar.component(.hour, from: date)
    let minute = calendar.component(.minute, from: date)
    return String(format: "%02d%02d%02d", day, hour, minute)
}

/// Format timestamp as military DDHHMM from milliseconds
public func formatMilitaryDDHHMM(millis: Int64) -> String {
    let date = Date(timeIntervalSince1970: Double(millis) / 1000.0)
    return formatMilitaryDDHHMM(date)
}

/// Format timestamp as military DTG: DDHHMM'Z' (UTC)
/// Example: "281430Z"
public func formatMilitaryDTG(_ date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "ddHHmm"
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter.string(from: date) + "Z"
}

/// Format timestamp as military DTG from milliseconds
public func formatMilitaryDTG(millis: Int64) -> String {
    let date = Date(timeIntervalSince1970: Double(millis) / 1000.0)
    return formatMilitaryDTG(date)
}

/// Get current date-time as military DDHHMM format
public func currentDdHhMm() -> String {
    return formatMilitaryDDHHMM()
}

// MARK: - Route Time Formatting

/// Format route time as military DDHHMM from millis
public func formatRouteTime(startTimeMillis: Int64) -> String {
    return formatMilitaryDDHHMM(millis: startTimeMillis)
}

/// Format route info for display: "DDHHMM - X.Xkm, Xmin"
public func formatRouteInfo(startTimeMillis: Int64, totalDistanceMeters: Float, durationMillis: Int64) -> String {
    let time = formatMilitaryDDHHMM(millis: startTimeMillis)
    let distKm = String(format: "%.1f", totalDistanceMeters / 1000.0)
    let durationMin = Int(durationMillis / 60000)
    return "\(time) - \(distKm)km, \(durationMin)min"
}

/// Format planned route info for display
public func formatPlannedRouteInfo(name: String, createdAtMillis: Int64, totalDistanceMeters: Float) -> String {
    let time = formatMilitaryDTG(millis: createdAtMillis)
    let distKm = String(format: "%.1f", totalDistanceMeters / 1000.0)
    return "\(name) - \(distKm)km (\(time))"
}

// MARK: - Distance Calculations

/// Calculate Haversine distance between two points in meters
public func haversineDistance(
    lat1: Double, lon1: Double,
    lat2: Double, lon2: Double
) -> Double {
    let R = 6371000.0 // Earth radius in meters

    let dLat = (lat2 - lat1).toRadians
    let dLon = (lon2 - lon1).toRadians

    let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1.toRadians) * cos(lat2.toRadians) *
            sin(dLon / 2) * sin(dLon / 2)

    let c = 2 * atan2(sqrt(a), sqrt(1 - a))

    return R * c
}

/// Calculate Haversine distance between two CLLocationCoordinate2D points
public func haversineDistance(
    from: CLLocationCoordinate2D,
    to: CLLocationCoordinate2D
) -> Double {
    return haversineDistance(
        lat1: from.latitude, lon1: from.longitude,
        lat2: to.latitude, lon2: to.longitude
    )
}

/// Calculate total distance of coordinates in meters
/// Works with any array of (lat, lon) tuples
public func calculateRouteDistance(_ coordinates: [(lat: Double, lon: Double)]) -> Float {
    guard coordinates.count >= 2 else { return 0 }

    var total: Double = 0
    for i in 0..<(coordinates.count - 1) {
        let a = coordinates[i]
        let b = coordinates[i + 1]
        total += haversineDistance(lat1: a.lat, lon1: a.lon, lat2: b.lat, lon2: b.lon)
    }
    return Float(total)
}

/// Calculate total distance of CLLocationCoordinate2D array in meters
public func calculateRouteDistance(_ coordinates: [CLLocationCoordinate2D]) -> Float {
    guard coordinates.count >= 2 else { return 0 }

    var total: Double = 0
    for i in 0..<(coordinates.count - 1) {
        total += haversineDistance(from: coordinates[i], to: coordinates[i + 1])
    }
    return Float(total)
}

// MARK: - Relative Time Formatting

/// Format timestamp as relative time for "last seen" display
/// Returns "just now", "X min ago", "X h ago", or absolute date if older than 24h
public func formatRelativeTime(_ timestampMillis: Int64) -> String {
    let now = Date.currentMillis
    let diff = now - timestampMillis

    let oneMinute: Int64 = 60_000
    let oneHour: Int64 = 60 * oneMinute
    let oneDay: Int64 = 24 * oneHour

    switch diff {
    case ..<oneMinute:
        return "just now"
    case ..<oneHour:
        return "\(diff / oneMinute) min ago"
    case ..<oneDay:
        return "\(diff / oneHour) h ago"
    default:
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let date = Date(timeIntervalSince1970: Double(timestampMillis) / 1000.0)
        return formatter.string(from: date)
    }
}

/// Format timestamp as relative time from Date
public func formatRelativeTime(_ date: Date) -> String {
    return formatRelativeTime(Int64(date.timeIntervalSince1970 * 1000))
}

// MARK: - String Normalization

/// Safe lowercase for optional strings
public func safeLower(_ string: String?) -> String {
    return string?.lowercased() ?? ""
}

/// Normalize possibly bogus "null"/"undefined" strings
public func nullIfLiteral(_ string: String?) -> String? {
    guard let s = string?.trimmingCharacters(in: .whitespaces), !s.isEmpty else {
        return nil
    }

    if s.lowercased() == "null" || s.lowercased() == "undefined" {
        return nil
    }

    return s
}

/// Normalize a nickname for display; hide IDs/UUID/base64-ish and blanks
public func displayNickname(_ raw: String?) -> String {
    guard let cleaned = nullIfLiteral(raw),
          !MapStringUtilities.looksLikeIdentifierHex(cleaned),
          !cleaned.isEmpty else {
        return "No nickname"
    }
    return cleaned
}

// MARK: - Duration Formatting

/// Format duration in milliseconds as human-readable string
public func formatDuration(_ millis: Int64) -> String {
    let totalSeconds = millis / 1000
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Format duration as compact string (e.g., "2h 30m")
public func formatDurationCompact(_ millis: Int64) -> String {
    let totalMinutes = millis / 60000
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60

    if hours > 0 && minutes > 0 {
        return "\(hours)h \(minutes)m"
    } else if hours > 0 {
        return "\(hours)h"
    } else {
        return "\(minutes)m"
    }
}

// MARK: - Distance Formatting

/// Format distance in meters as human-readable string
public func formatDistance(_ meters: Double, useMetric: Bool = true) -> String {
    if useMetric {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    } else {
        let feet = meters * 3.28084
        if feet >= 5280 {
            let miles = feet / 5280
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.0f ft", feet)
        }
    }
}

/// Format distance in meters as compact string
public func formatDistanceCompact(_ meters: Float) -> String {
    if meters >= 1000 {
        return String(format: "%.1fkm", meters / 1000)
    } else {
        return String(format: "%.0fm", meters)
    }
}

// MARK: - Speed Formatting

/// Format speed in meters per second as human-readable string
public func formatSpeed(_ metersPerSecond: Double, useMetric: Bool = true) -> String {
    if useMetric {
        let kmh = metersPerSecond * 3.6
        return String(format: "%.1f km/h", kmh)
    } else {
        let mph = metersPerSecond * 2.23694
        return String(format: "%.1f mph", mph)
    }
}

// MARK: - Bearing Formatting

/// Format bearing in degrees as cardinal direction
public func formatBearing(_ degrees: Double) -> String {
    let normalized = degrees.truncatingRemainder(dividingBy: 360)
    let adjusted = normalized < 0 ? normalized + 360 : normalized

    let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    let index = Int((adjusted + 22.5) / 45.0) % 8
    return directions[index]
}

/// Format bearing as degrees with direction
public func formatBearingFull(_ degrees: Double) -> String {
    let normalized = degrees.truncatingRemainder(dividingBy: 360)
    let adjusted = normalized < 0 ? normalized + 360 : normalized
    return String(format: "%.0f° %@", adjusted, formatBearing(adjusted))
}

// MARK: - Double Extension

private extension Double {
    var toRadians: Double {
        return self * .pi / 180.0
    }
}

// Note: Date.currentMillis is defined in Extensions.swift

// MARK: - Form Coordinate Formatting

/// Coordinate pattern matching for reformatting form descriptions
private let latLonPattern = #"(-?\d{1,3}\.\d+)\s*[,\s]\s*(-?\d{1,3}\.\d+)"#
private let mgrsPattern = #"\d{1,2}[A-Z]{1,3}\s*\d{4,10}"#

/// Reformat a pin description's coordinates based on the viewer's coordinate mode
/// This is used when displaying forms (7S, IFS) to match the user's preference
/// - Parameters:
///   - description: The original pin description
///   - coordMode: The viewer's coordinate display preference
///   - originalLat: The pin's latitude (for MGRS conversion if needed)
///   - originalLon: The pin's longitude (for MGRS conversion if needed)
/// - Returns: The description with coordinates reformatted
public func formatPinDescriptionWithCoordMode(
    _ description: String,
    coordMode: CoordMode,
    originalLat: Double? = nil,
    originalLon: Double? = nil
) -> String {
    guard !description.isEmpty else { return description }

    var result = description

    switch coordMode {
    case .mgrs:
        // Convert any lat/lon coordinates to MGRS
        result = replaceLatLonWithMGRS(in: result)

    case .latLon:
        // Convert any MGRS coordinates to lat/lon
        result = replaceMGRSWithLatLon(in: result)
    }

    return result
}

/// Replace lat/lon coordinates in text with MGRS format
private func replaceLatLonWithMGRS(in text: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: latLonPattern, options: []) else {
        return text
    }

    var result = text
    let range = NSRange(text.startIndex..., in: text)

    // Find all matches in reverse order to preserve indices
    let matches = regex.matches(in: text, options: [], range: range).reversed()

    for match in matches {
        guard let latRange = Range(match.range(at: 1), in: text),
              let lonRange = Range(match.range(at: 2), in: text),
              let lat = Double(text[latRange]),
              let lon = Double(text[lonRange]) else {
            continue
        }

        // Validate coordinates
        guard lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 else {
            continue
        }

        // Convert to MGRS
        let mgrs = MapCoordinateUtils.toMgrs(lat: lat, lon: lon)

        // Replace the matched text
        if let fullRange = Range(match.range, in: result) {
            result.replaceSubrange(fullRange, with: mgrs)
        }
    }

    return result
}

/// Replace MGRS coordinates in text with lat/lon format
private func replaceMGRSWithLatLon(in text: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: mgrsPattern, options: [.caseInsensitive]) else {
        return text
    }

    var result = text
    let range = NSRange(text.startIndex..., in: text)

    // Find all matches in reverse order to preserve indices
    let matches = regex.matches(in: text, options: [], range: range).reversed()

    for match in matches {
        guard let mgrsRange = Range(match.range, in: text) else {
            continue
        }

        let mgrsString = String(text[mgrsRange]).trimmingCharacters(in: .whitespaces)

        // Try to parse MGRS
        if let coord = MapCoordinateUtils.parseMgrs(mgrsString) {
            let latLon = String(format: "%.6f, %.6f", coord.latitude, coord.longitude)
            result.replaceSubrange(mgrsRange, with: latLon)
        }
    }

    return result
}

/// Format coordinates for display in a form based on the coordinate mode
/// - Parameters:
///   - lat: Latitude
///   - lon: Longitude
///   - coordMode: The coordinate display mode
/// - Returns: Formatted coordinate string
public func formatFormCoordinate(lat: Double, lon: Double, coordMode: CoordMode) -> String {
    switch coordMode {
    case .mgrs:
        return MapCoordinateUtils.toMgrs(lat: lat, lon: lon)
    case .latLon:
        return String(format: "%.6f, %.6f", lat, lon)
    }
}

/// Extract and reformat the "Grid Ref" field from a 7S form description
/// The 7S form typically has format: "Grid Ref: XXX\nTarget: YYY\n..."
public func reformat7SFormCoordinates(_ description: String, coordMode: CoordMode) -> String {
    let lines = description.components(separatedBy: "\n")
    var resultLines: [String] = []

    for line in lines {
        if line.lowercased().hasPrefix("grid ref:") || line.lowercased().hasPrefix("grid:") {
            // This line contains coordinates - reformat them
            let reformatted = formatPinDescriptionWithCoordMode(line, coordMode: coordMode)
            resultLines.append(reformatted)
        } else {
            resultLines.append(line)
        }
    }

    return resultLines.joined(separator: "\n")
}

/// Extract and reformat coordinates from an IFS form description
/// The IFS form typically has multiple coordinate fields
public func reformatIFSFormCoordinates(_ description: String, coordMode: CoordMode) -> String {
    let lines = description.components(separatedBy: "\n")
    var resultLines: [String] = []

    let coordinateFieldPrefixes = ["target:", "position:", "grid:", "coord:", "location:"]

    for line in lines {
        let lowercaseLine = line.lowercased()
        let hasCoordinateField = coordinateFieldPrefixes.contains { lowercaseLine.hasPrefix($0) }

        if hasCoordinateField {
            let reformatted = formatPinDescriptionWithCoordMode(line, coordMode: coordMode)
            resultLines.append(reformatted)
        } else {
            resultLines.append(line)
        }
    }

    return resultLines.joined(separator: "\n")
}

/// Format a form's complete description based on its type and the viewer's coordinate preference
/// - Parameters:
///   - pinType: The type of pin (e.g., .form7S, .formIFS)
///   - description: The original description
///   - coordMode: The viewer's coordinate display preference
/// - Returns: The reformatted description
public func formatFormDescriptionForViewer(
    pinType: NatoType,
    description: String,
    coordMode: CoordMode
) -> String {
    switch pinType {
    case .form7S:
        return reformat7SFormCoordinates(description, coordMode: coordMode)
    case .formIFS:
        return reformatIFSFormCoordinates(description, coordMode: coordMode)
    default:
        // For non-form pins, just do basic coordinate reformatting
        return formatPinDescriptionWithCoordMode(description, coordMode: coordMode)
    }
}
