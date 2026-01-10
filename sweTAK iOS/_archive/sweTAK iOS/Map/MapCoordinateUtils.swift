import Foundation
import CoreLocation

// Note: CoordMode, UnitSystem, and PositionUnit are defined in MapModels.swift

// MARK: - MGRS Conversion Cache

private var lastMgrsLat: Double?
private var lastMgrsLon: Double?
private var lastMgrsString: String?

// MARK: - Coordinate Utilities

/// Map coordinate utilities for conversion, validation, and formatting
/// Mirrors Android MapCoordinateUtils functionality
public enum MapCoordinateUtils {

    // MARK: - MGRS Conversion

    /// Convert latitude/longitude to MGRS string
    /// Uses a simple cache to avoid recomputing when called repeatedly with identical coordinates
    public static func toMgrs(lat: Double, lon: Double) -> String {
        // Check cache
        if let cachedLat = lastMgrsLat,
           let cachedLon = lastMgrsLon,
           let cachedString = lastMgrsString,
           cachedLat == lat && cachedLon == lon {
            return cachedString
        }

        // Convert to MGRS
        let result = convertToMGRS(latitude: lat, longitude: lon)

        // Cache result
        lastMgrsLat = lat
        lastMgrsLon = lon
        lastMgrsString = result

        return result
    }

    /// Parse a lat/lon string like "59.123, 18.456" or "59.123 18.456"
    public static func parseLatLon(_ text: String) -> CLLocationCoordinate2D? {
        let cleaned = text.replacingOccurrences(of: ",", with: " ")
        let parts = cleaned.split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }

        guard parts.count == 2,
              let lat = Double(parts[0]),
              let lon = Double(parts[1]),
              isValidLatitude(lat),
              isValidLongitude(lon) else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Parse an MGRS string and convert to coordinate
    public static func parseMgrs(_ text: String) -> CLLocationCoordinate2D? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        guard !cleaned.isEmpty else { return nil }

