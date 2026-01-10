import Foundation
import SwiftUI

// MARK: - String Extensions

extension String {
    /// Check if string is blank (empty or only whitespace)
    public var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Return nil if blank, otherwise return the trimmed string
    public var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Truncate string to max length with ellipsis
    public func truncated(to maxLength: Int, trailing: String = "...") -> String {
        guard count > maxLength else { return self }
        return String(prefix(maxLength - trailing.count)) + trailing
    }
}

// MARK: - Optional String Extensions

extension Optional where Wrapped == String {
    /// Return empty string if nil, otherwise return the value
    public var orEmpty: String {
        self ?? ""
    }

    /// Check if optional string is nil or blank
    public var isNilOrBlank: Bool {
        self?.isBlank ?? true
    }
}

// MARK: - Data Extensions

extension Data {
    /// Convert to hex string
    public var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }

    /// Initialize from hex string
    public init?(hexString: String) {
        let hex = hexString.dropFirst(hexString.hasPrefix("0x") ? 2 : 0)
        guard hex.count % 2 == 0 else { return nil }

        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex

        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }

        self = data
    }
}

// MARK: - Color Extensions

extension Color {
    /// Initialize from hex value (e.g., 0xFF4CAF50)
    public init(hex: UInt64, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }

    /// Initialize from hex string (e.g., "#4CAF50" or "4CAF50")
    public init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        hex = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex

        guard hex.count == 6, let value = UInt64(hex, radix: 16) else {
            return nil
        }

        self.init(hex: value)
    }

    // Predefined tactical colors
    public static let tacticalRed = Color(hex: 0xF44336)
    public static let tacticalYellow = Color(hex: 0xFFC107)
    public static let tacticalGreen = Color(hex: 0x4CAF50)
    public static let tacticalBlue = Color(hex: 0x2196F3)
    public static let tacticalGray = Color(hex: 0x9E9E9E)
}

// MARK: - Array Extensions

extension Array {
    /// Safe subscript that returns nil for out-of-bounds indices
    public subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Array where Element: Identifiable {
    /// Find index of element by ID
    public func firstIndex(withId id: Element.ID) -> Index? {
        firstIndex { $0.id == id }
    }

    /// Remove element by ID
    public mutating func removeFirst(withId id: Element.ID) {
        if let index = firstIndex(withId: id) {
            remove(at: index)
        }
    }
}

// MARK: - Dictionary Extensions

extension Dictionary where Key == String, Value == Any {
    /// Safe string value extraction
    public func string(_ key: String) -> String? {
        self[key] as? String
    }

    /// Safe int value extraction
    public func int(_ key: String) -> Int? {
        self[key] as? Int
    }

    /// Safe int64 value extraction
    public func int64(_ key: String) -> Int64? {
        if let value = self[key] as? Int64 {
            return value
        }
        if let value = self[key] as? Int {
            return Int64(value)
        }
        return nil
    }

    /// Safe double value extraction
    public func double(_ key: String) -> Double? {
        self[key] as? Double
    }

    /// Safe bool value extraction
    public func bool(_ key: String) -> Bool? {
        self[key] as? Bool
    }

    /// Safe array value extraction
    public func array(_ key: String) -> [Any]? {
        self[key] as? [Any]
    }

    /// Safe dictionary value extraction
    public func dictionary(_ key: String) -> [String: Any]? {
        self[key] as? [String: Any]
    }
}

// MARK: - View Extensions

extension View {
    /// Apply modifier conditionally
    @ViewBuilder
    public func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Hide view conditionally
    @ViewBuilder
    public func hidden(_ shouldHide: Bool) -> some View {
        if shouldHide {
            hidden()
        } else {
            self
        }
    }
}

// MARK: - Date Extensions

extension Date {
    /// Current time in milliseconds since 1970
    public static var currentMillis: Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    /// Initialize from milliseconds since 1970
    public init(millis: Int64) {
        self.init(timeIntervalSince1970: Double(millis) / 1000.0)
    }

    /// Convert to milliseconds since 1970
    public var toMillis: Int64 {
        Int64(timeIntervalSince1970 * 1000)
    }

    /// Format as relative time string (e.g., "5 minutes ago")
    public var relativeString: String {
        let interval = Date().timeIntervalSince(self)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Publisher Extensions

import Combine

extension Publisher {
    /// Receive on main thread
    public func receiveOnMain() -> Publishers.ReceiveOn<Self, DispatchQueue> {
        receive(on: DispatchQueue.main)
    }
}
