import Foundation

// MARK: - Military Role

/// Military roles for command hierarchy
public enum MilitaryRole: String, Codable, CaseIterable {
    case none = "NONE"
    case companyCommander = "COMPANY_COMMANDER"
    case assistantCompanyCommander = "ASSISTANT_COMPANY_COMMANDER"
    case troopLeader = "TROOP_LEADER"
    case assistantTroopLeader = "ASSISTANT_TROOP_LEADER"
    case platoonLeader = "PLATOON_LEADER"
    case assistantPlatoonLeader = "ASSISTANT_PLATOON_LEADER"
    case squadLeader = "SQUAD_LEADER"
    case assistantSquadLeader = "ASSISTANT_SQUAD_LEADER"
    case staffMember = "STAFF_MEMBER"
    case soldier = "SOLDIER"
    case other = "OTHER"

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .companyCommander: return "Company Commander"
        case .assistantCompanyCommander: return "Assistant Company Commander"
        case .troopLeader: return "Troop Leader"
        case .assistantTroopLeader: return "Assistant Troop Leader"
        case .platoonLeader: return "Platoon Leader"
        case .assistantPlatoonLeader: return "Assistant Platoon Leader"
        case .squadLeader: return "Squad Leader"
        case .assistantSquadLeader: return "Assistant Squad Leader"
        case .staffMember: return "Staff Member"
        case .soldier: return "Soldier"
        case .other: return "Other"
        }
    }

    public var abbreviation: String {
        switch self {
        case .none: return ""
        case .companyCommander: return "CC"
        case .assistantCompanyCommander: return "ACC"
        case .troopLeader: return "TL"
        case .assistantTroopLeader: return "ATL"
        case .platoonLeader: return "PL"
        case .assistantPlatoonLeader: return "APL"
        case .squadLeader: return "SL"
        case .assistantSquadLeader: return "ASL"
        case .staffMember: return "Staff"
        case .soldier: return "Soldier"
        case .other: return "Other"
        }
    }

    public static func from(_ value: String?) -> MilitaryRole {
        guard let value = value, !value.isEmpty else { return .none }
        return MilitaryRole.allCases.first {
            $0.rawValue.caseInsensitiveCompare(value) == .orderedSame ||
            $0.displayName.caseInsensitiveCompare(value) == .orderedSame ||
            $0.abbreviation.caseInsensitiveCompare(value) == .orderedSame
        } ?? .none
    }
}

// MARK: - Contact Profile

/// Contact/peer profile information
public struct ContactProfile: Codable, Identifiable, Equatable {
    public var id: String { deviceId }

    public let deviceId: String
    public var nickname: String?
    public var callsign: String?
    public var firstName: String?
    public var lastName: String?
    public var company: String?
    public var platoon: String?
    public var squad: String?
    public var mobile: String?
    public var email: String?
    public var photoUri: String?
    public var role: MilitaryRole
    public var lastSeenMs: Int64
    public var fromIp: String?  // Network origin (for UDP peers)

    public init(
        deviceId: String,
        nickname: String? = nil,
        callsign: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        company: String? = nil,
        platoon: String? = nil,
        squad: String? = nil,
        mobile: String? = nil,
        email: String? = nil,
        photoUri: String? = nil,
        role: MilitaryRole = .none,
        lastSeenMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        fromIp: String? = nil
    ) {
        self.deviceId = deviceId
        self.nickname = nickname
        self.callsign = callsign
        self.firstName = firstName
        self.lastName = lastName
        self.company = company
        self.platoon = platoon
        self.squad = squad
        self.mobile = mobile
        self.email = email
        self.photoUri = photoUri
        self.role = role
        self.lastSeenMs = lastSeenMs
        self.fromIp = fromIp
    }

