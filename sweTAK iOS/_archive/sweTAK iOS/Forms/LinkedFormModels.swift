import Foundation
import CoreLocation

// MARK: - Form Types

/// Standard form types for linked forms
public enum LinkedFormType: String, CaseIterable {
    /// Call for Fire report
    case callForFire = "CFF"

    /// 9-Line MEDEVAC request
    case medevac = "MEDEVAC"

    /// METHANE casualty report
    case methane = "METHANE"

    /// Situation Report
    case sitrep = "SITREP"

    /// Contact Report
    case contact = "CONTACT"

    /// Spot Report
    case spot = "SPOT"

    /// Intelligence Report
    case intrep = "INTREP"

    /// Artillery Adjustment
    case adjustment = "ADJUST"

    /// Generic observation note
    case observation = "OBS"

    public var displayName: String {
        switch self {
        case .callForFire: return "Call for Fire"
        case .medevac: return "9-Line MEDEVAC"
        case .methane: return "METHANE Report"
        case .sitrep: return "Situation Report"
        case .contact: return "Contact Report"
        case .spot: return "Spot Report"
        case .intrep: return "Intelligence Report"
        case .adjustment: return "Fire Adjustment"
        case .observation: return "Observation"
        }
    }

    public var abbreviation: String {
        rawValue
    }
}

// MARK: - Call for Fire Form Data

/// Structured data for Call for Fire reports
public struct CallForFireData: Codable, Equatable {
    /// Observer identification
    public let observerId: String

    /// Warning order (e.g., "FIRE MISSION")
    public let warningOrder: String

    /// Target location (grid reference or coordinates)
    public let targetLocation: String

    /// Target description
    public let targetDescription: String

    /// Method of engagement
    public let methodOfEngagement: String

    /// Method of fire and control
    public let methodOfFireControl: String

    /// Additional remarks
    public let remarks: String?

    /// Timestamp
    public let timestamp: Int64

    public init(
        observerId: String,
        warningOrder: String = "FIRE MISSION",
        targetLocation: String,
        targetDescription: String,
        methodOfEngagement: String = "ADJUST FIRE",
        methodOfFireControl: String = "AT MY COMMAND",
        remarks: String? = nil,
        timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.observerId = observerId
        self.warningOrder = warningOrder
        self.targetLocation = targetLocation
        self.targetDescription = targetDescription
        self.methodOfEngagement = methodOfEngagement
        self.methodOfFireControl = methodOfFireControl
        self.remarks = remarks
        self.timestamp = timestamp
    }

    /// Encode to JSON string for storage
    public func toJSONString() -> String? {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    /// Decode from JSON string
    public static func fromJSONString(_ json: String) -> CallForFireData? {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(CallForFireData.self, from: data) else {
            return nil
        }
        return decoded
    }
}

// MARK: - Fire Adjustment Data

/// Data for artillery fire adjustments
public struct FireAdjustmentData: Codable, Equatable {
    /// Original CFF form ID being adjusted
    public let originalFormId: Int64

    /// Adjustment type
    public let adjustmentType: AdjustmentType

    /// Direction adjustment (mils or degrees)
    public let direction: String?

    /// Distance adjustment (meters)
    public let distance: Int?

    /// Vertical adjustment (ADD/DROP in meters)
    public let vertical: String?

    /// Additional fire commands
    public let fireCommand: String?

    /// Remarks
    public let remarks: String?

    public enum AdjustmentType: String, Codable {
        case add = "ADD"
        case drop = "DROP"
        case left = "LEFT"
        case right = "RIGHT"
        case fireForEffect = "FFE"
        case repeat_ = "REPEAT"
        case endOfMission = "EOM"
    }

    public init(
        originalFormId: Int64,
        adjustmentType: AdjustmentType,
        direction: String? = nil,
        distance: Int? = nil,
        vertical: String? = nil,
        fireCommand: String? = nil,
        remarks: String? = nil
    ) {
        self.originalFormId = originalFormId
        self.adjustmentType = adjustmentType
        self.direction = direction
        self.distance = distance
        self.vertical = vertical
        self.fireCommand = fireCommand
        self.remarks = remarks
    }

    public func toJSONString() -> String? {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    public static func fromJSONString(_ json: String) -> FireAdjustmentData? {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(FireAdjustmentData.self, from: data) else {
            return nil
        }
        return decoded
    }
}

// MARK: - Spot Report Data

/// SALUTE format spot report data
public struct SpotReportData: Codable, Equatable {
    /// Size - number and type of personnel/vehicles
    public let size: String

    /// Activity - what they are doing
    public let activity: String

    /// Location - where observed
    public let location: String

    /// Unit - identification or uniforms
    public let unit: String

    /// Time - when observed
    public let time: String

    /// Equipment - weapons and equipment
    public let equipment: String

    /// Additional remarks
    public let remarks: String?

