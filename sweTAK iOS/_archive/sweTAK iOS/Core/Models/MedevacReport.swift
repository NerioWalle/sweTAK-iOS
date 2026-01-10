import Foundation
import SwiftUI

// MARK: - Medevac Direction

public enum MedevacDirection: String, Codable {
    case outgoing = "OUTGOING"
    case incoming = "INCOMING"
}

// MARK: - Medevac Priority

/// Triage priority levels for MEDEVAC casualties.
public enum MedevacPriority: String, Codable, CaseIterable {
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

// MARK: - Medevac ACK Type

public enum MedevacAckType: String, Codable {
    case delivered = "DELIVERED"
    case read = "READ"
}

// MARK: - Medevac Report

/// MEDEVAC handover report for injured soldier handover.
///
/// Used when handing over an injured soldier to MEDEVAC personnel.
/// Contains essential medical and identification information.
public struct MedevacReport: Codable, Identifiable, Equatable {
    public let id: String
    public let createdAtMillis: Int64
    public let senderDeviceId: String
    public let senderCallsign: String

    // Patient identification
    public let soldierName: String
    public let priority: MedevacPriority
    public let ageInfo: String              // Child/Adult or known/approximate age

    // Incident timing
    public let incidentTime: String         // DDHHMM format

    // Mechanism of injury
    public let mechanismOfInjury: String    // What caused the injury (shrapnel, gunshot wound, etc.)

    // Injury details
    public let injuryDescription: String    // Discovered or suspected injuries

    // Signs and symptoms
    public let signsSymptoms: String        // bleeding, breathing difficulty, etc.

    // Vital parameters
    public var pulse: String
    public var bodyTemperature: String

    // Treatment
    public var treatmentActions: String     // What actions have been taken
    public var medicinesGiven: String       // Any medicines administered

    // Care-taker
    public let caretakerName: String        // Who has been taking care of the soldier

    // Targeting
    public let recipientDeviceIds: [String]

    // Direction tracking
    public let direction: MedevacDirection

    // Read status
    public var isRead: Bool

    public init(
        id: String = UUID().uuidString,
        createdAtMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        senderDeviceId: String,
        senderCallsign: String,
        soldierName: String,
        priority: MedevacPriority,
        ageInfo: String,
        incidentTime: String,
        mechanismOfInjury: String,
        injuryDescription: String,
        signsSymptoms: String,
        pulse: String = "",
        bodyTemperature: String = "",
        treatmentActions: String = "",
        medicinesGiven: String = "",
        caretakerName: String,
        recipientDeviceIds: [String],
        direction: MedevacDirection,
        isRead: Bool = false
    ) {
        self.id = id
        self.createdAtMillis = createdAtMillis
        self.senderDeviceId = senderDeviceId
        self.senderCallsign = senderCallsign
        self.soldierName = soldierName
        self.priority = priority
        self.ageInfo = ageInfo
        self.incidentTime = incidentTime
        self.mechanismOfInjury = mechanismOfInjury
        self.injuryDescription = injuryDescription
        self.signsSymptoms = signsSymptoms
        self.pulse = pulse
        self.bodyTemperature = bodyTemperature
        self.treatmentActions = treatmentActions
        self.medicinesGiven = medicinesGiven
        self.caretakerName = caretakerName
        self.recipientDeviceIds = recipientDeviceIds
        self.direction = direction
        self.isRead = isRead
    }
}

// MARK: - Medevac Recipient Status

public struct MedevacRecipientStatus: Codable, Identifiable, Equatable {
    public var id: String { "\(medevacId)-\(recipientDeviceId)" }

    public let medevacId: String
    public let recipientDeviceId: String
    public let recipientCallsign: String?
    public let sentAtMillis: Int64
    public var deliveredAtMillis: Int64?
    public var readAtMillis: Int64?

    public var isDelivered: Bool { deliveredAtMillis != nil }
    public var isRead: Bool { readAtMillis != nil }

    public init(
        medevacId: String,
        recipientDeviceId: String,
        recipientCallsign: String?,
        sentAtMillis: Int64,
        deliveredAtMillis: Int64? = nil,
        readAtMillis: Int64? = nil
    ) {
        self.medevacId = medevacId
        self.recipientDeviceId = recipientDeviceId
        self.recipientCallsign = recipientCallsign
        self.sentAtMillis = sentAtMillis
        self.deliveredAtMillis = deliveredAtMillis
        self.readAtMillis = readAtMillis
    }
}

// MARK: - Medevac ACK

public struct MedevacAck: Codable, Equatable {
    public let medevacId: String
    public let fromDeviceId: String
    public let toDeviceId: String
    public let ackType: MedevacAckType
    public let timestampMillis: Int64

    public init(
        medevacId: String,
        fromDeviceId: String,
        toDeviceId: String,
        ackType: MedevacAckType,
        timestampMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.medevacId = medevacId
        self.fromDeviceId = fromDeviceId
        self.toDeviceId = toDeviceId
        self.ackType = ackType
        self.timestampMillis = timestampMillis
    }
}
