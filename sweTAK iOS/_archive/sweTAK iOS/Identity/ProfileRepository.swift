import Foundation
import Combine
import os.log

// MARK: - Profile Repository Protocol

/// Protocol for profile data access
public protocol ProfileRepositoryProtocol {
    /// Get the local user's profile
    func getLocalProfile() -> LocalProfile

    /// Save the local user's profile
    func saveLocalProfile(_ profile: LocalProfile)

    /// Get a contact profile by device ID
    func getContactProfile(deviceId: String) -> ContactProfile?

    /// Save or update a contact profile
    func saveContactProfile(_ profile: ContactProfile)

    /// Get all contact profiles
    func getAllContacts() -> [ContactProfile]

    /// Delete a contact profile
    func deleteContact(deviceId: String)

    /// Observe all contacts
    func observeContacts() -> AnyPublisher<[ContactProfile], Never>
}

// MARK: - Profile Repository

/// Repository for managing local and contact profiles
/// Provides a clean data access layer for profile operations
public final class ProfileRepository: ProfileRepositoryProtocol, ObservableObject {

    // MARK: - Singleton

    public static let shared = ProfileRepository()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "ProfileRepo")

    // MARK: - Dependencies

    private let profileStore = LocalProfileStore.shared

    // MARK: - Published State

    @Published public private(set) var contacts: [ContactProfile] = []

    // MARK: - Private Storage

    private var contactsCache: [String: ContactProfile] = [:]
    private let contactsLock = NSLock()
    private let persistenceKey = "swetak.contacts.cache"

    // MARK: - Initialization

    private init() {
        loadContactsFromStorage()
    }

    // MARK: - Local Profile

    public func getLocalProfile() -> LocalProfile {
        profileStore.load()
    }

    public func saveLocalProfile(_ profile: LocalProfile) {
        profileStore.save(profile)
    }

    public var localCallsign: String {
        profileStore.resolveCallsign()
    }

    // MARK: - Contact Profiles

    public func getContactProfile(deviceId: String) -> ContactProfile? {
        contactsLock.lock()
        defer { contactsLock.unlock() }
        return contactsCache[deviceId]
    }

    public func saveContactProfile(_ profile: ContactProfile) {
        contactsLock.lock()
        contactsCache[profile.deviceId] = profile
        let allContacts = Array(contactsCache.values).sorted { $0.displayName < $1.displayName }
        contactsLock.unlock()

        DispatchQueue.main.async {
            self.contacts = allContacts
        }

        saveContactsToStorage()
        logger.debug("Saved contact: \(profile.displayName)")
    }

    public func getAllContacts() -> [ContactProfile] {
        contactsLock.lock()
        defer { contactsLock.unlock() }
        return Array(contactsCache.values).sorted { $0.displayName < $1.displayName }
    }

    public func deleteContact(deviceId: String) {
        contactsLock.lock()
        contactsCache.removeValue(forKey: deviceId)
        let allContacts = Array(contactsCache.values).sorted { $0.displayName < $1.displayName }
        contactsLock.unlock()

        DispatchQueue.main.async {
            self.contacts = allContacts
        }

        saveContactsToStorage()
        logger.debug("Deleted contact: \(deviceId)")
    }

    public func observeContacts() -> AnyPublisher<[ContactProfile], Never> {
        $contacts.eraseToAnyPublisher()
    }

    // MARK: - Batch Operations

    /// Update contact from network message
    public func updateFromNetwork(
        deviceId: String,
        callsign: String?,
        nickname: String? = nil,
        fromHost: String? = nil
    ) {
        contactsLock.lock()

        var profile = contactsCache[deviceId] ?? ContactProfile(deviceId: deviceId)

        if let cs = callsign, !cs.isEmpty, cs != "Unknown" {
            profile = ContactProfile(
                deviceId: profile.deviceId,
                nickname: nickname ?? profile.nickname,
                callsign: cs,
                firstName: profile.firstName,
                lastName: profile.lastName,
                company: profile.company,
                platoon: profile.platoon,
                squad: profile.squad,
                mobile: profile.mobile,
                email: profile.email,
                role: profile.role,
                lastSeenMs: Int64(Date().timeIntervalSince1970 * 1000),
                fromIp: fromHost ?? profile.fromIp
            )
        } else {
            // Just update last seen
            profile = ContactProfile(
                deviceId: profile.deviceId,
                nickname: nickname ?? profile.nickname,
                callsign: profile.callsign,
                firstName: profile.firstName,
                lastName: profile.lastName,
                company: profile.company,
                platoon: profile.platoon,
                squad: profile.squad,
                mobile: profile.mobile,
                email: profile.email,
                role: profile.role,
                lastSeenMs: Int64(Date().timeIntervalSince1970 * 1000),
                fromIp: fromHost ?? profile.fromIp
            )
        }

        contactsCache[deviceId] = profile
        let allContacts = Array(contactsCache.values).sorted { $0.displayName < $1.displayName }
        contactsLock.unlock()

        DispatchQueue.main.async {
            self.contacts = allContacts
        }
    }

    /// Merge a full profile from network
    public func mergeContactProfile(_ incoming: ContactProfile) {
        contactsLock.lock()

        let existing = contactsCache[incoming.deviceId]

        // Merge: prefer incoming values, fall back to existing
        let merged = ContactProfile(
            deviceId: incoming.deviceId,
            nickname: incoming.nickname ?? existing?.nickname,
            callsign: incoming.callsign ?? existing?.callsign,
            firstName: incoming.firstName ?? existing?.firstName,
            lastName: incoming.lastName ?? existing?.lastName,
            company: incoming.company ?? existing?.company,
            platoon: incoming.platoon ?? existing?.platoon,
            squad: incoming.squad ?? existing?.squad,
            mobile: incoming.mobile ?? existing?.mobile,
            email: incoming.email ?? existing?.email,
            role: incoming.role != .none ? incoming.role : (existing?.role ?? .none),
            lastSeenMs: incoming.lastSeenMs,
            fromIp: incoming.fromIp ?? existing?.fromIp
        )

        contactsCache[incoming.deviceId] = merged
        let allContacts = Array(contactsCache.values).sorted { $0.displayName < $1.displayName }
        contactsLock.unlock()

        DispatchQueue.main.async {
            self.contacts = allContacts
        }

        saveContactsToStorage()
    }

    /// Get online contacts (seen within last 5 minutes)
    public func getOnlineContacts() -> [ContactProfile] {
        getAllContacts().filter { $0.isOnline }
    }

    /// Get contact count
    public var contactCount: Int {
        contactsLock.lock()
        defer { contactsLock.unlock() }
        return contactsCache.count
    }

    /// Clear all contacts
    public func clearContacts() {
        contactsLock.lock()
        contactsCache.removeAll()
        contactsLock.unlock()

        DispatchQueue.main.async {
            self.contacts = []
        }

        saveContactsToStorage()
        logger.info("All contacts cleared")
    }

    // MARK: - Persistence

    private func loadContactsFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let decoded = try? JSONDecoder().decode([ContactProfile].self, from: data) else {
            return
        }

        contactsLock.lock()
        for contact in decoded {
            contactsCache[contact.deviceId] = contact
        }
        let allContacts = Array(contactsCache.values).sorted { $0.displayName < $1.displayName }
        contactsLock.unlock()

        DispatchQueue.main.async {
            self.contacts = allContacts
        }

        logger.info("Loaded \(decoded.count) contacts from storage")
    }

    private func saveContactsToStorage() {
        contactsLock.lock()
        let toSave = Array(contactsCache.values)
        contactsLock.unlock()

        guard let data = try? JSONEncoder().encode(toSave) else { return }
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }
}

// MARK: - Profile Search

extension ProfileRepository {

    /// Search contacts by name or callsign
    public func searchContacts(query: String) -> [ContactProfile] {
        let lowercased = query.lowercased()
        return getAllContacts().filter { contact in
            contact.displayName.lowercased().contains(lowercased) ||
            (contact.fullName?.lowercased().contains(lowercased) ?? false) ||
            (contact.callsign?.lowercased().contains(lowercased) ?? false) ||
            (contact.nickname?.lowercased().contains(lowercased) ?? false)
        }
    }

    /// Get contacts in a specific company
    public func getContactsByCompany(_ company: String) -> [ContactProfile] {
        getAllContacts().filter { $0.company?.lowercased() == company.lowercased() }
    }

    /// Get contacts by role
    public func getContactsByRole(_ role: MilitaryRole) -> [ContactProfile] {
        getAllContacts().filter { $0.role == role }
    }
}
