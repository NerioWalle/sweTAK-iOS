import Foundation
import CoreLocation

// MARK: - NATO Pin Type

/// APP-6-inspired pin types
public enum NatoType: String, Codable, CaseIterable {
    case infantry = "INFANTRY"
    case intelligence = "INTELLIGENCE"
    case surveillance = "SURVEILLANCE"
    case artillery = "ARTILLERY"
    case marine = "MARINE"
    case droneObserved = "DRONE_OBSERVED"
    case op = "OP"
    case photo = "PHOTO"
    case form7S = "FORM_7S"
    case formIFS = "FORM_IFS"

    public var label: String {
        switch self {
        case .infantry: return "Infantry"
        case .intelligence: return "Intelligence"
        case .surveillance: return "Surveillance"
        case .artillery: return "Artillery"
        case .marine: return "Marine"
        case .droneObserved: return "Drone observed"
        case .op: return "Observation Post"
        case .photo: return "Photo"
        case .form7S: return "7S"
        case .formIFS: return "IFS"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .infantry: return "flag.fill"
        case .intelligence: return "eye.fill"
        case .surveillance: return "sensor.fill"
        case .artillery: return "shield.lefthalf.filled"
        case .marine: return "anchor"
        case .droneObserved: return "airplane"
        case .op: return "tent.fill"
        case .photo: return "camera.fill"
        case .form7S: return "doc.fill"
        case .formIFS: return "scope"
        }
    }

    /// Tolerant parser for inbound/legacy type strings
    public static func parse(_ raw: String?) -> NatoType {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces).uppercased() else {
            return .infantry
        }
        switch raw {
        case "INFANTRY": return .infantry
        case "INTELLIGENCE": return .intelligence
        case "SURVEILLANCE": return .surveillance
        case "ARTILLERY": return .artillery
        case "MARINE": return .marine
        case "DRONE_OBSERVED", "DRONE", "UAV": return .droneObserved
        case "OP", "OBSERVATION_POST": return .op
        case "PHOTO", "CAMERA": return .photo
        case "FORM_7S", "7S": return .form7S
        case "FORM_IFS", "IFS": return .formIFS
        default: return .infantry
        }
    }
}

// MARK: - NATO Pin

/// Tactical pin with coordinates, NATO type, and metadata
public struct NatoPin: Codable, Identifiable, Equatable {
    public let id: Int64
    public let latitude: Double
    public let longitude: Double
    public let type: NatoType
    public let title: String
    public var description: String
    public var authorCallsign: String
    public let createdAtMillis: Int64
    public var originDeviceId: String
    public var photoUri: String?  // URI to attached photo for PHOTO type pins

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public init(
        id: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        latitude: Double,
        longitude: Double,
        type: NatoType,
        title: String,
        description: String = "",
        authorCallsign: String = "",
        createdAtMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        originDeviceId: String = "",
        photoUri: String? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.type = type
        self.title = title
        self.description = description
        self.authorCallsign = authorCallsign
        self.createdAtMillis = createdAtMillis
        self.originDeviceId = originDeviceId
        self.photoUri = photoUri
    }

    /// Convert to JSON dictionary for network transmission
    public func toJSON() -> [String: Any] {
        var json: [String: Any] = [
            "id": id,
            "lat": latitude,
            "lon": longitude,
            "type": type.rawValue,
            "title": title,
            "description": description,
            "authorCallsign": authorCallsign,
            "createdAtMillis": createdAtMillis,
            "originDeviceId": originDeviceId
        ]
        if let photoUri = photoUri {
            json["photoUri"] = photoUri
        }
        return json
    }

    /// Parse from JSON dictionary
    public static func fromJSON(_ json: [String: Any]) -> NatoPin? {
        guard let id = json["id"] as? Int64 ?? (json["id"] as? Int).map({ Int64($0) }),
              let lat = json["lat"] as? Double,
              let lon = json["lon"] as? Double,
              let title = json["title"] as? String else {
            return nil
        }

        return NatoPin(
            id: id,
            latitude: lat,
            longitude: lon,
            type: NatoType.parse(json["type"] as? String),
            title: title,
            description: json["description"] as? String ?? "",
            authorCallsign: json["authorCallsign"] as? String ?? "",
            createdAtMillis: json["createdAtMillis"] as? Int64 ?? Int64(Date().timeIntervalSince1970 * 1000),
            originDeviceId: json["originDeviceId"] as? String ?? "",
            photoUri: json["photoUri"] as? String
        )
    }
}

// MARK: - Linked Form

/// Form submissions linked to OP pins (not shown as separate map pins)
public struct LinkedForm: Codable, Identifiable, Equatable {
    public let id: Int64
    public let opPinId: Int64
    public let opOriginDeviceId: String
    public let formType: String
    public let formData: String
    public let submittedAtMillis: Int64
    public let authorCallsign: String
    // Raw coordinates for display formatting (viewer's coord preference)
    public let targetLat: Double?
    public let targetLon: Double?
    public let observerLat: Double?
    public let observerLon: Double?

    public init(
        id: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        opPinId: Int64,
        opOriginDeviceId: String,
        formType: String,
        formData: String,
        submittedAtMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        authorCallsign: String,
        targetLat: Double? = nil,
        targetLon: Double? = nil,
        observerLat: Double? = nil,
        observerLon: Double? = nil
    ) {
        self.id = id
        self.opPinId = opPinId
        self.opOriginDeviceId = opOriginDeviceId
        self.formType = formType
        self.formData = formData
        self.submittedAtMillis = submittedAtMillis
        self.authorCallsign = authorCallsign
        self.targetLat = targetLat
        self.targetLon = targetLon
        self.observerLat = observerLat
        self.observerLon = observerLon
    }
}
