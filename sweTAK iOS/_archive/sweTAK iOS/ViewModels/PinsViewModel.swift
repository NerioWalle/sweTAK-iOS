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

    // MARK: - Sync State

    /// Flag to track when we've explicitly requested pins from the network
    /// Only accept incoming pins when this is true
    private var awaitingPinSync: Bool = false
    private var syncTimeoutTask: DispatchWorkItem?

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

    /// Clear all pins
    public func clearAllPins() {
        pins.removeAll()
        savePins()
        logger.debug("Cleared all pins")
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

    // MARK: - Pin Sync Request Management

    /// Call this when requesting pins from the network
    /// Opens a window to accept incoming pins for a limited time
    public func startAwaitingPinSync(timeoutSeconds: Double = 30) {
        logger.info("Starting pin sync window (timeout: \(timeoutSeconds)s)")
        awaitingPinSync = true

        // Cancel any existing timeout
        syncTimeoutTask?.cancel()

        // Set up new timeout to close the sync window
        let task = DispatchWorkItem { [weak self] in
            self?.stopAwaitingPinSync()
        }
        syncTimeoutTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds, execute: task)
    }

    /// Stop accepting incoming pins from the network
    public func stopAwaitingPinSync() {
        if awaitingPinSync {
            logger.info("Closing pin sync window")
            awaitingPinSync = false
            syncTimeoutTask?.cancel()
            syncTimeoutTask = nil
        }
    }

    /// Check if we're currently accepting pins from the network
    public var isAwaitingPinSync: Bool {
        awaitingPinSync
    }

    /// Send all our pins to the network (response to a pin request)
    public func respondToPinRequest(callsign: String) {
        let pinCount = self.pins.count
        logger.info("Responding to pin request with \(pinCount) pins")

        for pin in self.pins {
            TransportCoordinator.shared.publishPin(pin)
        }
    }

    // MARK: - Network Pin Handling

    private func handleIncomingPin(_ pin: NatoPin, fromDeviceId: String) {
        // Ignore our own pins (but allow if originDeviceId is empty - legacy pins)
        if !fromDeviceId.isEmpty && fromDeviceId == myDeviceId {
            logger.debug("Ignoring our own pin \(pin.id)")
            return
        }

        // Check if sender is blocked
        guard !blockedDeviceIds.contains(fromDeviceId) else {
            logger.debug("Rejected pin from blocked device: \(fromDeviceId)")
            return
        }

        // Always accept pins from the network (like Android does)
        // Update or add pin
        if let index = pins.firstIndex(where: { $0.id == pin.id && $0.originDeviceId == pin.originDeviceId }) {
            pins[index] = pin
            logger.debug("Updated pin \(pin.id) from \(fromDeviceId)")
        } else {
            pins.append(pin)
            logger.info("Added new pin \(pin.id) from \(fromDeviceId) - type: \(pin.type.rawValue)")
        }
        savePins()
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
        // Ignore our own requests
        guard fromDeviceId != myDeviceId else { return }

        let pinCount = self.pins.count
        logger.info("Pin request received from \(fromDeviceId) - sending \(pinCount) pins")

        // Respond with all our pins
        let callsign = SettingsViewModel.shared.callsign
        respondToPinRequest(callsign: callsign)
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
