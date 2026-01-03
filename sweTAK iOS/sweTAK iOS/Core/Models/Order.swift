import Foundation

// MARK: - Order Type

/// Order format types.
/// - OBO: 3-field format (Orientation, Decision, Order)
/// - fiveP: 5-field format (Orientation, Mission, Execution, Logistics, Command)
public enum OrderType: String, Codable, CaseIterable {
    case obo = "OBO"
    case fiveP = "FIVE_P"

    public var displayName: String {
        switch self {
        case .obo: return "OBO"
        case .fiveP: return "5P"
        }
    }

    public var fieldCount: Int {
        switch self {
        case .obo: return 3
        case .fiveP: return 5
        }
    }
}

// MARK: - Order Direction

public enum OrderDirection: String, Codable {
    case outgoing = "OUTGOING"
    case incoming = "INCOMING"
}

// MARK: - Order ACK Type

/// ACK types for orders:
/// - delivered: Device received the order (automatic)
/// - read: User opened/viewed the order (explicit action)
public enum OrderAckType: String, Codable {
    case delivered = "DELIVERED"
    case read = "READ"
}

// MARK: - Order

/// Represents a military order (OBO or 5P format).
///
/// OBO fields: orientation, decision, order
/// 5P fields: orientation, mission, execution, logistics, commandSignaling
public struct Order: Codable, Identifiable, Equatable {
    public let id: String
    public let type: OrderType
    public let createdAtMillis: Int64
    public let senderDeviceId: String
    public let senderCallsign: String

    // Orientation/Background - used by both formats
    public let orientation: String

    // OBO-specific fields
    public var decision: String
    public var order: String

    // 5P-specific fields
    public var mission: String
    public var execution: String
    public var logistics: String
    public var commandSignaling: String

    // Targeting
    public let recipientDeviceIds: [String]

    // Direction tracking
    public let direction: OrderDirection

    // Read status for incoming orders
    public var isRead: Bool

    public init(
        id: String = UUID().uuidString,
        type: OrderType,
        createdAtMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        senderDeviceId: String,
        senderCallsign: String,
        orientation: String,
        decision: String = "",
        order: String = "",
        mission: String = "",
        execution: String = "",
        logistics: String = "",
        commandSignaling: String = "",
        recipientDeviceIds: [String],
        direction: OrderDirection,
        isRead: Bool = false
    ) {
        self.id = id
        self.type = type
        self.createdAtMillis = createdAtMillis
        self.senderDeviceId = senderDeviceId
        self.senderCallsign = senderCallsign
        self.orientation = orientation
        self.decision = decision
        self.order = order
        self.mission = mission
        self.execution = execution
        self.logistics = logistics
        self.commandSignaling = commandSignaling
        self.recipientDeviceIds = recipientDeviceIds
        self.direction = direction
        self.isRead = isRead
    }
}

// MARK: - Order Recipient Status

/// Tracks ACK/read status for each recipient of an order.
public struct OrderRecipientStatus: Codable, Identifiable, Equatable {
    public var id: String { "\(orderId)-\(recipientDeviceId)" }

    public let orderId: String
    public let recipientDeviceId: String
    public let recipientCallsign: String?
    public let sentAtMillis: Int64
    public var deliveredAtMillis: Int64?
    public var readAtMillis: Int64?

    public var isDelivered: Bool { deliveredAtMillis != nil }
    public var isRead: Bool { readAtMillis != nil }

    public init(
        orderId: String,
        recipientDeviceId: String,
        recipientCallsign: String?,
        sentAtMillis: Int64,
        deliveredAtMillis: Int64? = nil,
        readAtMillis: Int64? = nil
    ) {
        self.orderId = orderId
        self.recipientDeviceId = recipientDeviceId
        self.recipientCallsign = recipientCallsign
        self.sentAtMillis = sentAtMillis
        self.deliveredAtMillis = deliveredAtMillis
        self.readAtMillis = readAtMillis
    }
}

// MARK: - Order ACK

/// Acknowledgment event for an order.
public struct OrderAck: Codable, Equatable {
    public let orderId: String
    public let fromDeviceId: String
    public let toDeviceId: String
    public let ackType: OrderAckType
    public let timestampMillis: Int64

    public init(
        orderId: String,
        fromDeviceId: String,
        toDeviceId: String,
        ackType: OrderAckType,
        timestampMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.orderId = orderId
        self.fromDeviceId = fromDeviceId
        self.toDeviceId = toDeviceId
        self.ackType = ackType
        self.timestampMillis = timestampMillis
    }
}
