import Foundation
import Combine
import os.log

// MARK: - Pin Add Event

/// Event representing a pin to be synced
public struct PinAddEvent: Equatable {
    public let id: Int64
    public let lat: Double
    public let lon: Double
    public let typeName: String
    public let title: String
    public let description: String
    public let createdAtMillis: Int64
    public let originDeviceId: String
    public let photoUri: String?

    public init(
        id: Int64,
        lat: Double,
        lon: Double,
        typeName: String,
        title: String,
        description: String,
        createdAtMillis: Int64,
        originDeviceId: String,
        photoUri: String? = nil
    ) {
        self.id = id
        self.lat = lat
        self.lon = lon
        self.typeName = typeName
        self.title = title
        self.description = description
        self.createdAtMillis = createdAtMillis
        self.originDeviceId = originDeviceId
        self.photoUri = photoUri
    }

    /// Create from NatoPin
    public init(from pin: NatoPin, deviceId: String) {
        self.id = pin.id
        self.lat = pin.latitude
        self.lon = pin.longitude
        self.typeName = pin.type.rawValue
        self.title = pin.title
        self.description = pin.description
        self.createdAtMillis = pin.createdAtMillis
        self.originDeviceId = pin.originDeviceId.isEmpty ? deviceId : pin.originDeviceId
        self.photoUri = pin.photoUri
    }
}

// MARK: - Pin Sync Coordinator

/// Coordinates pin and linked form synchronization across transports
/// Mirrors Android PinSyncCoordinator functionality
public final class PinSyncCoordinator {

    // MARK: - Singleton

