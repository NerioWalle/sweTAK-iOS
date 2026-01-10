import Foundation
import SwiftUI

// MARK: - Report Direction

public enum ReportDirection: String, Codable {
    case outgoing = "OUTGOING"
    case incoming = "INCOMING"
}

// MARK: - Readiness Level

/// Readiness grading levels for PEDARS reports.
public enum ReadinessLevel: String, Codable, CaseIterable {
    case green = "GREEN"
    case yellow = "YELLOW"
    case red = "RED"

    public var displayName: String {
        switch self {
        case .green: return "Green - No limitations"
        case .yellow: return "Yellow - With limitations"
        case .red: return "Red - Cannot solve missions"
        }
    }

    @available(iOS 14.0, macOS 10.15, *)
    public var color: Color {
        switch self {
        case .green: return Color(red: 0.298, green: 0.686, blue: 0.314)  // 0xFF4CAF50
        case .yellow: return Color(red: 1.0, green: 0.757, blue: 0.027)   // 0xFFFFC107
        case .red: return Color(red: 0.957, green: 0.263, blue: 0.212)    // 0xFFF44336
        }
    }
}

// MARK: - Report ACK Type

public enum ReportAckType: String, Codable {
    case delivered = "DELIVERED"
    case read = "READ"
}

// MARK: - Report

/// PEDARS status report data model.
///
/// PEDARS is a 24-hour mission status report covering:
/// - Personnel status (wounded, dead, capable)
/// - Replenishment needs
/// - Fuel needs
/// - Ammunition needs
/// - Equipment needs
/// - Readiness grading with details for Yellow/Red status
public struct Report: Codable, Identifiable, Equatable {
    public let id: String
    public let createdAtMillis: Int64
    public let senderDeviceId: String
    public let senderCallsign: String

    // Personnel status
    public let woundedCount: Int
    public let deadCount: Int
    public let capableCount: Int

    // Needs fields
    public let replenishment: String
    public let fuel: String
    public let ammunition: String
    public let equipment: String

    // Readiness
    public let readiness: ReadinessLevel
    public var readinessDetails: String  // For Yellow/Red explanations

    // Targeting
    public let recipientDeviceIds: [String]

    // Direction tracking
    public let direction: ReportDirection

    // Read status for incoming reports
    public var isRead: Bool

    public init(
        id: String = UUID().uuidString,
        createdAtMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        senderDeviceId: String,
        senderCallsign: String,
        woundedCount: Int,
        deadCount: Int,
        capableCount: Int,
        replenishment: String,
        fuel: String,
        ammunition: String,
        equipment: String,
        readiness: ReadinessLevel,
        readinessDetails: String = "",
        recipientDeviceIds: [String],
        direction: ReportDirection,
        isRead: Bool = false
    ) {
        self.id = id
        self.createdAtMillis = createdAtMillis
        self.senderDeviceId = senderDeviceId
        self.senderCallsign = senderCallsign
        self.woundedCount = woundedCount
        self.deadCount = deadCount
        self.capableCount = capableCount
        self.replenishment = replenishment
        self.fuel = fuel
        self.ammunition = ammunition
        self.equipment = equipment
        self.readiness = readiness
        self.readinessDetails = readinessDetails
        self.recipientDeviceIds = recipientDeviceIds
        self.direction = direction
        self.isRead = isRead
    }
}

// MARK: - Report Recipient Status

public struct ReportRecipientStatus: Codable, Identifiable, Equatable {
    public var id: String { "\(reportId)-\(recipientDeviceId)" }

    public let reportId: String
    public let recipientDeviceId: String
    public let recipientCallsign: String?
    public let sentAtMillis: Int64
    public var deliveredAtMillis: Int64?
    public var readAtMillis: Int64?

    public var isDelivered: Bool { deliveredAtMillis != nil }
    public var isRead: Bool { readAtMillis != nil }

    public init(
        reportId: String,
        recipientDeviceId: String,
        recipientCallsign: String?,
        sentAtMillis: Int64,
        deliveredAtMillis: Int64? = nil,
        readAtMillis: Int64? = nil
    ) {
        self.reportId = reportId
        self.recipientDeviceId = recipientDeviceId
        self.recipientCallsign = recipientCallsign
        self.sentAtMillis = sentAtMillis
        self.deliveredAtMillis = deliveredAtMillis
        self.readAtMillis = readAtMillis
    }
}

// MARK: - Report ACK

public struct ReportAck: Codable, Equatable {
    public let reportId: String
    public let fromDeviceId: String
    public let toDeviceId: String
    public let ackType: ReportAckType
    public let timestampMillis: Int64

    public init(
        reportId: String,
        fromDeviceId: String,
        toDeviceId: String,
        ackType: ReportAckType,
        timestampMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.reportId = reportId
        self.fromDeviceId = fromDeviceId
        self.toDeviceId = toDeviceId
        self.ackType = ackType
        self.timestampMillis = timestampMillis
    }
}