    public init(
        size: String,
        activity: String,
        location: String,
        unit: String,
        time: String,
        equipment: String,
        remarks: String? = nil
    ) {
        self.size = size
        self.activity = activity
        self.location = location
        self.unit = unit
        self.time = time
        self.equipment = equipment
        self.remarks = remarks
    }

    /// Format as SALUTE summary
    public var saluteSummary: String {
        """
        S: \(size)
        A: \(activity)
        L: \(location)
        U: \(unit)
        T: \(time)
        E: \(equipment)
        """
    }

    public func toJSONString() -> String? {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    public static func fromJSONString(_ json: String) -> SpotReportData? {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(SpotReportData.self, from: data) else {
            return nil
        }
        return decoded
    }
}

// MARK: - Contact Report Data

/// Contact report data for enemy engagements
public struct ContactReportData: Codable, Equatable {
    /// Type of contact (direct fire, indirect fire, IED, etc.)
    public let contactType: ContactType

    /// Location of contact
    public let location: String

    /// Time of contact
    public let timeOfContact: Int64

    /// Enemy size and composition
    public let enemySize: String

    /// Enemy activity
    public let enemyActivity: String

    /// Friendly casualties (if any)
    public let friendlyCasualties: String?

    /// Friendly actions taken
    public let friendlyActions: String

    /// Request for support
    public let supportRequest: String?

    /// Current status
    public let status: ContactStatus

    public enum ContactType: String, Codable, CaseIterable {
        case directFire = "DIRECT_FIRE"
        case indirectFire = "INDIRECT_FIRE"
        case ied = "IED"
        case ambush = "AMBUSH"
        case sniper = "SNIPER"
        case sighting = "SIGHTING"
        case other = "OTHER"

        public var displayName: String {
            switch self {
            case .directFire: return "Direct Fire"
            case .indirectFire: return "Indirect Fire"
            case .ied: return "IED/UXO"
            case .ambush: return "Ambush"
            case .sniper: return "Sniper"
            case .sighting: return "Enemy Sighting"
            case .other: return "Other"
            }
        }
    }

    public enum ContactStatus: String, Codable, CaseIterable {
        case ongoing = "ONGOING"
        case breaking = "BREAKING"
        case concluded = "CONCLUDED"

        public var displayName: String {
            switch self {
            case .ongoing: return "Ongoing"
            case .breaking: return "Breaking Contact"
            case .concluded: return "Concluded"
            }
        }
    }

    public init(
        contactType: ContactType,
        location: String,
        timeOfContact: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        enemySize: String,
        enemyActivity: String,
        friendlyCasualties: String? = nil,
        friendlyActions: String,
        supportRequest: String? = nil,
        status: ContactStatus
    ) {
        self.contactType = contactType
        self.location = location
        self.timeOfContact = timeOfContact
        self.enemySize = enemySize
        self.enemyActivity = enemyActivity
        self.friendlyCasualties = friendlyCasualties
        self.friendlyActions = friendlyActions
        self.supportRequest = supportRequest
        self.status = status
    }

    public func toJSONString() -> String? {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    public static func fromJSONString(_ json: String) -> ContactReportData? {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ContactReportData.self, from: data) else {
            return nil
        }
        return decoded
    }
}

// MARK: - Observation Note Data

/// Simple observation note attached to OP
public struct ObservationNoteData: Codable, Equatable {
    /// Note content
    public let content: String

    /// Priority level
    public let priority: Priority

    /// Time of observation
    public let observedAt: Int64

    /// Weather conditions at time of observation
    public let weatherConditions: String?

    /// Visibility conditions
    public let visibility: String?

    public enum Priority: String, Codable, CaseIterable {
        case routine = "ROUTINE"
        case priority = "PRIORITY"
        case immediate = "IMMEDIATE"
        case flash = "FLASH"

        public var displayName: String {
            rawValue.capitalized
        }
    }

    public init(
        content: String,
        priority: Priority = .routine,
        observedAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        weatherConditions: String? = nil,
        visibility: String? = nil
    ) {
        self.content = content
        self.priority = priority
        self.observedAt = observedAt
        self.weatherConditions = weatherConditions
        self.visibility = visibility
    }

    public func toJSONString() -> String? {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    public static func fromJSONString(_ json: String) -> ObservationNoteData? {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ObservationNoteData.self, from: data) else {
            return nil
        }
        return decoded
    }
}

// MARK: - LinkedForm Extensions

extension LinkedForm {
    /// Create a new form ID
    public static func generateId() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }

    /// Target coordinate if available
    public var targetCoordinate: CLLocationCoordinate2D? {
        guard let lat = targetLat, let lon = targetLon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Observer coordinate if available
    public var observerCoordinate: CLLocationCoordinate2D? {
        guard let lat = observerLat, let lon = observerLon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Submission date
    public var submittedAt: Date {
        Date(timeIntervalSince1970: Double(submittedAtMillis) / 1000.0)
    }

    /// Parse form data based on type
    public func parseFormData<T: Decodable>(as type: T.Type) -> T? {
        guard let data = formData.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
