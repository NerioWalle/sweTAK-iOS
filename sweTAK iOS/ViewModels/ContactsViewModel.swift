import Foundation
import Combine
import os.log

/// ViewModel for managing contacts/profiles
/// Mirrors Android ContactBook functionality
public final class ContactsViewModel: ObservableObject {

    // MARK: - Singleton

    public static let shared = ContactsViewModel()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "ContactsViewModel")

    // MARK: - Published State

    @Published public private(set) var contacts: [ContactProfile] = []
    @Published public private(set) var blockedDeviceIds: Set<String> = []
    @Published public private(set) var myProfile: ContactProfile?

    // MARK: - Storage Keys

    private enum Keys {
        static let contacts = "swetak_contacts"
        static let blockedIds = "swetak_blocked_ids"
        static let myProfile = "swetak_my_profile"
    }

    // MARK: - Initialization

    private init() {
        loadFromStorage()
        setupListeners()
    }

    // MARK: - Listeners

    private func setupListeners() {
        TransportCoordinator.shared.profileListener = self
        TransportCoordinator.shared.helloListener = self

        // Configure UDP profile provider
        UDPClientManager.shared.provideLocalProfile = { [weak self] in
            self?.myProfile ?? ContactProfile(
                deviceId: TransportCoordinator.shared.deviceId,
                callsign: "Unknown"
            )
        }
    }

    // MARK: - Storage

    private func loadFromStorage() {
        // Load contacts
        if let data = UserDefaults.standard.data(forKey: Keys.contacts),
           let storedContacts = try? JSONDecoder().decode([ContactProfile].self, from: data) {
            contacts = storedContacts
            logger.info("Loaded \(storedContacts.count) contacts from storage")
        }

        // Load blocked IDs
        if let blockedArray = UserDefaults.standard.stringArray(forKey: Keys.blockedIds) {
            blockedDeviceIds = Set(blockedArray)
        }

        // Load my profile
        if let data = UserDefaults.standard.data(forKey: Keys.myProfile),
           let profile = try? JSONDecoder().decode(ContactProfile.self, from: data) {
            myProfile = profile
        }
    }

    private func saveContacts() {
        if let data = try? JSONEncoder().encode(contacts) {
            UserDefaults.standard.set(data, forKey: Keys.contacts)
        }
    }

    private func saveBlockedIds() {
        UserDefaults.standard.set(Array(blockedDeviceIds), forKey: Keys.blockedIds)
    }

    private func saveMyProfile() {
        if let profile = myProfile, let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Keys.myProfile)
        }
    }

    // MARK: - My Profile

    /// Update my profile
    public func updateMyProfile(_ profile: ContactProfile) {
        myProfile = profile
        saveMyProfile()
        logger.info("Updated my profile: \(profile.callsign ?? "Unknown")")

        // Broadcast profile to network
        TransportCoordinator.shared.publishProfile(profile)
    }

    /// Update my callsign
    public func updateMyCallsign(_ callsign: String) {
        let deviceId = TransportCoordinator.shared.deviceId
        if var profile = myProfile {
            profile = ContactProfile(
                deviceId: deviceId,
                nickname: profile.nickname,
                callsign: callsign,
                firstName: profile.firstName,
                lastName: profile.lastName,
                company: profile.company,
                platoon: profile.platoon,
                squad: profile.squad,
                mobile: profile.mobile,
                email: profile.email,
                role: profile.role
            )
            updateMyProfile(profile)
        } else {
            updateMyProfile(ContactProfile(deviceId: deviceId, callsign: callsign))
        }
    }

    // MARK: - Contact Operations

    /// Get contact by device ID
    public func getContact(byDeviceId deviceId: String) -> ContactProfile? {
        contacts.first { $0.deviceId == deviceId }
    }

    /// Get contact by callsign
    public func getContact(byCallsign callsign: String) -> ContactProfile? {
        contacts.first { $0.callsign == callsign }
    }

    /// Update or add a contact
    public func upsertContact(_ contact: ContactProfile) {
        if let index = contacts.firstIndex(where: { $0.deviceId == contact.deviceId }) {
            contacts[index] = contact
        } else {
            contacts.append(contact)
        }
        saveContacts()
        logger.debug("Upserted contact: \(contact.callsign ?? contact.deviceId)")
    }

    /// Remove a contact
    public func removeContact(deviceId: String) {
        contacts.removeAll { $0.deviceId == deviceId }
        saveContacts()
    }

    // MARK: - Blocking

    /// Block a device
    public func blockDevice(_ deviceId: String) {
        blockedDeviceIds.insert(deviceId)
        saveBlockedIds()
        logger.info("Blocked device: \(deviceId)")

        // Update PinsViewModel with new blocked list
        PinsViewModel.shared.updateBlockedIds(blockedDeviceIds)
    }

    /// Unblock a device
    public func unblockDevice(_ deviceId: String) {
        blockedDeviceIds.remove(deviceId)
        saveBlockedIds()
        logger.info("Unblocked device: \(deviceId)")

        // Update PinsViewModel with new blocked list
        PinsViewModel.shared.updateBlockedIds(blockedDeviceIds)
    }

    /// Check if a device is blocked
    public func isBlocked(_ deviceId: String) -> Bool {
        blockedDeviceIds.contains(deviceId)
    }

    // MARK: - Discovery

    /// Refresh peer discovery
    public func refreshPeerDiscovery() {
        guard let callsign = myProfile?.callsign else { return }
        TransportCoordinator.shared.refreshPeerDiscovery(callsign: callsign)
    }

    /// Request profile from specific host (UDP)
    public func requestProfile(from host: String) {
        UDPClientManager.shared.publishProfileRequest(
            to: host,
            callsign: myProfile?.callsign,
            deviceId: TransportCoordinator.shared.deviceId
        )
    }

    // MARK: - Computed Properties

    /// Online contacts (active in last 5 minutes)
    public var onlineContacts: [ContactProfile] {
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        return contacts.filter { contact in
            guard let lastSeen = contact.lastSeenAt else { return false }
            return lastSeen > fiveMinutesAgo
        }
    }

    /// Contacts sorted by callsign
    public var sortedContacts: [ContactProfile] {
        contacts.sorted { ($0.callsign ?? "") < ($1.callsign ?? "") }
    }

    /// Non-blocked contacts
    public var allowedContacts: [ContactProfile] {
        contacts.filter { !blockedDeviceIds.contains($0.deviceId) }
    }

    /// Clear all contacts
    public func clearAllContacts() {
        contacts.removeAll()
        blockedDeviceIds.removeAll()
        saveContacts()
        saveBlockedIds()
        logger.info("Cleared all contacts")
    }

    /// Set my profile directly
    public func setMyProfile(_ profile: ContactProfile) {
        myProfile = profile
        saveMyProfile()

        // Also update in contacts list
        upsertContact(profile)

        // Broadcast to network
        TransportCoordinator.shared.publishProfile(profile)
        logger.info("Set my profile: \(profile.callsign ?? "Unknown")")
    }
}

