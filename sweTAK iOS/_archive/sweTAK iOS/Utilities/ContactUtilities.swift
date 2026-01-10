import Foundation

// MARK: - Contact Utilities

/// Utility functions for contact/profile management
public enum ContactUtilities {

    // MARK: - Profile Merging

    /// Merges two profiles, preferring non-empty values from the first profile
    public static func mergeProfiles(_ primary: ContactProfile?, _ secondary: ContactProfile?) -> ContactProfile? {
        guard let primary = primary else { return secondary }
        guard let secondary = secondary else { return primary }

        return ContactProfile(
            deviceId: primary.deviceId,
            nickname: choose(primary.nickname, secondary.nickname),
            callsign: choose(primary.callsign, secondary.callsign),
            firstName: choose(primary.firstName, secondary.firstName),
            lastName: choose(primary.lastName, secondary.lastName),
            company: choose(primary.company, secondary.company),
            platoon: choose(primary.platoon, secondary.platoon),
            squad: choose(primary.squad, secondary.squad),
            mobile: choose(primary.mobile, secondary.mobile),
            email: choose(primary.email, secondary.email),
            photoUri: choose(primary.photoUri, secondary.photoUri),
            role: primary.role != .none ? primary.role : secondary.role,
            lastSeenMs: max(primary.lastSeenMs, secondary.lastSeenMs),
            fromIp: choose(primary.fromIp, secondary.fromIp)
        )
    }

    /// Chooses the first non-null, non-blank string
    private static func choose(_ a: String?, _ b: String?) -> String? {
        if let a = a, !a.isEmpty, a.lowercased() != "null" {
            return a
        }
        if let b = b, !b.isEmpty, b.lowercased() != "null" {
            return b
        }
        return nil
    }

    // MARK: - Display Name Resolution

    /// Gets the effective display name for a contact
    public static func resolveDisplayName(for contact: ContactProfile) -> String {
        if let callsign = contact.callsign, !callsign.isEmpty, callsign.lowercased() != "unknown" {
            if let nickname = contact.nickname, !nickname.isEmpty {
                return "\(callsign) - \(nickname)"
            }
            return callsign
        }

        if let nickname = contact.nickname, !nickname.isEmpty {
            return nickname
        }

        if let fullName = contact.fullName, !fullName.isEmpty {
            return fullName
        }

        return String(contact.deviceId.prefix(8))
    }

    /// Gets the effective callsign for a contact
    public static func resolveCallsign(for contact: ContactProfile) -> String {
        if let callsign = contact.callsign, !callsign.isEmpty, callsign.lowercased() != "unknown" {
            return callsign
        }
        return "Unknown"
    }

    // MARK: - Last Seen Formatting

    /// Formats a timestamp as a relative "last seen" string
    public static func formatLastSeen(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(timestamp) / 1000.0)
        return formatLastSeen(date)
    }

    /// Formats a date as a relative "last seen" string
    public static func formatLastSeen(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }

    // MARK: - Online Status

    /// Checks if a contact is considered online (active within 5 minutes)
    public static func isOnline(_ contact: ContactProfile, threshold: TimeInterval = 300) -> Bool {
        guard let lastSeen = contact.lastSeenAt else { return false }
        return Date().timeIntervalSince(lastSeen) < threshold
    }

    // MARK: - Contact Filtering

    /// Filters contacts to exclude blocked and "Unknown" devices
    public static func filterForChat(
        contacts: [ContactProfile],
        blockedIds: Set<String>,
        myDeviceId: String
    ) -> [ContactProfile] {
        contacts.filter { contact in
            // Exclude self
            guard contact.deviceId != myDeviceId else { return false }

            // Exclude blocked
            guard !blockedIds.contains(contact.deviceId) else { return false }

            // Exclude contacts with no callsign or nickname
            let hasIdentity = (contact.callsign != nil && contact.callsign != "Unknown") ||
                              (contact.nickname != nil && !contact.nickname!.isEmpty)
            return hasIdentity
        }
    }

    /// Filters contacts for recipient selection
    public static func filterForRecipients(
        contacts: [ContactProfile],
        myDeviceId: String
    ) -> [ContactProfile] {
        contacts.filter { contact in
            // Exclude self
            guard contact.deviceId != myDeviceId else { return false }

            // Must have some form of identity
            let hasIdentity = (contact.callsign != nil && contact.callsign != "Unknown") ||
                              (contact.nickname != nil && !contact.nickname!.isEmpty)
            return hasIdentity
        }
    }

    // MARK: - Sorting

    /// Sorts contacts by callsign, then nickname
    public static func sortByCallsign(_ contacts: [ContactProfile]) -> [ContactProfile] {
        contacts.sorted { a, b in
            let aName = (a.callsign ?? a.nickname ?? "Unknown").lowercased()
            let bName = (b.callsign ?? b.nickname ?? "Unknown").lowercased()
            return aName < bName
        }
    }

    /// Sorts contacts by last seen (most recent first)
    public static func sortByLastSeen(_ contacts: [ContactProfile]) -> [ContactProfile] {
        contacts.sorted { a, b in
            (a.lastSeenMs) > (b.lastSeenMs)
        }
    }

    /// Sorts contacts by online status, then callsign
    public static func sortByOnlineStatus(_ contacts: [ContactProfile]) -> [ContactProfile] {
        contacts.sorted { a, b in
            let aOnline = isOnline(a)
            let bOnline = isOnline(b)

            if aOnline != bOnline {
                return aOnline && !bOnline
            }

            let aName = (a.callsign ?? a.nickname ?? "Unknown").lowercased()
            let bName = (b.callsign ?? b.nickname ?? "Unknown").lowercased()
            return aName < bName
        }
    }
}

// Note: Date.currentMillis is defined in Extensions.swift

// MARK: - String Extension for Profile Cleaning

extension String {
    /// Returns nil if the string is "null", "Unknown", or empty
    public var cleanedForProfile: String? {
        let trimmed = self.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.lowercased() == "null" || trimmed.lowercased() == "unknown" {
            return nil
        }
        return trimmed
    }
}
