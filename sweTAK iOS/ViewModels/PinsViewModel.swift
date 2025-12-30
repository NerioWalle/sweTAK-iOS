import Foundation
import Combine
import os.log

/// ViewModel for managing pins and linked forms
/// Mirrors Android PinsViewModel functionality
public final class PinsViewModel: ObservableObject {

    // MARK: - Singleton

    public static let shared = PinsViewModel()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "PinsViewModel")

    // MARK: - Published State

    @Published public private(set) var pins: [NatoPin] = []
    @Published public private(set) var linkedForms: [LinkedForm] = []

    // MARK: - Configuration

    private var myDeviceId: String = ""
    private var blockedDeviceIds: Set<String> = []

    // MARK: - Storage Keys

    private enum Keys {
        static let pins = "swetak_pins"
        static let linkedForms = "swetak_linked_forms"
    }

    // MARK: - Initialization

    private init() {
        loadFromStorage()
        setupListeners()
    }

    // MARK: - Listeners

    private func setupListeners() {
        TransportCoordinator.shared.pinListener = self
        TransportCoordinator.shared.linkedFormListener = self
    }

    // MARK: - Storage

    private func loadFromStorage() {
        // Load pins
        if let data = UserDefaults.standard.data(forKey: Keys.pins),
           let storedPins = try? JSONDecoder().decode([NatoPin].self, from: data) {
            pins = storedPins
            logger.info("Loaded \(storedPins.count) pins from storage")
        }

        // Load linked forms
        if let data = UserDefaults.standard.data(forKey: Keys.linkedForms),
           let storedForms = try? JSONDecoder().decode([LinkedForm].self, from: data) {
            linkedForms = storedForms
            logger.info("Loaded \(storedForms.count) linked forms from storage")
        }
    }

    private func savePins() {
        if let data = try? JSONEncoder().encode(pins) {
            UserDefaults.standard.set(data, forKey: Keys.pins)
        }
    }

    private func saveLinkedForms() {
        if let data = try? JSONEncoder().encode(linkedForms) {
            UserDefaults.standard.set(data, forKey: Keys.linkedForms)
        }
    }

    // MARK: - Configuration

    /// Start listening for pin updates
    public func startListening(deviceId: String, blockedDeviceIds: Set<String> = []) {
        myDeviceId = deviceId
        self.blockedDeviceIds = blockedDeviceIds
        logger.info("Started pin listener for device \(deviceId)")
    }

    /// Update blocked device IDs
    public func updateBlockedIds(_ blockedIds: Set<String>) {
        blockedDeviceIds = blockedIds
    }

    // MARK: - Pin CRUD Operations

    /// Add a new pin
    public func addPin(_ pin: NatoPin) {
        pins.append(pin)
        savePins()
        logger.debug("Added pin \(pin.id)")

        // Broadcast to network
        let deviceId = TransportCoordinator.shared.deviceId
        TransportCoordinator.shared.publishPin(pin)
    }

    /// Update an existing pin
    public func updatePin(_ pin: NatoPin) {
        if let index = pins.firstIndex(where: { $0.id == pin.id }) {
            pins[index] = pin
            savePins()
            logger.debug("Updated pin \(pin.id)")
        }
    }

    /// Delete a pin by ID
    public func deletePin(pinId: Int64) {
        pins.removeAll { $0.id == pinId }
        savePins()
        logger.debug("Deleted pin \(pinId)")

        // Broadcast deletion
        let deviceId = TransportCoordinator.shared.deviceId
        TransportCoordinator.shared.deletePin(pinId: pinId, originDeviceId: deviceId)
    }

    /// Get a pin by ID
    public func getPin(byId pinId: Int64) -> NatoPin? {
        pins.first { $0.id == pinId }
    }

    /// Generate a new unique pin ID
    public func generatePinId() -> Int64 {
        (pins.map { $0.id }.max() ?? 0) + 1
    }

    // MARK: - Linked Forms Operations

    /// Add a linked form
    public func addLinkedForm(_ form: LinkedForm) {
        // Check for duplicates
        if !linkedForms.contains(where: { $0.id == form.id && $0.opPinId == form.opPinId }) {
            linkedForms.append(form)
            saveLinkedForms()
            logger.debug("Added linked form \(form.id)")

            // Broadcast to network
            TransportCoordinator.shared.sendLinkedForm(form)
        }
    }

    /// Get linked forms for a pin
    public func getFormsForPin(pinId: Int64, originDeviceId: String) -> [LinkedForm] {
        linkedForms.filter { $0.opPinId == pinId && $0.opOriginDeviceId == originDeviceId }
    }

    /// Generate a new unique form ID
    public func generateFormId() -> Int64 {
        (linkedForms.map { $0.id }.max() ?? 0) + 1
    }

    // MARK: - Sync Operations

    /// Sync pins from external source
    public func syncPins(_ externalPins: [NatoPin]) {
        if pins != externalPins {
            pins = externalPins
            savePins()
            logger.debug("Synced \(externalPins.count) pins from external source")
        }
    }

    /// Sync linked forms from external source
    public func syncLinkedForms(_ externalForms: [LinkedForm]) {
        if linkedForms != externalForms {
            linkedForms = externalForms
            saveLinkedForms()
            logger.debug("Synced \(externalForms.count) linked forms from external source")
        }
    }

    // MARK: - Network Pin Handling

    private func handleIncomingPin(_ pin: NatoPin, fromDeviceId: String) {
        // Ignore our own pins
        guard fromDeviceId != myDeviceId else { return }

        // Check if sender is blocked
        guard !blockedDeviceIds.contains(fromDeviceId) else {
            logger.debug("Rejected pin from blocked device: \(fromDeviceId)")
            return
        }

        // Update or add pin
        if let index = pins.firstIndex(where: { $0.id == pin.id && $0.originDeviceId == pin.originDeviceId }) {
            pins[index] = pin
        } else {
            pins.append(pin)
        }
        savePins()

        logger.debug("Received pin \(pin.id) from \(fromDeviceId)")
    }
}

// MARK: - PinListener

extension PinsViewModel: PinListener {
    public func onPinReceived(pin: NatoPin) {
        DispatchQueue.main.async { [weak self] in
            self?.handleIncomingPin(pin, fromDeviceId: pin.originDeviceId)
        }
    }

    public func onPinDeleted(pinId: Int64, originDeviceId: String) {
        DispatchQueue.main.async { [weak self] in
            self?.pins.removeAll { $0.id == pinId && $0.originDeviceId == originDeviceId }
            self?.savePins()
            self?.logger.debug("Pin \(pinId) deleted by \(originDeviceId)")
        }
    }

    public func onPinRequestReceived(fromDeviceId: String) {
        // Respond with all our pins
        logger.debug("Pin request received from \(fromDeviceId)")
        // The response is handled by the transport layer
    }
}

// MARK: - LinkedFormListener

extension PinsViewModel: LinkedFormListener {
    public func onLinkedFormReceived(form: LinkedForm) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Check for duplicates
            if !self.linkedForms.contains(where: { $0.id == form.id && $0.opPinId == form.opPinId }) {
                self.linkedForms.append(form)
                self.saveLinkedForms()
                self.logger.debug("Received linked form \(form.id)")
            }
        }
    }
}
