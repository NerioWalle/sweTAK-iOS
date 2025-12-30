import Foundation
import CoreLocation

// MARK: - Map Profile Utilities

/// Utilities for profile sanitization, contact lookup, and merging
/// Mirrors Android MapProfileUtils functionality
public enum MapProfileUtils {

    // MARK: - Field Sanitization

    /// Sanitize a profile field value
    /// - Parameters:
    ///   - value: The raw value to sanitize
    ///   - maxLength: Maximum allowed length (0 = no limit)
    /// - Returns: Sanitized value or nil if invalid
    public static func sanitizeProfileField(_ value: String?, maxLength: Int = 0) -> String? {
        guard let value = value else { return nil }

        // Trim whitespace
        var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove null/undefined literals
        let lower = cleaned.lowercased()
        if lower.isEmpty || lower == "null" || lower == "undefined" || lower == "unknown" {
            return nil
        }

        // Check if it looks like a device ID or hex string
        if looksLikeIdentifierHex(cleaned) {
            return nil
        }

        // Apply max length if specified
        if maxLength > 0 && cleaned.count > maxLength {
            cleaned = String(cleaned.prefix(maxLength))
        }

        return cleaned.isEmpty ? nil : cleaned
    }

    /// Sanitize a callsign specifically
    /// Removes invalid characters and enforces callsign rules
    public static func sanitizeCallsign(_ value: String?) -> String? {
        guard let sanitized = sanitizeProfileField(value, maxLength: 32) else {
            return nil
        }

        // Callsigns should be alphanumeric with hyphens allowed
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let filtered = sanitized.unicodeScalars.filter { allowed.contains($0) }
        let result = String(String.UnicodeScalarView(filtered))

        return result.isEmpty ? nil : result.uppercased()
    }

    /// Sanitize a nickname
    public static func sanitizeNickname(_ value: String?) -> String? {
        return sanitizeProfileField(value, maxLength: 64)
    }

    /// Sanitize an email address
    public static func sanitizeEmail(_ value: String?) -> String? {
        guard let cleaned = sanitizeProfileField(value, maxLength: 128) else {
            return nil
        }

        // Basic email validation
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let regex = try? NSRegularExpression(pattern: emailPattern, options: [])
        let range = NSRange(cleaned.startIndex..., in: cleaned)

        if regex?.firstMatch(in: cleaned, options: [], range: range) != nil {
            return cleaned.lowercased()
        }

        return nil
    }

    /// Sanitize a phone number
    public static func sanitizePhone(_ value: String?) -> String? {
        guard let cleaned = sanitizeProfileField(value, maxLength: 32) else {
            return nil
        }

        // Keep only digits, +, and basic formatting
        let allowed = CharacterSet(charactersIn: "+0123456789- ()")
        let filtered = cleaned.unicodeScalars.filter { allowed.contains($0) }
        let result = String(String.UnicodeScalarView(filtered))

        // Must have at least some digits
        let digitCount = result.filter { $0.isNumber }.count
        return digitCount >= 6 ? result : nil
    }

    // MARK: - Contact Lookup

    /// Look up a contact's nickname from a contact dictionary
    /// - Parameters:
    ///   - contacts: Dictionary of contacts keyed by deviceId
    ///   - deviceId: Device ID to look up
    ///   - host: Optional host/IP fallback key
    /// - Returns: Nickname if found, nil otherwise
    public static func contactNicknameOrNull(
        contacts: [String: ContactProfile],
        deviceId: String?,
        host: String? = nil
    ) -> String? {
        // Try deviceId first
        if let deviceId = deviceId, !deviceId.isEmpty {
            if let contact = contacts[deviceId] {
                return sanitizeNickname(contact.nickname) ?? sanitizeNickname(contact.callsign)
            }
        }

        // Try host/IP as fallback
        if let host = host, !host.isEmpty {
            if let contact = contacts[host] {
                return sanitizeNickname(contact.nickname) ?? sanitizeNickname(contact.callsign)
            }
        }

        return nil
    }

    /// Look up a contact's callsign from a contact dictionary
    public static func contactCallsignOrNull(
        contacts: [String: ContactProfile],
        deviceId: String?,
        host: String? = nil
    ) -> String? {
        if let deviceId = deviceId, !deviceId.isEmpty {
            if let contact = contacts[deviceId] {
                return sanitizeCallsign(contact.callsign)
            }
        }

        if let host = host, !host.isEmpty {
            if let contact = contacts[host] {
                return sanitizeCallsign(contact.callsign)
            }
        }

        return nil
    }

