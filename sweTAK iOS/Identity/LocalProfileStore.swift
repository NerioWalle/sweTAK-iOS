import Foundation
import Combine
import os.log

// MARK: - Local Profile Store

/// Persistent storage for local user profile
/// Mirrors Android LocalProfileStore functionality
public final class LocalProfileStore: ObservableObject {

    // MARK: - Singleton

    public static let shared = LocalProfileStore()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "ProfileStore")

    // MARK: - Published State

    @Published public private(set) var profile: LocalProfile = LocalProfile()
    @Published public private(set) var callsign: String = "Unknown"

    // MARK: - UserDefaults Keys

    private let prefsName = "profile"

    private enum Keys {
        static let callsign = "callsign"
        static let callsignHint = "profile_callsign_hint"
        static let nickname = "nickname"
        static let firstName = "firstName"
        static let lastName = "lastName"
        static let company = "company"
        static let unit = "unit"  // Legacy key
        static let platoon = "platoon"
        static let squad = "squad"
        static let teamLegacy = "team"  // Legacy key for migration
        static let phone = "phone"
        static let email = "email"
        static let role = "role"
    }

    // MARK: - UserDefaults

    private var defaults: UserDefaults {
        UserDefaults(suiteName: prefsName) ?? .standard
    }

    // MARK: - Initialization

    private init() {
        loadProfile()
    }

    // MARK: - Public API

    /// Load profile from persistent storage
    public func load() -> LocalProfile {
        loadProfile()
        return profile
    }

    /// Save profile to persistent storage
    public func save(_ newProfile: LocalProfile) {
        let cs = clean(newProfile.callsign)

        defaults.set(cs, forKey: Keys.callsign)
        defaults.set(cs, forKey: Keys.callsignHint)  // Critical for fast/stable resolution
        defaults.set(clean(newProfile.nickname), forKey: Keys.nickname)
        defaults.set(clean(newProfile.firstName), forKey: Keys.firstName)
        defaults.set(clean(newProfile.lastName), forKey: Keys.lastName)
        defaults.set(clean(newProfile.company), forKey: Keys.company)
        defaults.set(clean(newProfile.company), forKey: Keys.unit)  // Keep legacy in sync
        defaults.set(clean(newProfile.platoon), forKey: Keys.platoon)
        defaults.set(clean(newProfile.squad), forKey: Keys.squad)
        defaults.set(clean(newProfile.phone), forKey: Keys.phone)
        defaults.set(clean(newProfile.email), forKey: Keys.email)
        defaults.set(newProfile.role.rawValue, forKey: Keys.role)

        defaults.synchronize()

        // Update published state
        profile = newProfile
        callsign = resolveCallsign()

        logger.info("Profile saved: \(cs)")
    }

    /// Resolve the best available callsign
    public func resolveCallsign() -> String {
        // Check hint first (faster resolution)
        if let hint = goodValue(defaults.string(forKey: Keys.callsignHint)) {
            return hint
        }

        // Fall back to main callsign
        if let cs = goodValue(defaults.string(forKey: Keys.callsign)) {
            return cs
        }

        return "Unknown"
    }

    /// Update just the callsign
    public func updateCallsign(_ newCallsign: String) {
        var updated = profile
        updated.callsign = newCallsign
        save(updated)
    }

    /// Update military role
    public func updateRole(_ newRole: MilitaryRole) {
        var updated = profile
        updated.role = newRole
        save(updated)
    }

    /// Clear all profile data
    public func clear() {
        let keys = [
            Keys.callsign, Keys.callsignHint, Keys.nickname,
            Keys.firstName, Keys.lastName, Keys.company, Keys.unit,
            Keys.platoon, Keys.squad, Keys.teamLegacy,
            Keys.phone, Keys.email, Keys.role
        ]

        keys.forEach { defaults.removeObject(forKey: $0) }
        defaults.synchronize()

        profile = LocalProfile()
        callsign = "Unknown"

        logger.info("Profile cleared")
    }

    /// Check if profile has been configured
    public var isConfigured: Bool {
        !profile.callsign.isEmpty
    }

    /// Convert local profile to ContactProfile for network transmission
    public func toContactProfile(deviceId: String) -> ContactProfile {
        ContactProfile(
            deviceId: deviceId,
            nickname: profile.nickname.isEmpty ? nil : profile.nickname,
            callsign: profile.callsign.isEmpty ? nil : profile.callsign,
            firstName: profile.firstName.isEmpty ? nil : profile.firstName,
            lastName: profile.lastName.isEmpty ? nil : profile.lastName,
            company: profile.company.isEmpty ? nil : profile.company,
            platoon: profile.platoon.isEmpty ? nil : profile.platoon,
            squad: profile.squad.isEmpty ? nil : profile.squad,
            mobile: profile.phone.isEmpty ? nil : profile.phone,
            email: profile.email.isEmpty ? nil : profile.email,
            role: profile.role
        )
    }

    // MARK: - Private Methods

    private func loadProfile() {
        // Prefer company, but support legacy "unit"
        let company = clean(defaults.string(forKey: Keys.company)).isEmpty
            ? clean(defaults.string(forKey: Keys.unit))
            : clean(defaults.string(forKey: Keys.company))

        // Prefer squad, but support legacy "team" for migration
        let squad = clean(defaults.string(forKey: Keys.squad)).isEmpty
            ? clean(defaults.string(forKey: Keys.teamLegacy))
            : clean(defaults.string(forKey: Keys.squad))

        let roleStr = clean(defaults.string(forKey: Keys.role))
        let role = MilitaryRole.from(roleStr)

        profile = LocalProfile(
            callsign: clean(defaults.string(forKey: Keys.callsign)),
            nickname: clean(defaults.string(forKey: Keys.nickname)),
            firstName: clean(defaults.string(forKey: Keys.firstName)),
            lastName: clean(defaults.string(forKey: Keys.lastName)),
            company: company,
            platoon: clean(defaults.string(forKey: Keys.platoon)),
            squad: squad,
            phone: clean(defaults.string(forKey: Keys.phone)),
            email: clean(defaults.string(forKey: Keys.email)),
            role: role
        )

        callsign = resolveCallsign()

        logger.debug("Profile loaded: \(self.callsign)")
    }

    /// Clean a value by trimming whitespace and handling "null" strings
    private func clean(_ value: String?) -> String {
        guard let v = value?.trimmingCharacters(in: .whitespaces) else { return "" }
        if v.lowercased() == "null" { return "" }
        return v
    }

    /// Check if a value is "good" (not empty, null, or "unknown")
    private func goodValue(_ value: String?) -> String? {
        guard let s = value?.trimmingCharacters(in: .whitespaces) else { return nil }
        if s.isEmpty { return nil }
        if s.lowercased() == "null" { return nil }
        if s.lowercased() == "unknown" { return nil }
        return s
    }
}

// MARK: - Profile Change Observer

extension LocalProfileStore {

    /// Observe profile changes
    public func observeProfile() -> AnyPublisher<LocalProfile, Never> {
        $profile.eraseToAnyPublisher()
    }

    /// Observe callsign changes
    public func observeCallsign() -> AnyPublisher<String, Never> {
        $callsign.eraseToAnyPublisher()
    }
}
