import Foundation
import os.log

// MARK: - Tactical Dispatcher

/// High-level dispatcher for tactical operations
/// Provides simple API for common tactical broadcasts
/// Mirrors Android TacDispatcher functionality
public enum TacDispatcher {

    // MARK: - Logger

    private static let logger = Logger(subsystem: "com.swetak", category: "TacDispatcher")

    // MARK: - Position Broadcasting

    /// Broadcast current position to all peers
    public static func broadcastMyPosition(deviceId: String, latitude: Double, longitude: Double) {
        let callsign = LocalProfileStore.shared.resolveCallsign()

        logger.debug("Broadcasting position: \(latitude), \(longitude) as \(callsign)")

        TransportCoordinator.shared.publishPosition(
            callsign: callsign,
            latitude: latitude,
            longitude: longitude
        )
    }

    /// Broadcast position with altitude and heading
    public static func broadcastMyPosition(
        deviceId: String,
        latitude: Double,
        longitude: Double,
        altitude: Double?,
        heading: Double?
    ) {
        let callsign = LocalProfileStore.shared.resolveCallsign()

        logger.debug("Broadcasting position: \(latitude), \(longitude) alt=\(altitude ?? 0) hdg=\(heading ?? 0) as \(callsign)")

        // Base position broadcast
        TransportCoordinator.shared.publishPosition(
            callsign: callsign,
            latitude: latitude,
            longitude: longitude
        )

        // Extended position info could be added to a custom message type
    }

    // MARK: - Pin Operations

    /// Send a tactical pin to all peers
    public static func sendPin(
        deviceId: String,
        id: Int64,
        latitude: Double,
        longitude: Double,
        natoType: String,
        title: String,
        description: String,
        createdAtMillis: Int64,
        photoBase64: String? = nil
    ) {
        let callsign = LocalProfileStore.shared.resolveCallsign()

        logger.debug("Sending pin: id=\(id) type=\(natoType) title='\(title)'")

        let pin = NatoPin(
            id: id,
            type: NatoPinType(rawValue: natoType) ?? .friendlyUnit,
            latitude: latitude,
            longitude: longitude,
            title: title,
            description: description,
            createdAtMillis: createdAtMillis,
            originDeviceId: deviceId,
            photoBase64: photoBase64
        )

        TransportCoordinator.shared.publishPin(pin)
    }

    /// Send a NatoPin directly
    public static func sendPin(_ pin: NatoPin) {
        logger.debug("Sending pin: id=\(pin.id) type=\(pin.type.rawValue)")
        TransportCoordinator.shared.publishPin(pin)
    }

    /// Delete a pin from all peers
    public static func deletePin(pinId: Int64, originDeviceId: String) {
        logger.debug("Deleting pin: id=\(pinId)")
        TransportCoordinator.shared.deletePin(pinId: pinId, originDeviceId: originDeviceId)
    }

    /// Request all pins from the network
    public static func requestAllPins(deviceId: String) {
        let callsign = LocalProfileStore.shared.resolveCallsign()

        logger.debug("Requesting all pins as \(callsign)")

        TransportCoordinator.shared.requestAllPins(callsign: callsign)
    }

    // MARK: - Profile Operations

    /// Publish local profile to all peers
    public static func publishMyProfile(deviceId: String) {
        let profile = LocalProfileStore.shared.load()
        let callsign = profile.callsign.trimmingCharacters(in: .whitespaces).isEmpty
            ? LocalProfileStore.shared.resolveCallsign()
            : profile.callsign

        logger.debug("Publishing profile as \(callsign)")

        TransportCoordinator.shared.publishProfile(profile)
    }

    /// Publish a ContactProfile
    public static func publishProfile(_ profile: ContactProfile) {
        logger.debug("Publishing contact profile: \(profile.displayName)")
        TransportCoordinator.shared.publishProfile(profile)
    }

    // MARK: - Discovery

    /// Send hello/discovery message
    public static func sendHello(deviceId: String) {
        let callsign = LocalProfileStore.shared.resolveCallsign()

        logger.debug("Sending hello as \(callsign)")

        TransportCoordinator.shared.sendHello(callsign: callsign)
    }

    /// Refresh peer discovery (hello + profile request)
    public static func refreshPeerDiscovery(deviceId: String) {
        let callsign = LocalProfileStore.shared.resolveCallsign()

        logger.debug("Refreshing peer discovery as \(callsign)")

        TransportCoordinator.shared.refreshPeerDiscovery(callsign: callsign)
    }

    // MARK: - Chat Operations