    /// Get display name for a device from contacts
    /// Returns callsign, nickname, or truncated deviceId
    public static func displayNameFor(
        deviceId: String,
        contacts: [String: ContactProfile]
    ) -> String {
        if let contact = contacts[deviceId] {
            if let callsign = sanitizeCallsign(contact.callsign) {
                if let nickname = sanitizeNickname(contact.nickname) {
                    return "\(callsign) - \(nickname)"
                }
                return callsign
            }
            if let nickname = sanitizeNickname(contact.nickname) {
                return nickname
            }
        }

        // Return truncated device ID
        return String(deviceId.prefix(8))
    }

    // MARK: - Contact Merging

    /// Merge multiple contact sources into a single contact profile
    /// Priority: latest > current > network
    /// - Parameters:
    ///   - latest: Most recent contact info (e.g., from incoming message)
    ///   - current: Current stored contact
    ///   - network: Contact info from network discovery
    /// - Returns: Merged contact profile
    public static func mergedContact(
        latest: [String: ContactProfile],
        current: [String: ContactProfile],
        deviceId: String,
        fromIp: String? = nil
    ) -> ContactProfile? {
        let latestContact = latest[deviceId]
        let currentContact = current[deviceId]

        // Start with latest or current
        var base: ContactProfile
        if let latest = latestContact {
            base = latest
        } else if let current = currentContact {
            base = current
        } else {
            return nil
        }

        // Merge with current if different
        if let current = currentContact, latestContact != nil {
            base = ContactProfile(
                deviceId: deviceId,
                nickname: chooseNonEmpty(base.nickname, current.nickname),
                callsign: chooseNonEmpty(base.callsign, current.callsign),
                firstName: chooseNonEmpty(base.firstName, current.firstName),
                lastName: chooseNonEmpty(base.lastName, current.lastName),
                company: chooseNonEmpty(base.company, current.company),
                platoon: chooseNonEmpty(base.platoon, current.platoon),
                squad: chooseNonEmpty(base.squad, current.squad),
                mobile: chooseNonEmpty(base.mobile, current.mobile),
                email: chooseNonEmpty(base.email, current.email),
                photoUri: chooseNonEmpty(base.photoUri, current.photoUri),
                role: base.role != .none ? base.role : current.role,
                lastSeenMs: max(base.lastSeenMs, current.lastSeenMs),
                fromIp: fromIp ?? base.fromIp ?? current.fromIp
            )
        }

        return base
    }

    /// Upsert (update or insert) a contact into a dictionary
    /// - Parameters:
    ///   - contacts: Mutable contact dictionary
    ///   - incoming: New contact information
    ///   - mergeExisting: Whether to merge with existing or replace
    /// - Returns: The resulting contact
    @discardableResult
    public static func upsertContact(
        into contacts: inout [String: ContactProfile],
        incoming: ContactProfile,
        mergeExisting: Bool = true
    ) -> ContactProfile {
        let deviceId = incoming.deviceId

        if mergeExisting, let existing = contacts[deviceId] {
            // Merge incoming with existing
            let merged = ContactProfile(
                deviceId: deviceId,
                nickname: chooseNonEmpty(incoming.nickname, existing.nickname),
                callsign: chooseNonEmpty(incoming.callsign, existing.callsign),
                firstName: chooseNonEmpty(incoming.firstName, existing.firstName),
                lastName: chooseNonEmpty(incoming.lastName, existing.lastName),
                company: chooseNonEmpty(incoming.company, existing.company),
                platoon: chooseNonEmpty(incoming.platoon, existing.platoon),
                squad: chooseNonEmpty(incoming.squad, existing.squad),
                mobile: chooseNonEmpty(incoming.mobile, existing.mobile),
                email: chooseNonEmpty(incoming.email, existing.email),
                photoUri: chooseNonEmpty(incoming.photoUri, existing.photoUri),
                role: incoming.role != .none ? incoming.role : existing.role,
                lastSeenMs: max(incoming.lastSeenMs, existing.lastSeenMs),
                fromIp: incoming.fromIp ?? existing.fromIp
            )
            contacts[deviceId] = merged
            return merged
        } else {
            contacts[deviceId] = incoming
            return incoming
        }
    }

    // MARK: - Marker Display