    /// Parse a ContactProfile from incoming JSON (network or MQTT)
    public static func fromJSON(_ json: [String: Any], deviceId: String, fromIp: String? = nil) -> ContactProfile {
        let rawCallsign = json["callsign"] as? String ?? ""
        let callsign = rawCallsign.isEmpty || rawCallsign == "Unknown" ? nil : rawCallsign

        let nick = json["nick"] as? String ?? ""
        let nickname = nick.isEmpty ? (json["nickname"] as? String).flatMap { $0.isEmpty ? nil : $0 } : nick

        return ContactProfile(
            deviceId: deviceId,
            nickname: nickname,
            callsign: callsign,
            firstName: (json["first"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            lastName: (json["last"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            company: (json["company"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            platoon: (json["platoon"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            squad: (json["squad"] as? String ?? json["team"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            mobile: (json["mobile"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            email: (json["email"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            photoUri: (json["photoUri"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            role: MilitaryRole.from(json["role"] as? String),
            lastSeenMs: Int64(Date().timeIntervalSince1970 * 1000),
            fromIp: fromIp
        )
    }

    /// Convert to JSON dictionary for network transmission
    /// Field names match Android protocol expectations
    public func toJSON() -> [String: Any] {
        var json: [String: Any] = [
            "deviceId": deviceId
        ]
        if let callsign = callsign { json["callsign"] = callsign }
        if let nickname = nickname { json["nickname"] = nickname }
        if let firstName = firstName { json["firstName"] = firstName }
        if let lastName = lastName { json["lastName"] = lastName }
        if let company = company { json["company"] = company }
        if let platoon = platoon { json["platoon"] = platoon }
        if let squad = squad { json["squad"] = squad }
        if let mobile = mobile { json["phone"] = mobile }
        if let email = email { json["email"] = email }
        if let photoUri = photoUri { json["photoUri"] = photoUri }
        if role != .none { json["role"] = role.rawValue }
        return json
    }

    // MARK: - Computed Properties

    /// Last seen as Date
    public var lastSeenAt: Date? {
        lastSeenMs > 0 ? Date(timeIntervalSince1970: Double(lastSeenMs) / 1000.0) : nil
    }

    /// Display name (callsign or nickname or deviceId)
    public var displayName: String {
        callsign ?? nickname ?? deviceId
    }

    /// Full name (first + last)
    public var fullName: String? {
        let parts = [firstName, lastName].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// Is this contact online (seen within last 5 minutes)
    public var isOnline: Bool {
        guard let lastSeen = lastSeenAt else { return false }
        return Date().timeIntervalSince(lastSeen) < 300
    }
}

// MARK: - Local Profile

/// Local user profile stored on device
public struct LocalProfile: Codable, Equatable {
    public var callsign: String
    public var nickname: String
    public var firstName: String
    public var lastName: String
    public var company: String
    public var platoon: String
    public var squad: String
    public var phone: String
    public var email: String
    public var role: MilitaryRole

    public init(
        callsign: String = "",
        nickname: String = "",
        firstName: String = "",
        lastName: String = "",
        company: String = "",
        platoon: String = "",
        squad: String = "",
        phone: String = "",
        email: String = "",
        role: MilitaryRole = .none
    ) {
        self.callsign = callsign
        self.nickname = nickname
        self.firstName = firstName
        self.lastName = lastName
        self.company = company
        self.platoon = platoon
        self.squad = squad
        self.phone = phone
        self.email = email
        self.role = role
    }
}

// MARK: - Friend (LAN Peer)

/// LAN peer information
public struct Friend: Codable, Identifiable, Equatable {
    public var id: String { deviceId }

    public let deviceId: String
    public let host: String
    public let port: Int
    public var callsign: String
    public var approved: Bool  // All devices approved by default
    public var lastLat: Double?
    public var lastLon: Double?

    public init(
        deviceId: String,
        host: String,
        port: Int,
        callsign: String = "",
        approved: Bool = true,
        lastLat: Double? = nil,
        lastLon: Double? = nil
    ) {
        self.deviceId = deviceId
        self.host = host
        self.port = port
        self.callsign = callsign
        self.approved = approved
        self.lastLat = lastLat
        self.lastLon = lastLon
    }
}

// MARK: - Remote Marker

/// Remote marker for map display
public struct RemoteMarker: Codable, Identifiable, Equatable {
    public var id: String { deviceId }

    public let deviceId: String
    public let callsign: String
    public let nickname: String?
    public let lat: Double
    public let lon: Double

    public init(
        deviceId: String,
        callsign: String,
        nickname: String?,
        lat: Double,
        lon: Double
    ) {
        self.deviceId = deviceId
        self.callsign = callsign
        self.nickname = nickname
        self.lat = lat
        self.lon = lon
    }
}
