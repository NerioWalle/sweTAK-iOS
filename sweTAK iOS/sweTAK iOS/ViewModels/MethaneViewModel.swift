import Foundation
import Combine
import os.log

/// ViewModel for managing METHANE emergency notification requests.
/// Mirrors Android's METHANE request management functionality.
public final class MethaneViewModel: ObservableObject {

    // MARK: - Singleton

    public static let shared = MethaneViewModel()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "MethaneViewModel")

    // MARK: - Published State

    @Published public private(set) var requests: [MethaneRequest] = []
    @Published public private(set) var recipientStatuses: [MethaneRecipientStatus] = []
    @Published public private(set) var unreadIncomingCount: Int = 0

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let methaneRequests = "swetak_methane_requests"
        static let methaneStatuses = "swetak_methane_statuses"
    }

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        loadRequests()
        loadStatuses()
        updateUnreadCount()
        setupListeners()
    }

    // MARK: - Listeners

    private func setupListeners() {
        TransportCoordinator.shared.methaneListener = self
    }

    // MARK: - Computed Properties

    public var incomingRequests: [MethaneRequest] {
        requests
            .filter { $0.direction == .incoming }
            .sorted { $0.createdAtMillis > $1.createdAtMillis }
    }

    public var outgoingRequests: [MethaneRequest] {
        requests
            .filter { $0.direction == .outgoing }
            .sorted { $0.createdAtMillis > $1.createdAtMillis }
    }

    // MARK: - Request Management

    /// Send a new METHANE request.
    public func sendMethaneRequest(_ request: MethaneRequest) {
        var outgoingRequest = request
        // Ensure direction is outgoing for sent requests
        if outgoingRequest.direction != .outgoing {
            outgoingRequest = MethaneRequest(
                id: request.id,
                createdAtMillis: request.createdAtMillis,
                senderDeviceId: request.senderDeviceId,
                senderCallsign: request.senderCallsign,
                callsign: request.callsign,
                unit: request.unit,
                incidentLocation: request.incidentLocation,
                incidentLatitude: request.incidentLatitude,
                incidentLongitude: request.incidentLongitude,
                incidentTime: request.incidentTime,
                incidentType: request.incidentType,
                hazards: request.hazards,
                approachRoutes: request.approachRoutes,
                hlsLocation: request.hlsLocation,
                hlsLatitude: request.hlsLatitude,
                hlsLongitude: request.hlsLongitude,
                casualtyCountP1: request.casualtyCountP1,
                casualtyCountP2: request.casualtyCountP2,
                casualtyCountP3: request.casualtyCountP3,
                casualtyCountDeceased: request.casualtyCountDeceased,
                casualtyDetails: request.casualtyDetails,
                assetsPresent: request.assetsPresent,
                assetsRequired: request.assetsRequired,
                recipientDeviceIds: request.recipientDeviceIds,
                direction: .outgoing,
                isRead: true
            )
        }

        // Add to local storage
        requests.append(outgoingRequest)
        saveRequests()

        // Create recipient statuses
        for recipientId in outgoingRequest.recipientDeviceIds {
            let status = MethaneRecipientStatus(
                methaneId: outgoingRequest.id,
                recipientDeviceId: recipientId,
                recipientCallsign: ContactsViewModel.shared.contacts.first { $0.deviceId == recipientId }?.callsign,
                sentAtMillis: Date.currentMillis
            )
            recipientStatuses.append(status)
        }
        saveStatuses()

        // Send via transport
        TransportCoordinator.shared.sendMethane(outgoingRequest)

        logger.info("Sent METHANE request: \(outgoingRequest.id) to \(outgoingRequest.recipientDeviceIds.count) recipients")
    }

    /// Add a received METHANE request.
    public func addReceivedRequest(_ request: MethaneRequest) {
        // Avoid duplicates
        guard !requests.contains(where: { $0.id == request.id }) else {
            logger.debug("Duplicate METHANE request received, ignoring: \(request.id)")
            return
        }

        // Create incoming request
        let incomingRequest = MethaneRequest(
            id: request.id,
            createdAtMillis: request.createdAtMillis,
            senderDeviceId: request.senderDeviceId,
            senderCallsign: request.senderCallsign,
            callsign: request.callsign,
            unit: request.unit,
            incidentLocation: request.incidentLocation,
            incidentLatitude: request.incidentLatitude,
            incidentLongitude: request.incidentLongitude,
            incidentTime: request.incidentTime,
            incidentType: request.incidentType,
            hazards: request.hazards,
            approachRoutes: request.approachRoutes,
            hlsLocation: request.hlsLocation,
            hlsLatitude: request.hlsLatitude,
            hlsLongitude: request.hlsLongitude,
            casualtyCountP1: request.casualtyCountP1,
            casualtyCountP2: request.casualtyCountP2,
            casualtyCountP3: request.casualtyCountP3,
            casualtyCountDeceased: request.casualtyCountDeceased,
            casualtyDetails: request.casualtyDetails,
            assetsPresent: request.assetsPresent,
            assetsRequired: request.assetsRequired,
            recipientDeviceIds: request.recipientDeviceIds,
            direction: .incoming,
            isRead: false
        )

        requests.append(incomingRequest)
        saveRequests()
        updateUnreadCount()

        // Send delivery ACK
        sendAck(requestId: incomingRequest.id, toDeviceId: incomingRequest.senderDeviceId, ackType: .delivered)

        logger.info("Received METHANE request: \(incomingRequest.id) from \(incomingRequest.senderCallsign)")
    }

    /// Mark a request as read.
    public func markAsRead(requestId: String) {
        guard let index = requests.firstIndex(where: { $0.id == requestId }) else { return }

        var request = requests[index]
        guard !request.isRead else { return }

        request.isRead = true
        requests[index] = request
        saveRequests()
        updateUnreadCount()

        // Send read ACK for incoming requests
        if request.direction == .incoming {
            sendAck(requestId: requestId, toDeviceId: request.senderDeviceId, ackType: .read)
        }

        logger.debug("Marked METHANE request as read: \(requestId)")
    }

    /// Delete a request.
    public func deleteRequest(requestId: String) {
        requests.removeAll { $0.id == requestId }
        recipientStatuses.removeAll { $0.methaneId == requestId }
        saveRequests()
        saveStatuses()
        updateUnreadCount()

        logger.debug("Deleted METHANE request: \(requestId)")
    }

    /// Get a request by ID.
    public func getRequest(id: String) -> MethaneRequest? {
        requests.first { $0.id == id }
    }

    /// Get recipient statuses for a request.
    public func getStatusesForRequest(requestId: String) -> [MethaneRecipientStatus] {
        recipientStatuses.filter { $0.methaneId == requestId }
    }

    // MARK: - ACK Handling

    private func sendAck(requestId: String, toDeviceId: String, ackType: MethaneAckType) {
        let ack = MethaneAck(
            methaneId: requestId,
            fromDeviceId: TransportCoordinator.shared.deviceId,
            toDeviceId: toDeviceId,
            ackType: ackType
        )
        TransportCoordinator.shared.sendMethaneAck(ack)
        logger.debug("Sent METHANE ACK: \(ackType.rawValue) for request \(requestId)")
    }

    /// Handle received ACK.
    public func handleReceivedAck(_ ack: MethaneAck) {
        guard let statusIndex = recipientStatuses.firstIndex(where: {
            $0.methaneId == ack.methaneId && $0.recipientDeviceId == ack.fromDeviceId
        }) else {
            logger.warning("Received ACK for unknown recipient status: \(ack.methaneId)")
            return
        }

        var status = recipientStatuses[statusIndex]

        switch ack.ackType {
        case .delivered:
            status.deliveredAtMillis = ack.timestampMillis
        case .read:
            status.readAtMillis = ack.timestampMillis
        }

        recipientStatuses[statusIndex] = status
        saveStatuses()

        logger.debug("Updated METHANE status: \(ack.ackType.rawValue) for request \(ack.methaneId)")
    }

    // MARK: - Persistence

    private func saveRequests() {
        do {
            let data = try JSONEncoder().encode(requests)
            UserDefaults.standard.set(data, forKey: Keys.methaneRequests)
        } catch {
            logger.error("Failed to save METHANE requests: \(error.localizedDescription)")
        }
    }

    private func loadRequests() {
        guard let data = UserDefaults.standard.data(forKey: Keys.methaneRequests) else { return }
        do {
            requests = try JSONDecoder().decode([MethaneRequest].self, from: data)
        } catch {
            logger.error("Failed to load METHANE requests: \(error.localizedDescription)")
        }
    }

    private func saveStatuses() {
        do {
            let data = try JSONEncoder().encode(recipientStatuses)
            UserDefaults.standard.set(data, forKey: Keys.methaneStatuses)
        } catch {
            logger.error("Failed to save METHANE statuses: \(error.localizedDescription)")
        }
    }

    private func loadStatuses() {
        guard let data = UserDefaults.standard.data(forKey: Keys.methaneStatuses) else { return }
        do {
            recipientStatuses = try JSONDecoder().decode([MethaneRecipientStatus].self, from: data)
        } catch {
            logger.error("Failed to load METHANE statuses: \(error.localizedDescription)")
        }
    }

    private func updateUnreadCount() {
        unreadIncomingCount = incomingRequests.filter { !$0.isRead }.count
    }

    // MARK: - Clear All

    public func clearAllRequests() {
        requests.removeAll()
        recipientStatuses.removeAll()
        saveRequests()
        saveStatuses()
        updateUnreadCount()
    }
}

// MARK: - MethaneListener

extension MethaneViewModel: MethaneListener {
    public func onMethaneReceived(methane: MethaneRequest) {
        DispatchQueue.main.async { [weak self] in
            self?.addReceivedRequest(methane)
        }
    }

    public func onMethaneAckReceived(ack: MethaneAck) {
        DispatchQueue.main.async { [weak self] in
            self?.handleReceivedAck(ack)
        }
    }
}