    /// Send a chat message
    public static func sendChatMessage(
        threadId: String,
        fromDeviceId: String,
        toDeviceId: String,
        text: String
    ) {
        logger.debug("Sending chat to \(toDeviceId): \(text.prefix(50))")

        let message = ChatMessage(
            threadId: threadId,
            fromDeviceId: fromDeviceId,
            toDeviceId: toDeviceId,
            text: text,
            timestampMillis: Date.currentMillis,
            direction: .outgoing
        )

        TransportCoordinator.shared.sendChat(message)
    }

    // MARK: - Orders

    /// Send a military order
    public static func sendOrder(_ order: Order) {
        logger.debug("Sending order: \(order.id) type=\(order.type.rawValue)")
        TransportCoordinator.shared.sendOrder(order)
    }

    /// Send order acknowledgment
    public static func sendOrderAck(orderId: String, toDeviceId: String, ackType: OrderAckType) {
        let deviceId = TransportCoordinator.shared.deviceId

        let ack = OrderAck(
            orderId: orderId,
            fromDeviceId: deviceId,
            toDeviceId: toDeviceId,
            ackType: ackType,
            timestampMillis: Date.currentMillis
        )

        TransportCoordinator.shared.sendOrderAck(ack)
    }

    // MARK: - Reports

    /// Send a status report
    public static func sendReport(_ report: Report) {
        logger.debug("Sending report: \(report.id)")
        TransportCoordinator.shared.sendReport(report)
    }

    /// Send report acknowledgment
    public static func sendReportAck(reportId: String, toDeviceId: String, ackType: ReportAckType) {
        let deviceId = TransportCoordinator.shared.deviceId

        let ack = ReportAck(
            reportId: reportId,
            fromDeviceId: deviceId,
            toDeviceId: toDeviceId,
            ackType: ackType,
            timestampMillis: Date.currentMillis
        )

        TransportCoordinator.shared.sendReportAck(ack)
    }

    // MARK: - METHANE

    /// Send a METHANE emergency request
    public static func sendMethane(_ methane: MethaneRequest) {
        logger.debug("Sending METHANE: \(methane.id)")
        TransportCoordinator.shared.sendMethane(methane)
    }

    /// Send METHANE acknowledgment
    public static func sendMethaneAck(methaneId: String, toDeviceId: String, ackType: MethaneAckType) {
        let deviceId = TransportCoordinator.shared.deviceId

        let ack = MethaneAck(
            methaneId: methaneId,
            fromDeviceId: deviceId,
            toDeviceId: toDeviceId,
            ackType: ackType,
            timestampMillis: Date.currentMillis
        )

        TransportCoordinator.shared.sendMethaneAck(ack)
    }

    // MARK: - MEDEVAC

    /// Send a MEDEVAC report
    public static func sendMedevac(_ medevac: MedevacReport) {
        logger.debug("Sending MEDEVAC: \(medevac.id)")
        TransportCoordinator.shared.sendMedevac(medevac)
    }

    /// Send MEDEVAC acknowledgment
    public static func sendMedevacAck(medevacId: String, toDeviceId: String, ackType: MedevacAckType) {
        let deviceId = TransportCoordinator.shared.deviceId

        let ack = MedevacAck(
            medevacId: medevacId,
            fromDeviceId: deviceId,
            toDeviceId: toDeviceId,
            ackType: ackType,
            timestampMillis: Date.currentMillis
        )

        TransportCoordinator.shared.sendMedevacAck(ack)
    }

    // MARK: - Linked Forms

    /// Send a linked form
    public static func sendLinkedForm(_ form: LinkedForm) {
        logger.debug("Sending linked form: \(form.formType) for pin \(form.opPinId)")
        TransportCoordinator.shared.sendLinkedForm(form)
    }

    // MARK: - Sync All

    /// Perform a full tactical sync
    /// - Sends hello
    /// - Publishes profile
    /// - Syncs all pins
    /// - Syncs all linked forms
    public static func performFullSync(deviceId: String) {
        let callsign = LocalProfileStore.shared.resolveCallsign()

        logger.info("Performing full tactical sync as \(callsign)")

        // 1. Send discovery hello
        sendHello(deviceId: deviceId)

        // 2. Publish profile
        publishMyProfile(deviceId: deviceId)

        // 3. Sync pins and forms
        PinSyncCoordinator.shared.syncAll(callsign: callsign, deviceId: deviceId)

        // 4. Request pins from others
        requestAllPins(deviceId: deviceId)
    }
}

// MARK: - Convenience Wrappers

extension TacDispatcher {

    /// Get current device ID
    public static var deviceId: String {
        TransportCoordinator.shared.deviceId
    }

    /// Get current callsign
    public static var callsign: String {
        LocalProfileStore.shared.resolveCallsign()
    }

    /// Check if connected
    public static var isConnected: Bool {
        TransportCoordinator.shared.connectionState == .connected
    }

    /// Current transport mode
    public static var transportMode: TransportMode {
        TransportCoordinator.shared.activeMode
    }
}
