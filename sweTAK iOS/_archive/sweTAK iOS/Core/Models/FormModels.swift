import Foundation
import CoreLocation

// MARK: - Form Types

/// Types of linked forms that can be attached to OP pins
public enum FormType: String, Codable, CaseIterable {
    case sevenS = "7S"
    case indirectFire = "IFS"

    public var displayName: String {
        switch self {
        case .sevenS: return "7S Observation Report"
        case .indirectFire: return "Indirect Fire Support Request"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .sevenS: return "doc.fill"
        case .indirectFire: return "scope"
        }
    }
}

// MARK: - 7S Form Data

/// 7S observation report data model.
/// Used for enemy observation reports with the 7 S's:
/// - Scene (date/time, place)
/// - Size (force size)
/// - Sort (type of enemy)
/// - Sysselsattning (occupation/activity)
/// - Symbols (distinguishing features)
/// - Signal (reporter)
/// - Samband (additional info)
public struct SevenSFormData: Codable, Equatable {
    public var dateTime: String        // DDHHMM format
    public var place: String           // MGRS or Lat/Lon
    public var forceSize: String       // Number or description
    public var type: String            // Type of enemy forces
    public var occupation: String      // What they're doing
    public var symbols: String         // Distinguishing features
    public var reporter: String        // Callsign of reporter

    // Raw coordinates for display formatting
    public var latitude: Double?
    public var longitude: Double?

    public init(
        dateTime: String = "",
        place: String = "",
        forceSize: String = "",
        type: String = "",
        occupation: String = "",
        symbols: String = "",
        reporter: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.dateTime = dateTime
        self.place = place
        self.forceSize = forceSize
        self.type = type
        self.occupation = occupation
        self.symbols = symbols
        self.reporter = reporter
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Convert to JSON string for storage in LinkedForm
    public func toJSONString() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }

    /// Parse from JSON string
    public static func fromJSONString(_ json: String) -> SevenSFormData? {
        guard let data = json.data(using: .utf8),
              let formData = try? JSONDecoder().decode(SevenSFormData.self, from: data) else {
            return nil
        }
        return formData
    }

    /// Create a pre-filled draft with current date/time and location
    public static func createDraft(
        reporter: String,
        latitude: Double?,
        longitude: Double?,
        placeText: String?
    ) -> SevenSFormData {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "ddHHmm"
        let dateTimeString = formatter.string(from: now)

        let placeString: String
        if let text = placeText {
            placeString = text
        } else if let lat = latitude, let lon = longitude {
            placeString = String(format: "%.6f, %.6f", lat, lon)
        } else {
            placeString = ""
        }

        return SevenSFormData(
            dateTime: dateTimeString,
            place: placeString,
            reporter: reporter,
            latitude: latitude,
            longitude: longitude
        )
    }
}

// MARK: - Indirect Fire Support Form Data

/// Request types for indirect fire support
public enum IFSRequestType: String, Codable, CaseIterable {
    case fight = "Fight"
    case keepDown = "Keep down"
    case block = "Block"
    case smoke = "Smoke"
    case illuminate = "Illuminate"

    public var displayName: String { rawValue }
}

/// Indirect Fire Support request form data model.
/// Used for requesting artillery/mortar fire support.
public struct IndirectFireFormData: Codable, Equatable {
    public var observer: String            // Observer's callsign
    public var requestType: IFSRequestType // Type of fire request
    public var targetDescription: String   // What is the target
    public var observerPosition: String    // Observer's coordinates
    public var enemyForces: String         // Description of enemy forces
    public var enemyActivity: String       // What the enemy is doing
    public var targetTerrain: String       // Terrain at target location
    public var widthMeters: Int?           // Target area width
    public var angleOfViewMils: Int?       // Bearing to target in mils
    public var distanceMeters: Int?        // Distance to target

    // Raw coordinates for calculations
    public var targetLatitude: Double?
    public var targetLongitude: Double?
    public var observerLatitude: Double?
    public var observerLongitude: Double?

    public init(
        observer: String = "",
        requestType: IFSRequestType = .fight,
        targetDescription: String = "",
        observerPosition: String = "",
        enemyForces: String = "",
        enemyActivity: String = "",
        targetTerrain: String = "",
        widthMeters: Int? = nil,
        angleOfViewMils: Int? = nil,
        distanceMeters: Int? = nil,
        targetLatitude: Double? = nil,
        targetLongitude: Double? = nil,
        observerLatitude: Double? = nil,
        observerLongitude: Double? = nil
    ) {
        self.observer = observer
        self.requestType = requestType
        self.targetDescription = targetDescription
        self.observerPosition = observerPosition
        self.enemyForces = enemyForces
        self.enemyActivity = enemyActivity
        self.targetTerrain = targetTerrain
        self.widthMeters = widthMeters
        self.angleOfViewMils = angleOfViewMils
        self.distanceMeters = distanceMeters
        self.targetLatitude = targetLatitude
        self.targetLongitude = targetLongitude
        self.observerLatitude = observerLatitude
        self.observerLongitude = observerLongitude
    }

    /// Convert to JSON string for storage in LinkedForm
    public func toJSONString() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }

    /// Parse from JSON string
    public static func fromJSONString(_ json: String) -> IndirectFireFormData? {
        guard let data = json.data(using: .utf8),
              let formData = try? JSONDecoder().decode(IndirectFireFormData.self, from: data) else {
            return nil
        }
        return formData
    }

    /// Create a pre-filled draft
    public static func createDraft(
        observer: String,
        observerLatitude: Double?,
        observerLongitude: Double?,
        observerPositionText: String?,
        targetLatitude: Double?,
        targetLongitude: Double?
    ) -> IndirectFireFormData {
        var draft = IndirectFireFormData(
            observer: observer,
            targetLatitude: targetLatitude,
            targetLongitude: targetLongitude,
            observerLatitude: observerLatitude,
            observerLongitude: observerLongitude
        )

        // Set observer position text
        if let text = observerPositionText {
            draft.observerPosition = text
        } else if let lat = observerLatitude, let lon = observerLongitude {
            draft.observerPosition = String(format: "%.6f, %.6f", lat, lon)
        }

        // Calculate distance and bearing if both positions available
        if let obsLat = observerLatitude, let obsLon = observerLongitude,
           let tgtLat = targetLatitude, let tgtLon = targetLongitude {
            let observerLoc = CLLocation(latitude: obsLat, longitude: obsLon)
            let targetLoc = CLLocation(latitude: tgtLat, longitude: tgtLon)

            // Distance in meters
            draft.distanceMeters = Int(targetLoc.distance(from: observerLoc))

            // Bearing in mils (0-6400)
            draft.angleOfViewMils = calculateBearingMils(
                from: CLLocationCoordinate2D(latitude: obsLat, longitude: obsLon),
                to: CLLocationCoordinate2D(latitude: tgtLat, longitude: tgtLon)
            )
        }

        return draft
    }
}

// MARK: - Utility Functions

/// Calculate bearing from one coordinate to another in NATO mils (0-6400)
private func calculateBearingMils(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Int {
    let lat1 = from.latitude * .pi / 180
    let lat2 = to.latitude * .pi / 180
    let dLon = (to.longitude - from.longitude) * .pi / 180

    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    var bearingDeg = atan2(y, x) * 180 / .pi

    if bearingDeg < 0 {
        bearingDeg += 360
    }

    let mils = bearingDeg / 360.0 * 6400.0
    return Int(mils.rounded())
}
