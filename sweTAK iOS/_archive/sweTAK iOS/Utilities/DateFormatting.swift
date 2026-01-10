import Foundation

// MARK: - Date Formatting Extensions

extension Date {
    /// Format as military time (DDHHMM)
    public var militaryFormat: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ddHHmm"
        return formatter.string(from: self)
    }

    /// Format as ISO 8601
    public var iso8601: String {
        ISO8601DateFormatter().string(from: self)
    }

    /// Format as relative time (e.g., "5 min ago")
    public var relativeFormat: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Format as short time (HH:mm)
    public var shortTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }

    /// Format as short date (dd/MM)
    public var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: self)
    }

    /// Format as full date and time
    public var fullDateTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    /// Initialize from milliseconds timestamp
    public init(milliseconds: Int64) {
        self.init(timeIntervalSince1970: Double(milliseconds) / 1000.0)
    }

    // currentMillis is defined in Extensions.swift

    /// Get milliseconds since epoch
    public var millisecondsSince1970: Int64 {
        Int64(timeIntervalSince1970 * 1000)
    }
}

// MARK: - Int64 Timestamp Extensions

extension Int64 {
    /// Convert milliseconds timestamp to Date
    public var toDate: Date {
        Date(milliseconds: self)
    }

    /// Format milliseconds timestamp as relative time
    public var relativeFormat: String {
        toDate.relativeFormat
    }

    /// Format milliseconds timestamp as short time
    public var shortTime: String {
        toDate.shortTime
    }

    /// Format milliseconds timestamp as full date and time
    public var fullDateTime: String {
        toDate.fullDateTime
    }
}