        return convertFromMGRS(cleaned)
    }

    /// Parse coordinate input based on the current coordinate mode
    public static func parseCoordinateInput(_ input: String, coordMode: CoordMode) -> CLLocationCoordinate2D? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        switch coordMode {
        case .latLon: return parseLatLon(trimmed)
        case .mgrs: return parseMgrs(trimmed)
        }
    }

    // MARK: - Distance Calculation

    /// Calculate distance in meters between two coordinates using Haversine formula
    public static func haversineMeters(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let R = 6371000.0 // Earth radius in meters

        let lat1Rad = a.latitude * .pi / 180
        let lat2Rad = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180

        let x = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(x), sqrt(1 - x))

        return R * c
    }

    // MARK: - Bounds Calculation

    /// Calculate coordinate bounds for a radius around a center point
    public struct CoordinateBounds {
        public let north: Double
        public let south: Double
        public let east: Double
        public let west: Double

        public var northEast: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: north, longitude: east)
        }

        public var southWest: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: south, longitude: west)
        }
    }

    /// Build coordinate bounds that enclose a circle of radiusMeters around center
    public static func boundsForRadius(center: CLLocationCoordinate2D, radiusMeters: Double) -> CoordinateBounds {
        let R = 6371000.0 // Earth radius in meters
        let latRad = center.latitude * .pi / 180
        let lonRad = center.longitude * .pi / 180

        let dLat = radiusMeters / R
        let dLon = radiusMeters / (R * cos(latRad))

        let north = (latRad + dLat) * 180 / .pi
        let south = (latRad - dLat) * 180 / .pi
        let east = (lonRad + dLon) * 180 / .pi
        let west = (lonRad - dLon) * 180 / .pi

        return CoordinateBounds(north: north, south: south, east: east, west: west)
    }

    // MARK: - Unit Conversion

    /// Convert meters to feet
    public static func metersToFeet(_ meters: Double) -> Double {
        meters * 3.280839895
    }

    /// Convert feet to meters
    public static func feetToMeters(_ feet: Double) -> Double {
        feet / 3.280839895
    }

    /// Convert kilometers to miles
    public static func kilometersToMiles(_ km: Double) -> Double {
        km * 0.621371
    }

    /// Convert miles to kilometers
    public static func milesToKilometers(_ miles: Double) -> Double {
        miles / 0.621371
    }

    // MARK: - Formatting

    /// Format distance for display based on unit system
    public static func formatDistance(_ meters: Double, units: UnitSystem) -> String {
        switch units {
        case .metric:
            if meters >= 1000 {
                return String(format: "%.2f km", meters / 1000.0)
            } else {
                return String(format: "%.0f m", meters)
            }
        case .imperial:
            let feet = metersToFeet(meters)
            if feet >= 5280 {
                return String(format: "%.2f mi", feet / 5280.0)
            } else {
                return String(format: "%.0f ft", feet)
            }
        }
    }

    /// Format altitude for display based on unit system
    public static func formatAltitude(_ meters: Double, units: UnitSystem) -> String {
        switch units {
        case .metric:
            return String(format: "%.0f m", meters)
        case .imperial:
            return String(format: "%.0f ft", metersToFeet(meters))
        }
    }

    /// Format speed for display based on unit system
    public static func formatSpeed(_ metersPerSecond: Double, units: UnitSystem) -> String {
        switch units {
        case .metric:
            let kmh = metersPerSecond * 3.6
            return String(format: "%.1f km/h", kmh)
        case .imperial:
            let mph = metersPerSecond * 2.23694
            return String(format: "%.1f mph", mph)
        }
    }

    /// Format a coordinate for display based on mode
    public static func formatCoordinate(lat: Double, lon: Double, mode: CoordMode) -> String {
        switch mode {
        case .mgrs:
            return toMgrs(lat: lat, lon: lon)
        case .latLon:
            return String(format: "%.6f, %.6f", lat, lon)
        }
    }

    /// Format coordinate for form display (7S/IFS)
    public static func formatPlaceFor7S(lat: Double, lon: Double, mode: CoordMode) -> String {
        switch mode {
        case .mgrs:
            return toMgrs(lat: lat, lon: lon)
        case .latLon:
            return String(format: "%.5f, %.5f", lat, lon)
        }
    }

    /// Format optional coordinates
    public static func formatPlaceFor7S(lat: Double?, lon: Double?, mode: CoordMode) -> String {
        guard let lat = lat, let lon = lon else { return "" }
        return formatPlaceFor7S(lat: lat, lon: lon, mode: mode)
    }

    // MARK: - Validation

    /// Validate that latitude is within valid range (-90 to 90 degrees)
    public static func isValidLatitude(_ lat: Double) -> Bool {
        lat.isFinite && lat >= -90.0 && lat <= 90.0
    }

    /// Validate that longitude is within valid range (-180 to 180 degrees)
    public static func isValidLongitude(_ lon: Double) -> Bool {
        lon.isFinite && lon >= -180.0 && lon <= 180.0
    }

    /// Validate a coordinate pair
    public static func isValidCoordinate(lat: Double, lon: Double) -> Bool {
        isValidLatitude(lat) && isValidLongitude(lon)
    }

    /// Validate a CLLocationCoordinate2D
    public static func isValidCoordinate(_ coord: CLLocationCoordinate2D) -> Bool {
        isValidCoordinate(lat: coord.latitude, lon: coord.longitude)
    }

    /// Validate and clamp latitude to valid range
    public static func clampLatitude(_ lat: Double) -> Double? {
        guard lat.isFinite else { return nil }
        return max(-90.0, min(90.0, lat))
    }

    /// Validate and clamp longitude to valid range
    public static func clampLongitude(_ lon: Double) -> Double? {
        guard lon.isFinite else { return nil }
        return max(-180.0, min(180.0, lon))
    }

    /// Clamp coordinate to valid range
    public static func clampCoordinate(_ coord: CLLocationCoordinate2D) -> CLLocationCoordinate2D? {
        guard let lat = clampLatitude(coord.latitude),
              let lon = clampLongitude(coord.longitude) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: - MGRS Implementation

    /// Convert latitude/longitude to MGRS string
    /// Simplified implementation - for production use, consider using a dedicated MGRS library
    private static func convertToMGRS(latitude: Double, longitude: Double) -> String {
        // Validate coordinates
        guard isValidCoordinate(lat: latitude, lon: longitude) else {
            return String(format: "%.5f, %.5f", latitude, longitude)
        }

        // UTM Zone calculation
        let zoneNumber = Int((longitude + 180) / 6) + 1

        // Zone letter
        let zoneLetter = getZoneLetter(latitude: latitude)

        // Convert to UTM
        let (easting, northing) = latLonToUTM(latitude: latitude, longitude: longitude, zoneNumber: zoneNumber)

        // Get 100km square identifier
        let (col, row) = get100kIdentifier(easting: easting, northing: northing, zoneNumber: zoneNumber)

        // Format easting/northing to 5 digits each (1m precision)
        let eastingDigits = Int(easting) % 100000
        let northingDigits = Int(northing) % 100000

        return String(format: "%d%@%@%@ %05d %05d",
                      zoneNumber, zoneLetter, col, row,
                      eastingDigits, northingDigits)
    }

    /// Parse MGRS string to latitude/longitude
    private static func convertFromMGRS(_ mgrs: String) -> CLLocationCoordinate2D? {
        // Remove spaces and validate format
        let cleaned = mgrs.uppercased().replacingOccurrences(of: " ", with: "")
        guard cleaned.count >= 5 else { return nil }

        // Parse zone number (1-2 digits)
        var index = cleaned.startIndex
        var zoneStr = ""
        while index < cleaned.endIndex && cleaned[index].isNumber {
            zoneStr.append(cleaned[index])
            index = cleaned.index(after: index)
        }
        guard let zoneNumber = Int(zoneStr), zoneNumber >= 1 && zoneNumber <= 60 else {
            return nil
        }

        // Parse zone letter
        guard index < cleaned.endIndex else { return nil }
        let zoneLetter = cleaned[index]
        index = cleaned.index(after: index)

        // Parse 100km square (2 letters)
        guard index < cleaned.endIndex else { return nil }
        let col = cleaned[index]
        index = cleaned.index(after: index)

        guard index < cleaned.endIndex else { return nil }
        let row = cleaned[index]
        index = cleaned.index(after: index)

        // Parse easting/northing digits
        let remaining = String(cleaned[index...])
        let digitCount = remaining.count / 2
        guard digitCount > 0 && remaining.count % 2 == 0 else { return nil }

        let eastingStr = String(remaining.prefix(digitCount))
        let northingStr = String(remaining.suffix(digitCount))

        guard let eastingVal = Int(eastingStr),
              let northingVal = Int(northingStr) else {
            return nil
        }

        // Scale to meters based on precision
        let scale = Int(pow(10.0, Double(5 - digitCount)))
        let easting = eastingVal * scale
        let northing = northingVal * scale

        // Convert 100km square to offset
        let (colOffset, rowOffset) = parse100kIdentifier(col: col, row: row, zoneNumber: zoneNumber)

        // Full UTM coordinates
        let fullEasting = Double(colOffset * 100000 + easting)
        let fullNorthing = Double(rowOffset * 100000 + northing)

        // Convert UTM to lat/lon
        return utmToLatLon(easting: fullEasting, northing: fullNorthing,
                          zoneNumber: zoneNumber, zoneLetter: zoneLetter)
    }

    // MARK: - UTM Helpers

    private static func getZoneLetter(latitude: Double) -> String {
        let letters = "CDEFGHJKLMNPQRSTUVWXX"
        let index = max(0, min(20, Int((latitude + 80) / 8)))
        return String(letters[letters.index(letters.startIndex, offsetBy: index)])
    }

    private static func latLonToUTM(latitude: Double, longitude: Double, zoneNumber: Int) -> (easting: Double, northing: Double) {
        let a = 6378137.0 // WGS84 semi-major axis
        let f = 1.0 / 298.257223563 // WGS84 flattening
        let k0 = 0.9996 // UTM scale factor

        let e2 = 2 * f - f * f
        let e4 = e2 * e2
        let e6 = e4 * e2

        let latRad = latitude * .pi / 180
        let lonRad = longitude * .pi / 180

        let lonOrigin = Double((zoneNumber - 1) * 6 - 180 + 3) * .pi / 180

        let N = a / sqrt(1 - e2 * sin(latRad) * sin(latRad))
        let T = tan(latRad) * tan(latRad)
        let C = e2 / (1 - e2) * cos(latRad) * cos(latRad)
        let A = cos(latRad) * (lonRad - lonOrigin)

        let M = a * ((1 - e2/4 - 3*e4/64 - 5*e6/256) * latRad
                    - (3*e2/8 + 3*e4/32 + 45*e6/1024) * sin(2*latRad)
                    + (15*e4/256 + 45*e6/1024) * sin(4*latRad)
                    - (35*e6/3072) * sin(6*latRad))

        let easting = k0 * N * (A + (1-T+C) * A*A*A/6
                    + (5 - 18*T + T*T + 72*C - 58*e2/(1-e2)) * pow(A, 5)/120) + 500000

        var northing = k0 * (M + N * tan(latRad) * (A*A/2 + (5 - T + 9*C + 4*C*C) * pow(A, 4)/24
                    + (61 - 58*T + T*T + 600*C - 330*e2/(1-e2)) * pow(A, 6)/720))

        if latitude < 0 {
            northing += 10000000
        }

        return (easting, northing)
    }

    private static func utmToLatLon(easting: Double, northing: Double, zoneNumber: Int, zoneLetter: Character) -> CLLocationCoordinate2D? {
        let a = 6378137.0
        let f = 1.0 / 298.257223563
        let k0 = 0.9996

        let e2 = 2 * f - f * f
        let e1 = (1 - sqrt(1 - e2)) / (1 + sqrt(1 - e2))

        var adjustedNorthing = northing
        if zoneLetter < "N" {
            adjustedNorthing -= 10000000
        }

        let x = easting - 500000
        let M = adjustedNorthing / k0

        let mu = M / (a * (1 - e2/4 - 3*e2*e2/64 - 5*e2*e2*e2/256))

        let phi1 = mu + (3*e1/2 - 27*pow(e1, 3)/32) * sin(2*mu)
                      + (21*e1*e1/16 - 55*pow(e1, 4)/32) * sin(4*mu)
                      + (151*pow(e1, 3)/96) * sin(6*mu)

        let N1 = a / sqrt(1 - e2 * sin(phi1) * sin(phi1))
        let T1 = tan(phi1) * tan(phi1)
        let C1 = e2 / (1 - e2) * cos(phi1) * cos(phi1)
        let R1 = a * (1 - e2) / pow(1 - e2 * sin(phi1) * sin(phi1), 1.5)
        let D = x / (N1 * k0)

        let lat = phi1 - (N1 * tan(phi1) / R1) * (D*D/2 - (5 + 3*T1 + 10*C1 - 4*C1*C1 - 9*e2/(1-e2)) * pow(D, 4)/24
                    + (61 + 90*T1 + 298*C1 + 45*T1*T1 - 252*e2/(1-e2) - 3*C1*C1) * pow(D, 6)/720)

        let lonOrigin = Double((zoneNumber - 1) * 6 - 180 + 3) * .pi / 180
        let lon = lonOrigin + (D - (1 + 2*T1 + C1) * pow(D, 3)/6
                    + (5 - 2*C1 + 28*T1 - 3*C1*C1 + 8*e2/(1-e2) + 24*T1*T1) * pow(D, 5)/120) / cos(phi1)

        let latitude = lat * 180 / .pi
        let longitude = lon * 180 / .pi

        guard isValidCoordinate(lat: latitude, lon: longitude) else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func get100kIdentifier(easting: Double, northing: Double, zoneNumber: Int) -> (col: String, row: String) {
        let setNumber = zoneNumber % 6
        let colLetters = ["ABCDEFGH", "JKLMNPQR", "STUVWXYZ", "ABCDEFGH", "JKLMNPQR", "STUVWXYZ"]
        let rowLetters = ["ABCDEFGHJKLMNPQRSTUV", "FGHJKLMNPQRSTUVABCDE"]

        let colIndex = Int(easting / 100000) - 1
        let rowIndex = Int(northing / 100000) % 20

        let colSet = colLetters[setNumber]
        let rowSet = rowLetters[setNumber % 2]

        let col = String(colSet[colSet.index(colSet.startIndex, offsetBy: colIndex % 8)])
        let row = String(rowSet[rowSet.index(rowSet.startIndex, offsetBy: rowIndex)])

        return (col, row)
    }

    private static func parse100kIdentifier(col: Character, row: Character, zoneNumber: Int) -> (colOffset: Int, rowOffset: Int) {
        let setNumber = zoneNumber % 6
        let colLetters = ["ABCDEFGH", "JKLMNPQR", "STUVWXYZ", "ABCDEFGH", "JKLMNPQR", "STUVWXYZ"]
        let rowLetters = ["ABCDEFGHJKLMNPQRSTUV", "FGHJKLMNPQRSTUVABCDE"]

        let colSet = colLetters[setNumber]
        let rowSet = rowLetters[setNumber % 2]

        let colOffset = (colSet.firstIndex(of: col).map { colSet.distance(from: colSet.startIndex, to: $0) } ?? 0) + 1
        let rowOffset = rowSet.firstIndex(of: row).map { rowSet.distance(from: rowSet.startIndex, to: $0) } ?? 0

        return (colOffset, rowOffset)
    }
}

// MARK: - CLLocationCoordinate2D Extension

extension CLLocationCoordinate2D {
    /// Format coordinate for display
    public func formatted(mode: CoordMode) -> String {
        MapCoordinateUtils.formatCoordinate(lat: latitude, lon: longitude, mode: mode)
    }

    /// Distance to another coordinate in meters using Haversine formula
    public func haversineDistance(to other: CLLocationCoordinate2D) -> Double {
        MapCoordinateUtils.haversineMeters(from: self, to: other)
    }

    /// Check if coordinate is valid
    public var isValid: Bool {
        MapCoordinateUtils.isValidCoordinate(self)
    }
}