    public static let shared = PinSyncCoordinator()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "PinSync")

    // MARK: - Providers

    /// Provider for local pins to sync
    public var provideLocalPins: (() -> [PinAddEvent])?

    /// Provider for local linked forms to sync
    public var provideLocalLinkedForms: (() -> [LinkedForm])?

    // MARK: - Callbacks

    /// Called when sync starts
    public var onSyncStarted: (() -> Void)?

    /// Called when sync completes
    public var onSyncCompleted: ((Int) -> Void)?  // Number of items synced

    /// Called on sync error
    public var onSyncError: ((String) -> Void)?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Sync all local pins over the current transport
    /// Called from UI when user chooses "Sync pins"
    public func syncAllPins(callsign: String, deviceId: String) {
        logger.info("syncAllPins() called with callsign=\(callsign) deviceId=\(deviceId)")

        guard let provider = provideLocalPins else {
            logger.warning("syncAllPins: provideLocalPins is nil – no pins to sync")
            onSyncError?("No pin provider configured")
            return
        }

        let pins = provider()
        let mode = TransportCoordinator.shared.activeMode

        logger.info("syncAllPins: mode=\(mode.rawValue) pinCount=\(pins.count)")

        if pins.isEmpty {
            logger.warning("syncAllPins: no local pins – aborting sync")
            onSyncCompleted?(0)
            return
        }

        onSyncStarted?()

        switch mode {
        case .mqtt:
            syncPinsOverMqtt(callsign: callsign, deviceId: deviceId, pins: pins)
        case .localUDP:
            syncPinsOverUdp(callsign: callsign, deviceId: deviceId, pins: pins)
        }

        onSyncCompleted?(pins.count)
    }

    /// Request all pins from the network
    /// Peers that receive the request will respond by sending their pins
    public func requestAllPinsFromNetwork(callsign: String, deviceId: String) {
        logger.info("requestAllPinsFromNetwork() called with callsign=\(callsign) deviceId=\(deviceId)")

        // Start accepting incoming pins for a limited time window
        PinsViewModel.shared.startAwaitingPinSync(timeoutSeconds: 30)

        // Send the pin request to the network
        TransportCoordinator.shared.requestAllPins(callsign: callsign)
    }

    /// Sync all linked forms over the current transport
    /// Called after syncing pins to ensure forms linked to OP pins are also shared
    public func syncAllLinkedForms(callsign: String, deviceId: String) {
        logger.info("syncAllLinkedForms() called with callsign=\(callsign) deviceId=\(deviceId)")

        guard let provider = provideLocalLinkedForms else {
            logger.warning("syncAllLinkedForms: provideLocalLinkedForms is nil – no forms to sync")
            return
        }

        let forms = provider()
        let mode = TransportCoordinator.shared.activeMode

        logger.info("syncAllLinkedForms: mode=\(mode.rawValue) formCount=\(forms.count)")

        if forms.isEmpty {
            logger.debug("syncAllLinkedForms: no local linked forms – nothing to sync")
            return
        }

        switch mode {
        case .mqtt:
            syncLinkedFormsOverMqtt(deviceId: deviceId, forms: forms)
        case .localUDP:
            syncLinkedFormsOverUdp(deviceId: deviceId, forms: forms)
        }
    }

    /// Full sync: pins + linked forms
    public func syncAll(callsign: String, deviceId: String) {
        syncAllPins(callsign: callsign, deviceId: deviceId)
        syncAllLinkedForms(callsign: callsign, deviceId: deviceId)
    }

    // MARK: - Private - MQTT Sync

    private func syncPinsOverMqtt(callsign: String, deviceId: String, pins: [PinAddEvent]) {
        for pin in pins {
            logger.debug("syncPinsOverMqtt: publishing pin id=\(pin.id) type=\(pin.typeName) title='\(pin.title)'")

            let natoPin = NatoPin(
                id: pin.id,
                latitude: pin.lat,
                longitude: pin.lon,
                type: NatoType(rawValue: pin.typeName) ?? .infantry,
                title: pin.title,
                description: pin.description,
                createdAtMillis: pin.createdAtMillis,
                originDeviceId: pin.originDeviceId.isEmpty ? deviceId : pin.originDeviceId,
                photoUri: pin.photoUri
            )

            TransportCoordinator.shared.publishPin(natoPin)
        }
    }

    private func syncLinkedFormsOverMqtt(deviceId: String, forms: [LinkedForm]) {
        for form in forms {
            logger.debug("syncLinkedFormsOverMqtt: publishing form id=\(form.id) opPinId=\(form.opPinId) formType=\(form.formType)")

            TransportCoordinator.shared.sendLinkedForm(form)
        }
    }

    // MARK: - Private - UDP Sync

    private func syncPinsOverUdp(callsign: String, deviceId: String, pins: [PinAddEvent]) {
        for pin in pins {
            logger.debug("syncPinsOverUdp: publishing pin id=\(pin.id) type=\(pin.typeName) title='\(pin.title)'")

            let natoPin = NatoPin(
                id: pin.id,
                latitude: pin.lat,
                longitude: pin.lon,
                type: NatoType(rawValue: pin.typeName) ?? .infantry,
                title: pin.title,
                description: pin.description,
                createdAtMillis: pin.createdAtMillis,
                originDeviceId: pin.originDeviceId.isEmpty ? deviceId : pin.originDeviceId,
                photoUri: pin.photoUri
            )

            UDPClientManager.shared.publishPin(natoPin, deviceId: deviceId, callsign: callsign)
        }
    }

    private func syncLinkedFormsOverUdp(deviceId: String, forms: [LinkedForm]) {
        for form in forms {
            logger.debug("syncLinkedFormsOverUdp: publishing form id=\(form.id) opPinId=\(form.opPinId) formType=\(form.formType)")

            UDPClientManager.shared.publishLinkedForm(form, deviceId: deviceId)
        }
    }
}

// MARK: - Convenience Extensions

extension PinSyncCoordinator {

    /// Setup pin provider from PinsViewModel
    public func configurePinProvider(_ provider: @escaping () -> [NatoPin], deviceId: String) {
        provideLocalPins = {
            provider().map { PinAddEvent(from: $0, deviceId: deviceId) }
        }
    }

    /// Setup linked form provider
    public func configureLinkedFormProvider(_ provider: @escaping () -> [LinkedForm]) {
        provideLocalLinkedForms = provider
    }
}
