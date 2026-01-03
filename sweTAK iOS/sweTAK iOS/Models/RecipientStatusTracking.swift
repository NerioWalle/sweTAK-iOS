import Foundation

// MARK: - Delivery Status

/// Message delivery status (complementary to existing status types)
public enum DeliveryStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    case sent = "SENT"
    case delivered = "DELIVERED"
    case read = "READ"
    case failed = "FAILED"

    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .read: return "Read"
        case .failed: return "Failed"
        }
    }

    public var icon: String {
        switch self {
        case .pending: return "clock"
        case .sent: return "checkmark"
        case .delivered: return "checkmark.circle"
        case .read: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle"
        }
    }

    public var isCompleted: Bool {
        switch self {
        case .delivered, .read: return true
        default: return false
        }
    }
}

// MARK: - METHANE Response Type

/// Response types for METHANE emergency requests
public enum MethaneResponseType: String, Codable, CaseIterable {
    case acknowledged = "ACKNOWLEDGED"
    case enRoute = "EN_ROUTE"
    case onScene = "ON_SCENE"
    case resourcesDeployed = "RESOURCES_DEPLOYED"
    case unableToRespond = "UNABLE_TO_RESPOND"

    public var displayName: String {
        switch self {
        case .acknowledged: return "Acknowledged"
        case .enRoute: return "En Route"
        case .onScene: return "On Scene"
        case .resourcesDeployed: return "Resources Deployed"
        case .unableToRespond: return "Unable to Respond"
        }
    }
}

// MARK: - MEDEVAC Request Priority

/// MEDEVAC request priority levels (T1-T4)
/// Note: Different from MedevacPriority (P1-P3) which is for triage
public enum MedevacRequestPriority: String, Codable, CaseIterable {
    case urgent = "URGENT"
    case priority = "PRIORITY"
    case routine = "ROUTINE"
    case convenience = "CONVENIENCE"

    public var displayName: String {
        switch self {
        case .urgent: return "Urgent (T1)"
        case .priority: return "Priority (T2)"
        case .routine: return "Routine (T3)"
        case .convenience: return "Convenience (T4)"
        }
    }

    public var color: String {
        switch self {
        case .urgent: return "red"
        case .priority: return "yellow"
        case .routine: return "green"
        case .convenience: return "blue"
        }
    }
}

// MARK: - Delivery Summary

/// Summary of delivery statuses for a message
public struct DeliverySummary: Equatable {
    public let total: Int
    public let pending: Int
    public let sent: Int
    public let delivered: Int
    public let read: Int
    public let failed: Int

    public init(from statuses: [DeliveryStatus]) {
        self.total = statuses.count
        self.pending = statuses.filter { $0 == .pending }.count
        self.sent = statuses.filter { $0 == .sent }.count
        self.delivered = statuses.filter { $0 == .delivered }.count
        self.read = statuses.filter { $0 == .read }.count
        self.failed = statuses.filter { $0 == .failed }.count
    }

    /// Initialize from existing OrderRecipientStatus array
    public init(fromOrderStatuses statuses: [OrderRecipientStatus]) {
        self.total = statuses.count
        self.pending = 0
        self.sent = statuses.filter { !$0.isDelivered && !$0.isRead }.count
        self.delivered = statuses.filter { $0.isDelivered && !$0.isRead }.count
        self.read = statuses.filter { $0.isRead }.count
        self.failed = 0
    }

    /// Initialize from existing ReportRecipientStatus array
    public init(fromReportStatuses statuses: [ReportRecipientStatus]) {
        self.total = statuses.count
        self.pending = 0
        self.sent = statuses.filter { !$0.isDelivered && !$0.isRead }.count
        self.delivered = statuses.filter { $0.isDelivered && !$0.isRead }.count
        self.read = statuses.filter { $0.isRead }.count
        self.failed = 0
    }

    /// Whether all recipients have received the message
    public var isFullyDelivered: Bool {
        delivered + read == total && failed == 0
    }

    /// Whether all recipients have read the message
    public var isFullyRead: Bool {
        read == total
    }

    /// Formatted summary string
    public var summaryText: String {
        if total == 0 {
            return "No recipients"
        }

        if isFullyRead {
            return "Read by all (\(total))"
        } else if isFullyDelivered {
            return "Delivered to all (\(total))"
        } else if failed > 0 {
            return "Failed: \(failed)/\(total)"
        } else {
            return "Sent: \(sent + delivered + read)/\(total)"
        }
    }
}

// MARK: - Status Tracking Utilities

/// Utilities for working with recipient statuses
public enum StatusTrackingUtils {

    /// Get delivery status from existing OrderRecipientStatus
    public static func getDeliveryStatus(from status: OrderRecipientStatus) -> DeliveryStatus {
        if status.isRead {
            return .read
        } else if status.isDelivered {
            return .delivered
        } else {
            return .sent
        }
    }

    /// Get delivery status from existing ReportRecipientStatus
    public static func getDeliveryStatus(from status: ReportRecipientStatus) -> DeliveryStatus {
        if status.isRead {
            return .read
        } else if status.isDelivered {
            return .delivered
        } else {
            return .sent
        }
    }

    /// Get delivery status from existing MethaneRecipientStatus
    public static func getDeliveryStatus(from status: MethaneRecipientStatus) -> DeliveryStatus {
        if status.isRead {
            return .read
        } else if status.isDelivered {
            return .delivered
        } else {
            return .sent
        }
    }

    /// Get delivery status from existing MedevacRecipientStatus
    public static func getDeliveryStatus(from status: MedevacRecipientStatus) -> DeliveryStatus {
        if status.isRead {
            return .read
        } else if status.isDelivered {
            return .delivered
        } else {
            return .sent
        }
    }

    /// Format timestamp as relative time
    public static func formatTimestamp(_ millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(millis) / 1000.0)
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Extensions for Existing Types

extension OrderRecipientStatus {
    /// Get the delivery status enum value
    public var deliveryStatus: DeliveryStatus {
        StatusTrackingUtils.getDeliveryStatus(from: self)
    }

    /// Formatted sent time
    public var formattedSentTime: String {
        StatusTrackingUtils.formatTimestamp(sentAtMillis)
    }

    /// Formatted delivered time
    public var formattedDeliveredTime: String? {
        guard let millis = deliveredAtMillis else { return nil }
        return StatusTrackingUtils.formatTimestamp(millis)
    }

    /// Formatted read time
    public var formattedReadTime: String? {
        guard let millis = readAtMillis else { return nil }
        return StatusTrackingUtils.formatTimestamp(millis)
    }
}

extension ReportRecipientStatus {
    /// Get the delivery status enum value
    public var deliveryStatus: DeliveryStatus {
        StatusTrackingUtils.getDeliveryStatus(from: self)
    }

    /// Formatted sent time
    public var formattedSentTime: String {
        StatusTrackingUtils.formatTimestamp(sentAtMillis)
    }
}

extension MethaneRecipientStatus {
    /// Get the delivery status enum value
    public var deliveryStatus: DeliveryStatus {
        StatusTrackingUtils.getDeliveryStatus(from: self)
    }

    /// Formatted sent time
    public var formattedSentTime: String {
        StatusTrackingUtils.formatTimestamp(sentAtMillis)
    }
}

extension MedevacRecipientStatus {
    /// Get the delivery status enum value
    public var deliveryStatus: DeliveryStatus {
        StatusTrackingUtils.getDeliveryStatus(from: self)
    }

    /// Formatted sent time
    public var formattedSentTime: String {
        StatusTrackingUtils.formatTimestamp(sentAtMillis)
    }
}