    /// Create a display label for a map marker
    /// - Parameters:
    ///   - callsign: Primary callsign
    ///   - nickname: Optional nickname
    ///   - deviceId: Fallback device ID
    ///   - maxLength: Maximum label length
    /// - Returns: Display label string
    public static func markerLabel(
        callsign: String?,
        nickname: String?,
        deviceId: String,
        maxLength: Int = 20
    ) -> String {
        var label: String

        if let callsign = sanitizeCallsign(callsign) {
            label = callsign
        } else if let nickname = sanitizeNickname(nickname) {
            label = nickname
        } else {
            label = String(deviceId.prefix(8))
        }

        if label.count > maxLength {
            label = String(label.prefix(maxLength - 1)) + "…"
        }

        return label
    }

    /// Create a subtitle for a map marker (e.g., role or unit)
    public static func markerSubtitle(
        role: MilitaryRole?,
        company: String?,
        platoon: String?
    ) -> String? {
        var parts: [String] = []

        if let role = role, role != .none {
            parts.append(role.abbreviation)
        }

        if let company = sanitizeProfileField(company, maxLength: 16) {
            parts.append(company)
        }

        if let platoon = sanitizeProfileField(platoon, maxLength: 16) {
            parts.append(platoon)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " / ")
    }

    // MARK: - Contact Status

    /// Get staleness category for a contact
    public enum ContactStaleness: String {
        case active     // < 5 min
        case recent     // 5-30 min
        case stale      // 30 min - 2 hr
        case inactive   // > 2 hr

        public var minuteThreshold: Int {
            switch self {
            case .active: return 5
            case .recent: return 30
            case .stale: return 120
            case .inactive: return Int.max
            }
        }
    }

    /// Determine staleness category for a contact
    public static func staleness(for contact: ContactProfile) -> ContactStaleness {
        let ageMs = Date.currentMillis - contact.lastSeenMs
        let ageMinutes = Int(ageMs / 60_000)

        if ageMinutes < 5 {
            return .active
        } else if ageMinutes < 30 {
            return .recent
        } else if ageMinutes < 120 {
            return .stale
        } else {
            return .inactive
        }
    }

    /// Group contacts by staleness
    public static func groupByStaleness(
        _ contacts: [ContactProfile]
    ) -> [ContactStaleness: [ContactProfile]] {
        var groups: [ContactStaleness: [ContactProfile]] = [
            .active: [],
            .recent: [],
            .stale: [],
            .inactive: []
        ]

        for contact in contacts {
            let stale = staleness(for: contact)
            groups[stale, default: []].append(contact)
        }

        return groups
    }

    // MARK: - Private Helpers

    private static func chooseNonEmpty(_ a: String?, _ b: String?) -> String? {
        if let a = a, !a.isEmpty, a.lowercased() != "null", a.lowercased() != "unknown" {
            return a
        }
        if let b = b, !b.isEmpty, b.lowercased() != "null", b.lowercased() != "unknown" {
            return b
        }
        return nil
    }
}

// MARK: - Profile Validation

extension MapProfileUtils {

    /// Validate a complete profile has required fields
    public static func isProfileComplete(_ profile: ContactProfile) -> Bool {
        sanitizeCallsign(profile.callsign) != nil ||
        sanitizeNickname(profile.nickname) != nil
    }

    /// Validate a local profile has required fields for network broadcast
    public static func isLocalProfileValid(_ profile: LocalProfile) -> Bool {
        !profile.callsign.isEmpty || !profile.nickname.isEmpty
    }

    /// Get profile completion percentage (for UI progress indicators)
    public static func profileCompleteness(_ profile: ContactProfile) -> Double {
        let fields: [String?] = [
            profile.callsign,
            profile.nickname,
            profile.firstName,
            profile.lastName,
            profile.company,
            profile.platoon,
            profile.squad,
            profile.mobile,
            profile.email
        ]

        let filled = fields.compactMap { sanitizeProfileField($0) }.count
        return Double(filled) / Double(fields.count)
    }
}

// MARK: - Contact Coordinate Helpers

extension MapProfileUtils {

    /// Create a coordinate from a friend's last known position
    public static func coordinateFor(friend: Friend) -> CLLocationCoordinate2D? {
        guard let lat = friend.lastLat,
              let lon = friend.lastLon,
              MapCoordinateUtils.isValidCoordinate(lat: lat, lon: lon) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Create a RemoteMarker from a contact profile and position
    public static func markerFor(
        contact: ContactProfile,
        lat: Double,
        lon: Double
    ) -> RemoteMarker? {
        guard MapCoordinateUtils.isValidCoordinate(lat: lat, lon: lon) else {
            return nil
        }

        return RemoteMarker(
            deviceId: contact.deviceId,
            callsign: contact.callsign ?? "Unknown",
            nickname: contact.nickname,
            lat: lat,
            lon: lon
        )
    }
}