// MARK: - ProfileListener

extension ContactsViewModel: ProfileListener {
    public func onProfileReceived(profile: ContactProfile) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Don't store our own profile
            if profile.deviceId == TransportCoordinator.shared.deviceId {
                return
            }

            // Update contact with current timestamp
            let updatedProfile = ContactProfile(
                deviceId: profile.deviceId,
                nickname: profile.nickname,
                callsign: profile.callsign,
                firstName: profile.firstName,
                lastName: profile.lastName,
                company: profile.company,
                platoon: profile.platoon,
                squad: profile.squad,
                mobile: profile.mobile,
                email: profile.email,
                photoUri: profile.photoUri,
                role: profile.role,
                lastSeenMs: Date.currentMillis,
                fromIp: profile.fromIp
            )

            self.upsertContact(updatedProfile)
            self.logger.debug("Received profile: \(profile.callsign ?? profile.deviceId)")
        }
    }
}

// MARK: - HelloListener

extension ContactsViewModel: HelloListener {
    public func onHelloReceived(deviceId: String, callsign: String, fromHost: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Create or update minimal contact
            let profile = ContactProfile(
                deviceId: deviceId,
                callsign: callsign.isEmpty ? nil : callsign,
                lastSeenMs: Date.currentMillis,
                fromIp: fromHost
            )

            // Only update if we don't have more complete data
            if let existing = self.getContact(byDeviceId: deviceId) {
                if existing.callsign == nil && !callsign.isEmpty {
                    self.upsertContact(ContactProfile(
                        deviceId: deviceId,
                        nickname: existing.nickname,
                        callsign: callsign,
                        firstName: existing.firstName,
                        lastName: existing.lastName,
                        company: existing.company,
                        platoon: existing.platoon,
                        squad: existing.squad,
                        mobile: existing.mobile,
                        email: existing.email,
                        photoUri: existing.photoUri,
                        role: existing.role,
                        lastSeenMs: Date.currentMillis,
                        fromIp: fromHost ?? existing.fromIp
                    ))
                }
            } else {
                self.upsertContact(profile)
            }

            self.logger.debug("Hello from \(callsign)@\(fromHost ?? "unknown")")
        }
    }
}
