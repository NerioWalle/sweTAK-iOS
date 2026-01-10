import Foundation
import CoreLocation

// MARK: - Coordinate Formatting

public struct CoordinateFormatter {

    // MARK: - MGRS Formatting

    /// Convert latitude/longitude to MGRS string
    /// Format: <Grid Zone><Band><100km Square><Easting><Northing>
    /// Example: 33U UP 12345 67890
    public static func toMGRS(latitude: Double, longitude: Double, precision: Int = 5) -> String {
        // Handle polar regions (not standard UTM)
        guard latitude >= -80 && latitude <= 84 else {
            return formatDecimal(latitude: latitude, longitude: longitude)
        }

        // Calculate UTM zone (1-60)
        var zone = Int((longitude + 180) / 6) + 1

        // Handle Norway/Svalbard exceptions
        if latitude >= 56 && latitude < 64 && longitude >= 3 && longitude < 12 {
            zone = 32
        } else if latitude >= 72 && latitude < 84 {
            if longitude >= 0 && longitude < 9 { zone = 31 }
            else if longitude >= 9 && longitude < 21 { zone = 33 }
            else if longitude >= 21 && longitude < 33 { zone = 35 }
            else if longitude >= 33 && longitude < 42 { zone = 37 }
        }

        // Calculate latitude band letter (C-X, excluding I and O)
        let bandLetters = "CDEFGHJKLMNPQRSTUVWX"
        let bandIndex = min(max(Int((latitude + 80) / 8), 0), bandLetters.count - 1)
        let band = String(bandLetters[bandLetters.index(bandLetters.startIndex, offsetBy: bandIndex)])

        // Calculate UTM coordinates
        let (easting, northing) = latLonToUTM(latitude: latitude, longitude: longitude, zone: zone)

        // Calculate 100km square identifier
        let col = Int(easting / 100000)
        let row = Int(northing / 100000) % 20

        // Column letters (A-H, J-N, P-Z, repeating every 3 zones)
        let setNumber = (zone - 1) % 3
        let colLetters: [String] = ["ABCDEFGH", "JKLMNPQR", "STUVWXYZ"]
        let colLetter = String(colLetters[setNumber][colLetters[setNumber].index(colLetters[setNumber].startIndex, offsetBy: (col - 1) % 8)])

        // Row letters (A-V excluding I and O, repeating)
        let rowLetters = "ABCDEFGHJKLMNPQRSTUV"
        let rowOffset = (zone % 2 == 0) ? 5 : 0
        let rowIndex = (row + rowOffset) % 20
        let rowLetter = String(rowLetters[rowLetters.index(rowLetters.startIndex, offsetBy: rowIndex)])

        // Get easting and northing within 100km square
        let e = Int(easting) % 100000
        let n = Int(northing) % 100000

        // Format based on precision (1-5)
        let divisor = Int(pow(10.0, Double(5 - precision)))
        let eStr = String(format: "%0\(precision)d", e / divisor)
        let nStr = String(format: "%0\(precision)d", n / divisor)

        return "\(zone)\(band) \(colLetter)\(rowLetter) \(eStr) \(nStr)"
    }

    /// Convert lat/lon to UTM easting/northing
    private static func latLonToUTM(latitude: Double, longitude: Double, zone: Int) -> (Double, Double) {
        let k0 = 0.9996
        let a = 6378137.0 // WGS84 semi-major axis
        let e2 = 0.00669438 // WGS84 eccentricity squared

        let latRad = latitude * .pi / 180
        let lonRad = longitude * .pi / 180
        let lonOrigin = Double((zone - 1) * 6 - 180 + 3) * .pi / 180

        let N = a / sqrt(1 - e2 * sin(latRad) * sin(latRad))
        let T = tan(latRad) * tan(latRad)
        let C = e2 / (1 - e2) * cos(latRad) * cos(latRad)
        let A = cos(latRad) * (lonRad - lonOrigin)

        let M = a * ((1 - e2/4 - 3*e2*e2/64) * latRad
                     - (3*e2/8 + 3*e2*e2/32) * sin(2*latRad)
                     + (15*e2*e2/256) * sin(4*latRad))

        let easting = k0 * N * (A + (1-T+C) * A*A*A/6 + (5-18*T+T*T) * pow(A, 5)/120) + 500000
        var northing = k0 * (M + N * tan(latRad) * (A*A/2 + (5-T+9*C+4*C*C) * pow(A, 4)/24))

        if latitude < 0 {
            northing += 10000000
        }

        return (easting, northing)
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

    /// Format coordinates based on the CoordinateFormat setting
    public static func format(
        latitude: Double,
        longitude: Double,
        format: CoordinateFormat
    ) -> String {
        switch format {
        case .mgrs:
            return toMGRS(latitude: latitude, longitude: longitude)
        case .decimal:
            return formatDecimal(latitude: latitude, longitude: longitude)
        case .dms:
            return formatDMS(latitude: latitude, longitude: longitude)
        case .utm:
            return formatUTM(latitude: latitude, longitude: longitude)
        }
    }

    // MARK: - UTM Formatting

    /// Format as UTM (e.g., "34T 123456 6789012")
    public static func formatUTM(latitude: Double, longitude: Double) -> String {
        // Calculate UTM zone
        let zone = Int((longitude + 180) / 6) + 1

        // Calculate zone letter
        let letters = "CDEFGHJKLMNPQRSTUVWX"
        let letterIndex = Int((latitude + 80) / 8)
        let letter = letterIndex >= 0 && letterIndex < letters.count
            ? String(letters[letters.index(letters.startIndex, offsetBy: min(letterIndex, letters.count - 1))])
            : "N"

        // Simplified UTM calculation (approximate)
        let lonOrigin = Double((zone - 1) * 6 - 180 + 3) * .pi / 180
        let latRad = latitude * .pi / 180
        let lonRad = longitude * .pi / 180

        let k0 = 0.9996
        let a = 6378137.0 // WGS84 semi-major axis
        let e2 = 0.00669438 // WGS84 eccentricity squared

        let N = a / sqrt(1 - e2 * sin(latRad) * sin(latRad))
        let T = tan(latRad) * tan(latRad)
        let C = e2 / (1 - e2) * cos(latRad) * cos(latRad)
        let A = cos(latRad) * (lonRad - lonOrigin)

        let M = a * ((1 - e2/4 - 3*e2*e2/64) * latRad
                     - (3*e2/8 + 3*e2*e2/32) * sin(2*latRad)
                     + (15*e2*e2/256) * sin(4*latRad))

        let easting = k0 * N * (A + (1-T+C) * A*A*A/6) + 500000
        let northing = k0 * (M + N * tan(latRad) * (A*A/2 + (5-T+9*C+4*C*C) * A*A*A*A/24))
        let adjustedNorthing = latitude < 0 ? northing + 10000000 : northing

        return String(format: "%d%@ %.0f %.0f", zone, letter, easting, adjustedNorthing)
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
