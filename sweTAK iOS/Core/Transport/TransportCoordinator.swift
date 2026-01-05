import Foundation
import Combine
import os.log

/// Coordinates message routing between UDP and MQTT transports.
/// This is the main entry point for all network operations.
public final class TransportCoordinator: ObservableObject {

    // MARK: - Singleton

    public static let shared = TransportCoordinator()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "TransportCoordinator")

    // MARK: - Published State

    @Published public private(set) var activeMode: TransportMode = .localUDP
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    @Published public private(set) var deviceId: String = ""

    // MARK: - Listeners

    public weak var positionListener: PositionListener?
    public weak var pinListener: PinListener?
    public weak var profileListener: ProfileListener?
    public weak var chatListener: ChatListener?
    public weak var orderListener: OrderListener?
    public weak var reportListener: ReportListener?
    public weak var methaneListener: MethaneListener?
    public weak var medevacListener: MedevacListener?
    public weak var linkedFormListener: LinkedFormListener?
    public weak var helloListener: HelloListener?

    // MARK: - Configuration

    public var udpConfiguration = UDPConfiguration()
    public var mqttConfiguration = MQTTConfiguration()

    // MARK: - Private Properties

    private var udpTransport: TransportProtocol?
    private var mqttTransport: TransportProtocol?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        // Generate device ID on first launch
        loadOrGenerateDeviceId()
    }

    private func loadOrGenerateDeviceId() {
        let key = "swetak.device.id"
        if let existingId = UserDefaults.standard.string(forKey: key) {
            deviceId = existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: key)
            deviceId = newId
        }
    }

    // MARK: - Transport Management

    public func setMode(_ mode: TransportMode) {
        logger.info("setMode() called: requested=\(mode.rawValue) current=\(self.activeMode.rawValue)")

        guard mode != activeMode else {
            logger.info("setMode() - mode already set, skipping")
            return
        }

        // Stop current transport
        logger.info("Stopping current transport...")
        stopCurrentTransport()

        activeMode = mode
        logger.info("activeMode changed to: \(mode.rawValue)")

        // Start new transport
        logger.info("Starting new transport...")
        startCurrentTransport()
    }

    public func start() {
        startCurrentTransport()
    }

    public func stop() {
        stopCurrentTransport()
    }

    private func startCurrentTransport() {
        switch activeMode {
        case .localUDP:
            startUDP()
        case .mqtt:
            startMQTT()
        }
    }

    private func stopCurrentTransport() {
        udpTransport?.stop()
        mqttTransport?.stop()
        connectionState = .disconnected
    }

    private func startUDP() {
        // Configure and start UDP transport
        let udp = UDPClientManager.shared
        udp.configure(with: udpConfiguration)

        // Set up profile provider
        udp.provideLocalProfile = { [weak self] in
            // This should be provided by the UI layer
            guard let deviceId = self?.deviceId else {
                return ContactProfile(deviceId: "", callsign: "Unknown")
            }
            return ContactProfile(deviceId: deviceId, callsign: "Unknown")
        }

        // Subscribe to UDP connection state changes
        udp.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.connectionState = connected ? .connected : .disconnected
            }
            .store(in: &cancellables)

        udpTransport = udp
        connectionState = .connecting
        udp.start()
    }

    private func startMQTT() {
        logger.info("startMQTT() called - config valid: \(self.mqttConfiguration.isValid), host: \(self.mqttConfiguration.host)")

        guard mqttConfiguration.isValid else {
            logger.error("startMQTT() - invalid MQTT configuration!")
            connectionState = .error("Invalid MQTT configuration")
            return
        }

        // Configure and start MQTT transport
        logger.info("Configuring MQTTClientManager...")
        let mqtt = MQTTClientManager.shared
        mqtt.configure(with: mqttConfiguration)

        // Subscribe to MQTT connection state changes (full state, not just boolean)
        mqtt.connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.logger.info("MQTT connection state update: \(String(describing: state))")
                self?.connectionState = state
            }
            .store(in: &cancellables)

        mqttTransport = mqtt
        connectionState = .connecting
        mqtt.start()
    }

    // MARK: - Message Publishing

    /// Publish position update
    public func publishPosition(callsign: String, latitude: Double, longitude: Double) {
        let payload: [String: Any] = [
            "callsign": callsign,
            "lat": latitude,
            "lon": longitude
        ]

        let message = NetworkMessage(
            type: .position,
            deviceId: deviceId,
            payload: payload
        )

        sendMessage(message)
    }

    /// Publish tactical pin
    public func publishPin(_ pin: NatoPin) {
        let message = NetworkMessage(
            type: .pin,
            deviceId: deviceId,
            payload: pin.toJSON()
        )

        sendMessage(message)
    }

    /// Delete tactical pin
    public func deletePin(pinId: Int64, originDeviceId: String) {
        let payload: [String: Any] = [
            "id": pinId,
            "originDeviceId": originDeviceId
        ]

        let message = NetworkMessage(
            type: .pinDelete,
            deviceId: deviceId,
            payload: payload
        )

        sendMessage(message)
    }

    /// Request all pins from network
    /// Opens a sync window to accept incoming pins for 30 seconds
    public func requestAllPins(callsign: String) {
        // Open sync window to accept incoming pins
        PinsViewModel.shared.startAwaitingPinSync(timeoutSeconds: 30)

        let payload: [String: Any] = [
            "callsign": callsign
        ]

        let message = NetworkMessage(
            type: .pinRequest,
            deviceId: deviceId,
            payload: payload
        )

        sendMessage(message)
    }

    /// Publish profile update
    public func publishProfile(_ profile: ContactProfile) {
        let message = NetworkMessage(
            type: .profile,
            deviceId: deviceId,
            payload: profile.toJSON()
        )

        sendMessage(message)
    }

    /// Publish local profile update
    public func publishProfile(_ profile: LocalProfile) {
        // Convert LocalProfile to ContactProfile format
        let contactProfile = ContactProfile(
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

        publishProfile(contactProfile)
    }

    /// Send hello/discovery message
    public func sendHello(callsign: String) {
        let payload: [String: Any] = [
            "callsign": callsign
        ]

        let message = NetworkMessage(
            type: .hello,
            deviceId: deviceId,
            payload: payload
        )

        sendMessage(message)
    }

    /// Send chat message
    public func sendChat(_ chatMessage: ChatMessage) {
        let payload: [String: Any] = [
            "id": chatMessage.id,
            "threadId": chatMessage.threadId,
            "fromDeviceId": chatMessage.fromDeviceId,
            "toDeviceId": chatMessage.toDeviceId,
            "text": chatMessage.text,
            "timestampMillis": chatMessage.timestampMillis
        ]

        let message = NetworkMessage(
            type: .chat,
            deviceId: deviceId,
            payload: payload
        )

        sendMessage(message, to: [chatMessage.toDeviceId])
    }

    /// Send chat acknowledgment
    public func sendChatAck(_ ack: ChatAck) {
        let payload: [String: Any] = [
            "messageId": ack.messageId,
            "fromDeviceId": ack.fromDeviceId,
            "toDeviceId": ack.toDeviceId,
            "timestampMillis": ack.timestampMillis
        ]

        let message = NetworkMessage(
            type: .chatAck,
            deviceId: deviceId,
            payload: payload
        )

        sendMessage(message, to: [ack.toDeviceId])
    }

    /// Send order
    public func sendOrder(_ order: Order) {
        let encoder = JSONEncoder()
        guard let orderData = try? encoder.encode(order),
              let orderDict = try? JSONSerialization.jsonObject(with: orderData) as? [String: Any] else {
            return
        }

        let message = NetworkMessage(
            type: .order,
            deviceId: deviceId,
            payload: orderDict
        )

        sendMessage(message, to: order.recipientDeviceIds)
    }

    /// Send order acknowledgment
    public func sendOrderAck(_ ack: OrderAck) {
        let payload: [String: Any] = [
            "orderId": ack.orderId,
            "fromDeviceId": ack.fromDeviceId,
            "toDeviceId": ack.toDeviceId,
            "ackType": ack.ackType.rawValue,
            "timestampMillis": ack.timestampMillis
        ]

        let message = NetworkMessage(
            type: .orderAck,
            deviceId: deviceId,
            payload: payload
        )

        sendMessage(message, to: [ack.toDeviceId])
    }

    /// Send report
    /// Uses Android-compatible field names for cross-platform compatibility
    public func sendReport(_ report: Report) {
        // Manually construct payload with Android-compatible field names
        let payload: [String: Any] = [
            "reportId": report.id,
            "fromDeviceId": report.senderDeviceId,
            "fromCallsign": report.senderCallsign,
            "toDeviceIds": report.recipientDeviceIds,
            "createdAtMillis": report.createdAtMillis,
            "woundedCount": report.woundedCount,
            "deadCount": report.deadCount,
            "capableCount": report.capableCount,
            "replenishment": report.replenishment,
            "fuel": report.fuel,
            "ammunition": report.ammunition,
            "equipment": report.equipment,
            "readiness": report.readiness.rawValue,
            "readinessDetails": report.readinessDetails
        ]

        let message = NetworkMessage(
            type: .report,
            deviceId: deviceId,
            payload: payload
        )

        sendMessage(message, to: report.recipientDeviceIds)
    }

    /// Send report acknowledgment
    public func sendReportAck(_ ack: ReportAck) {
        let payload: [String: Any] = [
            "reportId": ack.reportId,
            "fromDeviceId": ack.fromDeviceId,
            "toDeviceId": ack.toDeviceId,
            "ackType": ack.ackType.rawValue,
            "timestampMillis": ack.timestampMillis
        ]

        let message = NetworkMessage(
            type: .reportAck,
            deviceId: deviceId,
            payload: payload
        )

        sendMessage(message, to: [ack.toDeviceId])
    }

    /// Send METHANE request
    /// Uses Android-compatible field names for cross-platform compatibility
    public func sendMethane(_ methane: MethaneRequest) {
        // Manually construct payload with Android-compatible field names
        // Note: Android expects "requestId" not "methaneId"
        var payload: [String: Any] = [
            "requestId": methane.id,
            "fromDeviceId": methane.senderDeviceId,
            "fromCallsign": methane.senderCallsign,
            "toDeviceIds": methane.recipientDeviceIds,
            "createdAtMillis": methane.createdAtMillis,
            // M - Military (callsign and unit)
            "callsign": methane.callsign,
            "unit": methane.unit,
            // E - Exact location (Android expects incidentLocation, incidentLatitude, incidentLongitude)
            "incidentLocation": methane.incidentLocation,
            // T - Time and type
            "incidentType": methane.incidentType,
            "incidentTime": methane.incidentTime,
            // H - Hazards
            "hazards": methane.hazards,
            // A - Approach routes and HLS (Android expects approachRoutes, hlsLocation, hlsLatitude, hlsLongitude)
            "approachRoutes": methane.approachRoutes,
            "hlsLocation": methane.hlsLocation,
            // N - Numbers (Android expects casualtyCountP1, casualtyCountP2, casualtyCountP3, casualtyCountDeceased)
            "casualtyCountP1": methane.casualtyCountP1,
            "casualtyCountP2": methane.casualtyCountP2,
            "casualtyCountP3": methane.casualtyCountP3,
            "casualtyCountDeceased": methane.casualtyCountDeceased,
            "casualtyDetails": methane.casualtyDetails,
            // E - Emergency services (assets)
            "assetsPresent": methane.assetsPresent,
            "assetsRequired": methane.assetsRequired
        ]

        // Add optional coordinates only if present
        if let lat = methane.incidentLatitude {
            payload["incidentLatitude"] = lat
        }
        if let lon = methane.incidentLongitude {
            payload["incidentLongitude"] = lon
        }
        if let hlsLat = methane.hlsLatitude {
            payload["hlsLatitude"] = hlsLat
        }
        if let hlsLon = methane.hlsLongitude {
            payload["hlsLongitude"] = hlsLon
        }

        let message = NetworkMessage(
            type: .methane,
            deviceId: deviceId,
            payload: payload
        )

        sendMessage(message, to: methane.recipientDeviceIds)
    }

    /// Send METHANE acknowledgment
    public func sendMethaneAck(_ ack: MethaneAck) {
        let payload: [String: Any] = [
            "methaneId": ack.methaneId,
            "fromDeviceId": ack.fromDeviceId,
            "toDeviceId": ack.toDeviceId,
            "ackType": ack.ackType.rawValue,
            "timestampMillis": ack.timestampMillis
        ]

        let message = NetworkMessage(
            type: .methaneAck,
            deviceId: deviceId,
            payload: payload
        )

        sendMessage(message, to: [ack.toDeviceId])
    }

    /// Send MEDEVAC report
    /// Uses Android-compatible field names for cross-platform compatibility
    public func sendMedevac(_ medevac: MedevacReport) {
        // Manually construct payload with Android-compatible field names
        let payload: [String: Any] = [
            "reportId": medevac.id,
            "fromDeviceId": medevac.senderDeviceId,
            "fromCallsign": medevac.senderCallsign,
            "toDeviceIds": medevac.recipientDeviceIds,
            "createdAtMillis": medevac.createdAtMillis,
            "soldierName": medevac.soldierName,
            "priority": medevac.priority.rawValue,
            "ageInfo": medevac.ageInfo,
            "incidentTime": medevac.incidentTime,
            "mechanismOfInjury": medevac.mechanismOfInjury,
            "injuryDescription": medevac.injuryDescription,
            "signsSymptoms": medevac.signsSymptoms,
            "pulse": medevac.pulse,
            "bodyTemperature": medevac.bodyTemperature,
            "treatmentActions": medevac.treatmentActions,
            "medicinesGiven": medevac.medicinesGiven,
            "caretakerName": medevac.caretakerName
        ]

        let message = NetworkMessage(
            type: .medevac,
            deviceId: deviceId,
            payload: payload
        )

        sendMessage(message, to: medevac.recipientDeviceIds)
    }

    /// Send MEDEVAC acknowledgment
    public func sendMedevacAck(_ ack: MedevacAck) {
        let payload: [String: Any] = [
            "medevacId": ack.medevacId,
            "fromDeviceId": ack.fromDeviceId,
            "toDeviceId": ack.toDeviceId,
            "ackType": ack.ackType.rawValue,
            "timestampMillis": ack.timestampMillis
        ]

        let message = NetworkMessage(
            type: .medevacAck,
            deviceId: deviceId,
            payload: payload
        )

        sendMessage(message, to: [ack.toDeviceId])
    }

    /// Send linked form
    public func sendLinkedForm(_ form: LinkedForm) {
        let encoder = JSONEncoder()
        guard let formData = try? encoder.encode(form),
              let formDict = try? JSONSerialization.jsonObject(with: formData) as? [String: Any] else {
            return
        }

        let message = NetworkMessage(
            type: .linkedForm,
            deviceId: deviceId,
            payload: formDict
        )

        sendMessage(message)
    }

    // MARK: - Peer Discovery Methods

    /// Refresh peer discovery for both UDP and MQTT modes
    /// Sends profile request to discover peers and publishes own profile
    public func refreshPeerDiscovery(callsign: String) {
        switch activeMode {
        case .localUDP:
            // Send hello to announce ourselves
            UDPClientManager.shared.sendHello(callsign: callsign, deviceId: deviceId)
            // Broadcast profile request to discover all peers
            UDPClientManager.shared.broadcastProfileRequest(callsign: callsign, deviceId: deviceId)
            // Also publish our own profile so others know about us
            if let myProfile = ContactsViewModel.shared.myProfile {
                UDPClientManager.shared.publishProfile(myProfile, deviceId: deviceId)
            }

        case .mqtt:
            // Publish profile request to MQTT topic
            MQTTClientManager.shared.publishProfileRequest(deviceId: deviceId, callsign: callsign)
            // Also publish our own profile so others know about us
            if let myProfile = ContactsViewModel.shared.myProfile {
                MQTTClientManager.shared.publishProfile(myProfile, deviceId: deviceId)
            }
        }
    }

    // MARK: - UDP-Specific Methods

    /// Set known UDP peers for direct communication
    public func setUDPPeers(_ addresses: Set<String>) {
        UDPClientManager.shared.setPeers(addresses)
    }

    /// Add a UDP peer address
    public func addUDPPeer(_ address: String) {
        UDPClientManager.shared.addPeer(address)
    }

    /// Remove a UDP peer address
    public func removeUDPPeer(_ address: String) {
        UDPClientManager.shared.removePeer(address)
    }

    /// Check if UDP transport is active
    public var isUDPActive: Bool {
        activeMode == .localUDP && connectionState == .connected
    }

    /// Check if MQTT transport is active
    public var isMQTTActive: Bool {
        activeMode == .mqtt && connectionState == .connected
    }

    // MARK: - Private Send

    private func sendMessage(_ message: NetworkMessage, to recipients: [String]? = nil) {
        logger.info("sendMessage: type=\(message.type.rawValue) activeMode=\(self.activeMode.rawValue) connected=\(self.connectionState.isConnected)")

        switch activeMode {
        case .localUDP:
            // Use UDPClientManager which handles broadcast + unicast
            logger.debug("Sending via UDP")
            UDPClientManager.shared.send(message: message, to: recipients)
        case .mqtt:
            // Use MQTTClientManager which handles topic routing internally
            logger.info("Sending via MQTT to topic: \(MQTTTopic.topic(for: message.type))")
            MQTTClientManager.shared.send(message: message, to: recipients)
        }
    }

    // MARK: - Message Handling

    internal func handleReceivedMessage(_ message: NetworkMessage, fromHost: String?) {
        // Ignore messages from self
        guard message.deviceId != deviceId else { return }

        switch message.type {
        case .position:
            handlePosition(message.payload, deviceId: message.deviceId)

        case .pin:
            handlePin(message.payload)

        case .pinDelete:
            handlePinDelete(message.payload)

        case .pinRequest:
            handlePinRequest(message.deviceId, payload: message.payload)

        case .profile:
            handleProfile(message.payload, deviceId: message.deviceId, fromHost: fromHost)

        case .hello:
            handleHello(message.deviceId, payload: message.payload, fromHost: fromHost)

        case .chat:
            handleChat(message.payload)

        case .chatAck:
            handleChatAck(message.payload)

        case .order:
            handleOrder(message.payload)

        case .orderAck:
            handleOrderAck(message.payload)

        case .report:
            handleReport(message.payload)

        case .reportAck:
            handleReportAck(message.payload)

        case .methane:
            handleMethane(message.payload)

        case .methaneAck:
            handleMethaneAck(message.payload)

        case .medevac:
            handleMedevac(message.payload)

        case .medevacAck:
            handleMedevacAck(message.payload)

        case .linkedForm:
            handleLinkedForm(message.payload)

        case .photo:
            // Photo handling will be implemented with pins
            break
        }
    }

    // MARK: - Message Handlers

    private func handlePosition(_ payload: [String: Any], deviceId: String) {
        guard let callsign = payload["callsign"] as? String,
              let lat = payload["lat"] as? Double,
              let lon = payload["lon"] as? Double else { return }

        DispatchQueue.main.async { [weak self] in
            self?.positionListener?.onPositionReceived(
                deviceId: deviceId,
                callsign: callsign,
                latitude: lat,
                longitude: lon
            )
        }
    }

    private func handlePin(_ payload: [String: Any]) {
        guard let pin = NatoPin.fromJSON(payload) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.pinListener?.onPinReceived(pin: pin)
        }
    }

    private func handlePinDelete(_ payload: [String: Any]) {
        guard let pinId = payload["id"] as? Int64 ?? (payload["id"] as? Int).map({ Int64($0) }),
              let originDeviceId = payload["originDeviceId"] as? String else { return }

        DispatchQueue.main.async { [weak self] in
            self?.pinListener?.onPinDeleted(pinId: pinId, originDeviceId: originDeviceId)
        }
    }

    private func handlePinRequest(_ fromDeviceId: String, payload: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.pinListener?.onPinRequestReceived(fromDeviceId: fromDeviceId)
        }
    }

    private func handleProfile(_ payload: [String: Any], deviceId: String, fromHost: String?) {
        let profile = ContactProfile.fromJSON(payload, deviceId: deviceId, fromIp: fromHost)

        DispatchQueue.main.async { [weak self] in
            self?.profileListener?.onProfileReceived(profile: profile)
        }
    }

    private func handleHello(_ deviceId: String, payload: [String: Any], fromHost: String?) {
        let callsign = payload["callsign"] as? String ?? ""

        DispatchQueue.main.async { [weak self] in
            self?.helloListener?.onHelloReceived(deviceId: deviceId, callsign: callsign, fromHost: fromHost)
        }
    }

    private func handleChat(_ payload: [String: Any]) {
        guard let id = payload["id"] as? String,
              let threadId = payload["threadId"] as? String,
              let fromDeviceId = payload["fromDeviceId"] as? String,
              let toDeviceId = payload["toDeviceId"] as? String,
              let text = payload["text"] as? String,
              let timestampMillis = payload["timestampMillis"] as? Int64 else { return }

        let message = ChatMessage(
            id: id,
            threadId: threadId,
            fromDeviceId: fromDeviceId,
            toDeviceId: toDeviceId,
            text: text,
            timestampMillis: timestampMillis,
            direction: .incoming
        )

        DispatchQueue.main.async { [weak self] in
            self?.chatListener?.onChatMessageReceived(message: message)
        }
    }

    private func handleChatAck(_ payload: [String: Any]) {
        guard let messageId = payload["messageId"] as? String,
              let fromDeviceId = payload["fromDeviceId"] as? String,
              let toDeviceId = payload["toDeviceId"] as? String,
              let timestampMillis = payload["timestampMillis"] as? Int64 else { return }

        let ack = ChatAck(
            messageId: messageId,
            fromDeviceId: fromDeviceId,
            toDeviceId: toDeviceId,
            timestampMillis: timestampMillis
        )

        DispatchQueue.main.async { [weak self] in
            self?.chatListener?.onChatAckReceived(ack: ack)
        }
    }

    private func handleOrder(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              var order = try? JSONDecoder().decode(Order.self, from: data) else { return }

        // Override direction for incoming
        order = Order(
            id: order.id,
            type: order.type,
            createdAtMillis: order.createdAtMillis,
            senderDeviceId: order.senderDeviceId,
            senderCallsign: order.senderCallsign,
            orientation: order.orientation,
            decision: order.decision,
            order: order.order,
            mission: order.mission,
            execution: order.execution,
            logistics: order.logistics,
            commandSignaling: order.commandSignaling,
            recipientDeviceIds: order.recipientDeviceIds,
            direction: .incoming,
            isRead: false
        )

        DispatchQueue.main.async { [weak self] in
            self?.orderListener?.onOrderReceived(order: order)
        }
    }

    private func handleOrderAck(_ payload: [String: Any]) {
        guard let orderId = payload["orderId"] as? String,
              let fromDeviceId = payload["fromDeviceId"] as? String,
              let toDeviceId = payload["toDeviceId"] as? String,
              let ackTypeString = payload["ackType"] as? String,
              let ackType = OrderAckType(rawValue: ackTypeString),
              let timestampMillis = payload["timestampMillis"] as? Int64 else { return }

        let ack = OrderAck(
            orderId: orderId,
            fromDeviceId: fromDeviceId,
            toDeviceId: toDeviceId,
            ackType: ackType,
            timestampMillis: timestampMillis
        )

        DispatchQueue.main.async { [weak self] in
            self?.orderListener?.onOrderAckReceived(ack: ack)
        }
    }

    private func handleReport(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              var report = try? JSONDecoder().decode(Report.self, from: data) else { return }

        // Override direction for incoming
        report = Report(
            id: report.id,
            createdAtMillis: report.createdAtMillis,
            senderDeviceId: report.senderDeviceId,
            senderCallsign: report.senderCallsign,
            woundedCount: report.woundedCount,
            deadCount: report.deadCount,
            capableCount: report.capableCount,
            replenishment: report.replenishment,
            fuel: report.fuel,
            ammunition: report.ammunition,
            equipment: report.equipment,
            readiness: report.readiness,
            readinessDetails: report.readinessDetails,
            recipientDeviceIds: report.recipientDeviceIds,
            direction: .incoming,
            isRead: false
        )

        DispatchQueue.main.async { [weak self] in
            self?.reportListener?.onReportReceived(report: report)
        }
    }

    private func handleReportAck(_ payload: [String: Any]) {
        guard let reportId = payload["reportId"] as? String,
              let fromDeviceId = payload["fromDeviceId"] as? String,
              let toDeviceId = payload["toDeviceId"] as? String,
              let ackTypeString = payload["ackType"] as? String,
              let ackType = ReportAckType(rawValue: ackTypeString),
              let timestampMillis = payload["timestampMillis"] as? Int64 else { return }

        let ack = ReportAck(
            reportId: reportId,
            fromDeviceId: fromDeviceId,
            toDeviceId: toDeviceId,
            ackType: ackType,
            timestampMillis: timestampMillis
        )

        DispatchQueue.main.async { [weak self] in
            self?.reportListener?.onReportAckReceived(ack: ack)
        }
    }

    private func handleMethane(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              var methane = try? JSONDecoder().decode(MethaneRequest.self, from: data) else { return }

        // Override direction for incoming
        methane = MethaneRequest(
            id: methane.id,
            createdAtMillis: methane.createdAtMillis,
            senderDeviceId: methane.senderDeviceId,
            senderCallsign: methane.senderCallsign,
            callsign: methane.callsign,
            unit: methane.unit,
            incidentLocation: methane.incidentLocation,
            incidentLatitude: methane.incidentLatitude,
            incidentLongitude: methane.incidentLongitude,
            incidentTime: methane.incidentTime,
            incidentType: methane.incidentType,
            hazards: methane.hazards,
            approachRoutes: methane.approachRoutes,
            hlsLocation: methane.hlsLocation,
            hlsLatitude: methane.hlsLatitude,
            hlsLongitude: methane.hlsLongitude,
            casualtyCountP1: methane.casualtyCountP1,
            casualtyCountP2: methane.casualtyCountP2,
            casualtyCountP3: methane.casualtyCountP3,
            casualtyCountDeceased: methane.casualtyCountDeceased,
            casualtyDetails: methane.casualtyDetails,
            assetsPresent: methane.assetsPresent,
            assetsRequired: methane.assetsRequired,
            recipientDeviceIds: methane.recipientDeviceIds,
            direction: .incoming,
            isRead: false
        )

        DispatchQueue.main.async { [weak self] in
            self?.methaneListener?.onMethaneReceived(methane: methane)
        }
    }

    private func handleMethaneAck(_ payload: [String: Any]) {
        guard let methaneId = payload["methaneId"] as? String,
              let fromDeviceId = payload["fromDeviceId"] as? String,
              let toDeviceId = payload["toDeviceId"] as? String,
              let ackTypeString = payload["ackType"] as? String,
              let ackType = MethaneAckType(rawValue: ackTypeString),
              let timestampMillis = payload["timestampMillis"] as? Int64 else { return }

        let ack = MethaneAck(
            methaneId: methaneId,
            fromDeviceId: fromDeviceId,
            toDeviceId: toDeviceId,
            ackType: ackType,
            timestampMillis: timestampMillis
        )

        DispatchQueue.main.async { [weak self] in
            self?.methaneListener?.onMethaneAckReceived(ack: ack)
        }
    }

    private func handleMedevac(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              var medevac = try? JSONDecoder().decode(MedevacReport.self, from: data) else { return }

        // Override direction for incoming
        medevac = MedevacReport(
            id: medevac.id,
            createdAtMillis: medevac.createdAtMillis,
            senderDeviceId: medevac.senderDeviceId,
            senderCallsign: medevac.senderCallsign,
            soldierName: medevac.soldierName,
            priority: medevac.priority,
            ageInfo: medevac.ageInfo,
            incidentTime: medevac.incidentTime,
            mechanismOfInjury: medevac.mechanismOfInjury,
            injuryDescription: medevac.injuryDescription,
            signsSymptoms: medevac.signsSymptoms,
            pulse: medevac.pulse,
            bodyTemperature: medevac.bodyTemperature,
            treatmentActions: medevac.treatmentActions,
            medicinesGiven: medevac.medicinesGiven,
            caretakerName: medevac.caretakerName,
            recipientDeviceIds: medevac.recipientDeviceIds,
            direction: .incoming,
            isRead: false
        )

        DispatchQueue.main.async { [weak self] in
            self?.medevacListener?.onMedevacReceived(medevac: medevac)
        }
    }

    private func handleMedevacAck(_ payload: [String: Any]) {
        guard let medevacId = payload["medevacId"] as? String,
              let fromDeviceId = payload["fromDeviceId"] as? String,
              let toDeviceId = payload["toDeviceId"] as? String,
              let ackTypeString = payload["ackType"] as? String,
              let ackType = MedevacAckType(rawValue: ackTypeString),
              let timestampMillis = payload["timestampMillis"] as? Int64 else { return }

        let ack = MedevacAck(
            medevacId: medevacId,
            fromDeviceId: fromDeviceId,
            toDeviceId: toDeviceId,
            ackType: ackType,
            timestampMillis: timestampMillis
        )

        DispatchQueue.main.async { [weak self] in
            self?.medevacListener?.onMedevacAckReceived(ack: ack)
        }
    }

    private func handleLinkedForm(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let form = try? JSONDecoder().decode(LinkedForm.self, from: data) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.linkedFormListener?.onLinkedFormReceived(form: form)
        }
    }
}
