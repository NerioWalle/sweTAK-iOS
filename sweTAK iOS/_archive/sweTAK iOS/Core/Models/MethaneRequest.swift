import Foundation
import SwiftUI

// MARK: - Methane Direction

public enum MethaneDirection: String, Codable {
    case outgoing = "OUTGOING"
    case incoming = "INCOMING"
}

// MARK: - Casualty Priority

/// Triage priority levels for casualties.
public enum CasualtyPriority: String, Codable, CaseIterable {
    case p1 = "P1"
    case p2 = "P2"
    case p3 = "P3"
    case deceased = "DECEASED"

    public var displayName: String {
        switch self {
        case .p1: return "P1 - Immediate"
        case .p2: return "P2 - Urgent"
        case .p3: return "P3 - Delayed"
        case .deceased: return "Deceased"
        }
    }

    @available(iOS 14.0, macOS 10.15, *)
    public var color: Color {
        switch self {
        case .p1: return Color(red: 0.957, green: 0.263, blue: 0.212)    // Red - life-threatening
        case .p2: return Color(red: 1.0, green: 0.757, blue: 0.027)      // Yellow - serious but stable
        case .p3: return Color(red: 0.298, green: 0.686, blue: 0.314)    // Green - minor injuries
        case .deceased: return Color(red: 0.259, green: 0.259, blue: 0.259) // Gray - dead
        }
    }
}

// MARK: - Methane ACK Type

public enum MethaneAckType: String, Codable {
    case delivered = "DELIVERED"
    case read = "READ"
}

// MARK: - Methane Request

/// METHANE emergency notification request.
///
/// M - Military details (callsign, unit)
/// E - Exact location
/// T - Time and type of incident
/// H - Hazards (present or potential)
/// A - Approach routes and landing sites
/// N - Numbers and type of casualties
/// E - Expected response (assets present and required)
public struct MethaneRequest: Codable, Identifiable, Equatable {
    public let id: String
    public let createdAtMillis: Int64
    public let senderDeviceId: String
    public let senderCallsign: String

    // M - Military details
    public let callsign: String
    public let unit: String

    // E - Exact location (coordinates as string, e.g., MGRS or lat/lon)
    public let incidentLocation: String
    public let incidentLatitude: Double?
    public let incidentLongitude: Double?

    // T - Time and type of incident
    public let incidentTime: String
    public let incidentType: String

    // H - Hazards
    public let hazards: String

    // A - Approach routes and landing sites
    public let approachRoutes: String
    public var hlsLocation: String
    public let hlsLatitude: Double?
    public let hlsLongitude: Double?

    // N - Numbers and type of casualties
    public var casualtyCountP1: Int
    public var casualtyCountP2: Int
    public var casualtyCountP3: Int
    public var casualtyCountDeceased: Int
    public var casualtyDetails: String

    // E - Expected response
    public let assetsPresent: String
    public let assetsRequired: String

    // Targeting
    public let recipientDeviceIds: [String]

    // Direction tracking
    public let direction: MethaneDirection

    // Read status
    public var isRead: Bool

    public var totalCasualties: Int {
        casualtyCountP1 + casualtyCountP2 + casualtyCountP3 + casualtyCountDeceased
    }

    public init(
        id: String = UUID().uuidString,
        createdAtMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        senderDeviceId: String,
        senderCallsign: String,
        callsign: String,
        unit: String,
        incidentLocation: String,
        incidentLatitude: Double? = nil,
        incidentLongitude: Double? = nil,
        incidentTime: String,
        incidentType: String,
        hazards: String,
        approachRoutes: String,
        hlsLocation: String = "",
        hlsLatitude: Double? = nil,
        hlsLongitude: Double? = nil,
        casualtyCountP1: Int = 0,
        casualtyCountP2: Int = 0,
        casualtyCountP3: Int = 0,
        casualtyCountDeceased: Int = 0,
        casualtyDetails: String = "",
        assetsPresent: String,
        assetsRequired: String,
        recipientDeviceIds: [String],
        direction: MethaneDirection,
        isRead: Bool = false
    ) {
        self.id = id
        self.createdAtMillis = createdAtMillis
        self.senderDeviceId = senderDeviceId
        self.senderCallsign = senderCallsign
        self.callsign = callsign
        self.unit = unit
        self.incidentLocation = incidentLocation
        self.incidentLatitude = incidentLatitude
        self.incidentLongitude = incidentLongitude
        self.incidentTime = incidentTime
        self.incidentType = incidentType
        self.hazards = hazards
        self.approachRoutes = approachRoutes
        self.hlsLocation = hlsLocation
        self.hlsLatitude = hlsLatitude
        self.hlsLongitude = hlsLongitude
        self.casualtyCountP1 = casualtyCountP1
        self.casualtyCountP2 = casualtyCountP2
        self.casualtyCountP3 = casualtyCountP3
        self.casualtyCountDeceased = casualtyCountDeceased
        self.casualtyDetails = casualtyDetails
        self.assetsPresent = assetsPresent
        self.assetsRequired = assetsRequired
        self.recipientDeviceIds = recipientDeviceIds
        self.direction = direction
        self.isRead = isRead
    }
}

// MARK: - Methane Recipient Status

public struct MethaneRecipientStatus: Codable, Identifiable, Equatable {
    public var id: String { "\(methaneId)-\(recipientDeviceId)" }

    public let methaneId: String
    public let recipientDeviceId: String
    public let recipientCallsign: String?
    public let sentAtMillis: Int64
    public var deliveredAtMillis: Int64?
    public var readAtMillis: Int64?

    public var isDelivered: Bool { deliveredAtMillis != nil }
    public var isRead: Bool { readAtMillis != nil }

    public init(
        methaneId: String,
        recipientDeviceId: String,
        recipientCallsign: String?,
        sentAtMillis: Int64,
        deliveredAtMillis: Int64? = nil,
        readAtMillis: Int64? = nil
    ) {
        self.methaneId = methaneId
        self.recipientDeviceId = recipientDeviceId
        self.recipientCallsign = recipientCallsign
        self.sentAtMillis = sentAtMillis
        self.deliveredAtMillis = deliveredAtMillis
        self.readAtMillis = readAtMillis
    }
}

// MARK: - Methane ACK

public struct MethaneAck: Codable, Equatable {
    public let methaneId: String
    public let fromDeviceId: String
    public let toDeviceId: String
    public let ackType: MethaneAckType
    public let timestampMillis: Int64

    public init(
        methaneId: String,
        fromDeviceId: String,
        toDeviceId: String,
        ackType: MethaneAckType,
        timestampMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.methaneId = methaneId
        self.fromDeviceId = fromDeviceId
        self.toDeviceId = toDeviceId
        self.ackType = ackType
        self.timestampMillis = timestampMillis
    }
}
