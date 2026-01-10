import Foundation
import Combine
import os.log

// MARK: - Profile ViewModel

/// ViewModel for profile state management
/// Mirrors Android ProfileViewModel functionality
/// Provides reactive state for SwiftUI profile views
public final class ProfileViewModel: ObservableObject {

    // MARK: - Singleton

    public static let shared = ProfileViewModel()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "ProfileVM")

    // MARK: - Dependencies

    private let profileStore = LocalProfileStore.shared
    private let profileRepo = ProfileRepository.shared

    // MARK: - Published State

    /// Current local profile
    @Published public private(set) var profile: LocalProfile = LocalProfile()

    /// Current resolved callsign
    @Published public private(set) var callsign: String = "Unknown"

    /// Whether profile has been configured
    @Published public private(set) var isConfigured: Bool = false

    /// Validation errors
    @Published public private(set) var validationErrors: [String] = []

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupBindings()
        loadProfile()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Observe profile store changes
        profileStore.$profile
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                self?.profile = profile
                self?.updateConfiguredState()
            }
            .store(in: &cancellables)

        profileStore.$callsign
            .receive(on: DispatchQueue.main)
            .assign(to: &$callsign)
    }

    private func loadProfile() {
        profile = profileStore.load()
        callsign = profileStore.resolveCallsign()
        updateConfiguredState()
        logger.debug("Profile loaded: callsign=\(self.callsign)")
    }

    private func updateConfiguredState() {
        isConfigured = !profile.callsign.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Public API

    /// Save updated profile
    public func save(_ updated: LocalProfile) {
        validationErrors = validate(updated)

        guard validationErrors.isEmpty else {
            logger.warning("Profile validation failed: \(self.validationErrors)")
            return
        }

        profileStore.save(updated)
        profile = updated
        callsign = profileStore.resolveCallsign()
        updateConfiguredState()

        logger.info("Profile saved: callsign=\(self.callsign)")

        // Notify network of profile change
        RefreshBus.shared.emitProfileChanged()
    }

    /// Update individual field
    public func updateCallsign(_ value: String) {
        var updated = profile
        updated = LocalProfile(
            callsign: value,
            nickname: updated.nickname,
            firstName: updated.firstName,
            lastName: updated.lastName,
            company: updated.company,
            platoon: updated.platoon,
            squad: updated.squad,
            phone: updated.phone,
            email: updated.email,
            role: updated.role
        )
        save(updated)
    }

    public func updateNickname(_ value: String) {
        var updated = profile
        updated = LocalProfile(
            callsign: updated.callsign,
            nickname: value,
            firstName: updated.firstName,
            lastName: updated.lastName,
            company: updated.company,
            platoon: updated.platoon,
            squad: updated.squad,
            phone: updated.phone,
            email: updated.email,
            role: updated.role
        )
        save(updated)
    }

    public func updateRole(_ role: MilitaryRole) {
        var updated = profile
        updated = LocalProfile(
            callsign: updated.callsign,
            nickname: updated.nickname,
            firstName: updated.firstName,
            lastName: updated.lastName,
            company: updated.company,
            platoon: updated.platoon,
            squad: updated.squad,
            phone: updated.phone,
            email: updated.email,
            role: role
        )
        save(updated)
    }

    /// Clear profile
    public func clearProfile() {
        profileStore.clear()
        profile = LocalProfile()
        callsign = "Unknown"
        isConfigured = false
        logger.info("Profile cleared")
    }

    /// Reload profile from storage
    public func refresh() {
        loadProfile()
    }

    // MARK: - Validation

    private func validate(_ profile: LocalProfile) -> [String] {
        var errors: [String] = []

        // Callsign validation
        let trimmedCallsign = profile.callsign.trimmingCharacters(in: .whitespaces)
        if trimmedCallsign.isEmpty {
            errors.append("Callsign is required")
        } else if trimmedCallsign.count < 2 {
            errors.append("Callsign must be at least 2 characters")
        } else if trimmedCallsign.count > 20 {
            errors.append("Callsign must be 20 characters or less")
        }

        // Email validation (optional but must be valid if provided)
        if !profile.email.isEmpty {
            let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
            if profile.email.range(of: emailRegex, options: .regularExpression) == nil {
                errors.append("Invalid email format")
            }
        }

        // Phone validation (optional but must be valid if provided)
        if !profile.phone.isEmpty {
            let phoneRegex = #"^[+]?[0-9\s\-()]{6,20}$"#
            if profile.phone.range(of: phoneRegex, options: .regularExpression) == nil {
                errors.append("Invalid phone format")
            }
        }

        return errors
    }

    // MARK: - Contact Profile Conversion

    /// Get current profile as ContactProfile for sharing
    public func asContactProfile(deviceId: String) -> ContactProfile {
        profileStore.toContactProfile(deviceId: deviceId)
    }
}

// MARK: - Profile Field Binding Helpers

extension ProfileViewModel {

    /// Create binding for profile editing
    public func makeEditableProfile() -> EditableProfile {
        EditableProfile(
            callsign: profile.callsign,
            nickname: profile.nickname,
            firstName: profile.firstName,
            lastName: profile.lastName,
            company: profile.company,
            platoon: profile.platoon,
            squad: profile.squad,
            phone: profile.phone,
            email: profile.email,
            role: profile.role
        )
    }

    /// Save editable profile
    public func saveEditable(_ editable: EditableProfile) {
        let updated = LocalProfile(
            callsign: editable.callsign,
            nickname: editable.nickname,
            firstName: editable.firstName,
            lastName: editable.lastName,
            company: editable.company,
            platoon: editable.platoon,
            squad: editable.squad,
            phone: editable.phone,
            email: editable.email,
            role: editable.role
        )
        save(updated)
    }
}

// MARK: - Editable Profile

/// Mutable version of LocalProfile for form binding
public struct EditableProfile {
    public var callsign: String
    public var nickname: String
    public var firstName: String
    public var lastName: String
    public var company: String
    public var platoon: String
    public var squad: String
    public var phone: String
    public var email: String
    public var role: MilitaryRole

    public init(
        callsign: String = "",
        nickname: String = "",
        firstName: String = "",
        lastName: String = "",
        company: String = "",
        platoon: String = "",
        squad: String = "",
        phone: String = "",
        email: String = "",
        role: MilitaryRole = .none
    ) {
        self.callsign = callsign
        self.nickname = nickname
        self.firstName = firstName
        self.lastName = lastName
        self.company = company
        self.platoon = platoon
        self.squad = squad
        self.phone = phone
        self.email = email
        self.role = role
    }
}
