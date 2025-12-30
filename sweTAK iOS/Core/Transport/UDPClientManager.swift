import Foundation
import Combine
import Network
import os.log

/// UDP peer-to-peer client manager for iOS using Network framework
/// Mirrors Android UdpPeerBus functionality
public final class UDPClientManager: NSObject, TransportProtocol, ObservableObject {

    // MARK: - Constants

    public static let UDP_PORT: UInt16 = 35876
    private static let BROADCAST_ADDRESS = "255.255.255.255"
    private static let BUFFER_SIZE = 8192

    // MARK: - Singleton

    public static let shared = UDPClientManager()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "UDP")

    // MARK: - Published State

    @Published private var _connectionState: ConnectionState = .disconnected
    public var connectionState: AnyPublisher<ConnectionState, Never> {
        $_connectionState.eraseToAnyPublisher()
    }

    @Published public private(set) var isConnected: Bool = false

    // MARK: - Received Messages Publisher

    private let receivedMessagesSubject = PassthroughSubject<NetworkMessage, Never>()
    public var receivedMessages: AnyPublisher<NetworkMessage, Never> {
        receivedMessagesSubject.eraseToAnyPublisher()
    }

    // MARK: - Configuration

    private var configuration: UDPConfiguration = UDPConfiguration()

    // MARK: - Network Components

    private var listener: NWListener?
    private var broadcastConnection: NWConnection?
    private var peerConnections: [String: NWConnection] = [:]
    private let networkQueue = DispatchQueue(label: "com.swetak.udp", qos: .userInitiated)

    // MARK: - Known Peers

    private var knownPeers: Set<String> = []
    private let peersLock = NSLock()

    // MARK: - Profile Throttling

    private var lastProfileRequestTime: [String: Date] = [:]
    private var lastProfileReplyTime: [String: Date] = [:]
    private let throttleLock = NSLock()
    private let profileRequestThrottleMs: Int = 5000
    private let profileReplyThrottleMs: Int = 2000

    // MARK: - Profile Cache

    private var latestProfiles: [String: ContactProfile] = [:]
    private let profilesLock = NSLock()

    // MARK: - Callbacks

    public var provideLocalProfile: (() -> ContactProfile)?
    public var onContactProfileReceived: ((String, String?, ContactProfile) -> Void)?

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private override init() {
        super.init()

        $_connectionState
            .map { $0.isConnected }
            .assign(to: &$isConnected)
    }

    // MARK: - TransportProtocol

    public func start() {
        logger.info("Starting UDP transport on port \(Self.UDP_PORT)")
        _connectionState = .connecting

        startListener()
        setupBroadcastConnection()

        _connectionState = .connected
    }

    public func stop() {
        logger.info("Stopping UDP transport")

        listener?.cancel()
        listener = nil

        broadcastConnection?.cancel()
        broadcastConnection = nil

        peerConnections.values.forEach { $0.cancel() }
        peerConnections.removeAll()

        _connectionState = .disconnected
    }

    public func send(_ data: Data, to recipients: [String]?) {
        if let recipients = recipients, !recipients.isEmpty {
            // Unicast to specific recipients
            for recipient in recipients {
                sendToHost(data, host: recipient)
            }
        } else {
            // Broadcast
            broadcast(data)
        }
    }

    public func send(message: NetworkMessage, to recipients: [String]?) {
        guard let data = try? message.toJSONData() else {
            logger.error("Failed to serialize message for UDP send")
            return
        }
        send(data, to: recipients)
    }

    // MARK: - Configuration

    public func configure(with config: UDPConfiguration) {
        self.configuration = config
        logger.info("UDP configured: port=\(config.port) broadcast=\(config.broadcastAddress)")
    }

    // MARK: - Peer Management

    /// Add a known peer address
    public func addPeer(_ address: String) {
        peersLock.lock()
        knownPeers.insert(address)
        peersLock.unlock()
        logger.debug("Added peer: \(address)")
    }

    /// Remove a known peer address
    public func removePeer(_ address: String) {
        peersLock.lock()
        knownPeers.remove(address)
        peersLock.unlock()

        peerConnections[address]?.cancel()
        peerConnections.removeValue(forKey: address)
        logger.debug("Removed peer: \(address)")
    }

    /// Set all known peers
    public func setPeers(_ addresses: Set<String>) {
        peersLock.lock()
        knownPeers = addresses
        peersLock.unlock()
        logger.info("Set \(addresses.count) peers")
    }

    // MARK: - Profile Cache

    /// Get cached profile for a device ID
    public func latestProfile(for deviceId: String) -> ContactProfile? {
        profilesLock.lock()
        defer { profilesLock.unlock() }
        return latestProfiles[deviceId]
    }

    /// Get all cached profiles
    public func allLatestProfiles() -> [String: ContactProfile] {
        profilesLock.lock()
        defer { profilesLock.unlock() }
        return latestProfiles
    }

    // MARK: - Listener Setup

    private func startListener() {
        do {
            let params = NWParameters.udp
            params.allowLocalEndpointReuse = true

            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: Self.UDP_PORT)!)

            listener?.stateUpdateHandler = { [weak self] state in
                self?.handleListenerState(state)
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleIncomingConnection(connection)
            }

            listener?.start(queue: networkQueue)
            logger.info("UDP listener started on port \(Self.UDP_PORT)")

        } catch {
            logger.error("Failed to start UDP listener: \(error.localizedDescription)")
            _connectionState = .error("Failed to start UDP listener: \(error.localizedDescription)")
        }
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            logger.info("UDP listener ready")
        case .failed(let error):
            logger.error("UDP listener failed: \(error.localizedDescription)")
            _connectionState = .error("Listener failed: \(error.localizedDescription)")
        case .cancelled:
            logger.info("UDP listener cancelled")
        default:
            break
        }
    }

    private func handleIncomingConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveData(on: connection)
            case .failed(let error):
                self?.logger.error("Incoming connection failed: \(error.localizedDescription)")
            default:
                break
            }
        }
        connection.start(queue: networkQueue)
    }

    // MARK: - Broadcast Setup

    private func setupBroadcastConnection() {
        let host = NWEndpoint.Host(Self.BROADCAST_ADDRESS)
        let port = NWEndpoint.Port(rawValue: Self.UDP_PORT)!

        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        // Enable broadcast
        if let options = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            options.version = .v4
        }

        broadcastConnection = NWConnection(host: host, port: port, using: params)

        broadcastConnection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.logger.info("Broadcast connection ready")
            case .failed(let error):
                self?.logger.error("Broadcast connection failed: \(error.localizedDescription)")
            default:
                break
            }
        }

        broadcastConnection?.start(queue: networkQueue)
    }

    // MARK: - Receiving

    private func receiveData(on connection: NWConnection) {
        connection.receiveMessage { [weak self] content, context, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Receive error: \(error.localizedDescription)")
                return
            }

            if let data = content {
                let fromHost = self.extractHost(from: connection)
                self.handleReceivedData(data, fromHost: fromHost)
            }

            // Continue receiving
            self.receiveData(on: connection)
        }
    }

    private func extractHost(from connection: NWConnection) -> String {
        switch connection.endpoint {
        case .hostPort(let host, _):
            return "\(host)"
        default:
            return "unknown"
        }
    }

    private func handleReceivedData(_ data: Data, fromHost: String) {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            logger.warning("Failed to decode UDP data as UTF-8")
            return
        }

        logger.debug("RX <- \(fromHost): \(jsonString.prefix(120))")

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.warning("Failed to parse UDP JSON")
            return
        }

        let messageType = json["type"] as? String ?? ""
        let deviceId = json["deviceId"] as? String ?? ""

        // Ignore messages from self
        if deviceId == TransportCoordinator.shared.deviceId {
            return
        }

        // Route to appropriate handler
        switch messageType {
        case "hello":
            handleHelloMessage(json, fromHost: fromHost)

        case "pos":
            handlePositionMessage(json, fromHost: fromHost)

        case "profile":
            handleProfileMessage(json, fromHost: fromHost)

        case "profile_req":
            handleProfileRequestMessage(json, fromHost: fromHost)

        case "pin_add":
            handlePinAddMessage(json, fromHost: fromHost)

        case "pin_req":
            handlePinRequestMessage(json, fromHost: fromHost)

        case "chat":
            handleChatMessage(json, fromHost: fromHost)

        case "chat_ack":
            handleChatAckMessage(json, fromHost: fromHost)

        case "order":
            handleOrderMessage(json, fromHost: fromHost)

        case "order_ack":
            handleOrderAckMessage(json, fromHost: fromHost)

        case "linkedform":
            handleLinkedFormMessage(json, fromHost: fromHost)

        default:
            logger.debug("Unhandled UDP message type: \(messageType)")
        }
    }

    // MARK: - Message Handlers

    private func handleHelloMessage(_ json: [String: Any], fromHost: String) {
        let deviceId = json["deviceId"] as? String
        let callsign = json["callsign"] as? String
        let nickname = (json["nickname"] as? String) ?? (json["nick"] as? String)

        logger.debug("Hello from \(callsign ?? "unknown")@\(fromHost)")

        DispatchQueue.main.async {
            TransportCoordinator.shared.helloListener?.onHelloReceived(
                deviceId: deviceId ?? "",
                callsign: callsign ?? "",
                fromHost: fromHost
            )
        }

        // Auto-request profile (throttled)
        if !shouldThrottleProfileRequest(for: fromHost) {
            publishProfileRequest(to: fromHost, callsign: callsign, deviceId: deviceId)
        }
    }

    private func handlePositionMessage(_ json: [String: Any], fromHost: String) {
        guard let lat = json["lat"] as? Double,
              let lon = json["lon"] as? Double,
              isValidCoordinate(lat: lat, lon: lon) else {
            logger.warning("Invalid position from \(fromHost)")
            return
        }

        let deviceId = json["deviceId"] as? String ?? ""
        let callsign = json["callsign"] as? String ?? ""

        logger.debug("Position from \(callsign): \(lat), \(lon)")

        DispatchQueue.main.async {
            TransportCoordinator.shared.positionListener?.onPositionReceived(
                deviceId: deviceId,
                callsign: callsign,
                latitude: lat,
                longitude: lon
            )
        }

        // Auto-request profile (throttled)
        if !shouldThrottleProfileRequest(for: fromHost) {
            publishProfileRequest(to: fromHost, callsign: callsign, deviceId: deviceId)
        }
    }

    private func handleProfileMessage(_ json: [String: Any], fromHost: String) {
        let deviceId = json["deviceId"] as? String ?? ""
        guard !deviceId.isEmpty else { return }

        let profile = ContactProfile.fromJSON(json, deviceId: deviceId, fromIp: fromHost)

        // Cache the profile
        profilesLock.lock()
        latestProfiles[deviceId] = profile
        profilesLock.unlock()

        logger.debug("Profile from \(profile.callsign ?? "unknown")@\(fromHost)")

        DispatchQueue.main.async { [weak self] in
            TransportCoordinator.shared.profileListener?.onProfileReceived(profile: profile)
            self?.onContactProfileReceived?(deviceId, fromHost, profile)
        }
    }

    private func handleProfileRequestMessage(_ json: [String: Any], fromHost: String) {
        logger.debug("Profile request from \(fromHost)")

        // Auto-reply with our profile (throttled)
        if !shouldThrottleProfileReply(for: fromHost) {
            publishProfileTo(host: fromHost)
        }
    }

    private func handlePinAddMessage(_ json: [String: Any], fromHost: String) {
        guard let pin = NatoPin.fromJSON(json) else {
            logger.warning("Invalid pin from \(fromHost)")
            return
        }

        logger.debug("Pin from \(fromHost): \(pin.title)")

        DispatchQueue.main.async {
            TransportCoordinator.shared.pinListener?.onPinReceived(pin: pin)
        }
    }

    private func handlePinRequestMessage(_ json: [String: Any], fromHost: String) {
        let deviceId = json["deviceId"] as? String ?? ""

        logger.debug("Pin request from \(fromHost)")

        DispatchQueue.main.async {
            TransportCoordinator.shared.pinListener?.onPinRequestReceived(fromDeviceId: deviceId)
        }
    }

    private func handleChatMessage(_ json: [String: Any], fromHost: String) {
        guard let fromDeviceId = json["fromDeviceId"] as? String,
              let text = json["text"] as? String else {
            return
        }

        let threadId = json["threadId"] as? String ?? fromDeviceId
        let toDeviceId = json["toDeviceId"] as? String ?? ""
        let timestamp = json["ts"] as? Int64 ?? Date.currentMillis

        let message = ChatMessage(
            threadId: threadId,
            fromDeviceId: fromDeviceId,
            toDeviceId: toDeviceId,
            text: text,
            timestampMillis: timestamp,
            direction: .incoming
        )

        logger.debug("Chat from \(fromDeviceId): \(text.prefix(50))")

        DispatchQueue.main.async {
            TransportCoordinator.shared.chatListener?.onChatMessageReceived(message: message)
        }

        // Auto-send ACK
        let myDeviceId = TransportCoordinator.shared.deviceId
        if !myDeviceId.isEmpty && fromDeviceId != myDeviceId {
            sendChatAck(threadId: threadId, fromDeviceId: myDeviceId, toDeviceId: fromDeviceId, timestamp: timestamp)
        }
    }

    private func handleChatAckMessage(_ json: [String: Any], fromHost: String) {
        guard let messageId = json["threadId"] as? String,
              let fromDeviceId = json["fromDeviceId"] as? String,
              let toDeviceId = json["toDeviceId"] as? String else {
            return
        }

        let timestamp = json["ts"] as? Int64 ?? Date.currentMillis

        let ack = ChatAck(
            messageId: messageId,
            fromDeviceId: fromDeviceId,
            toDeviceId: toDeviceId,
            timestampMillis: timestamp
        )

        DispatchQueue.main.async {
            TransportCoordinator.shared.chatListener?.onChatAckReceived(ack: ack)
        }
    }

    private func handleOrderMessage(_ json: [String: Any], fromHost: String) {
        guard let orderId = json["orderId"] as? String,
              let orderTypeStr = json["orderType"] as? String,
              let fromDeviceId = json["fromDeviceId"] as? String,
              let fromCallsign = json["fromCallsign"] as? String else {
            return
        }

        let toDeviceIds = json["toDeviceIds"] as? [String] ?? []
        let myDeviceId = TransportCoordinator.shared.deviceId

        // Check if we're a recipient
        guard toDeviceIds.contains(myDeviceId) else { return }

        let orderType = OrderType(rawValue: orderTypeStr) ?? .obo
        let createdAtMillis = json["createdAtMillis"] as? Int64 ?? Date.currentMillis

        let order = Order(
            id: orderId,
            type: orderType,
            createdAtMillis: createdAtMillis,
            senderDeviceId: fromDeviceId,
            senderCallsign: fromCallsign,
            orientation: json["orientation"] as? String ?? "",
            decision: json["decision"] as? String ?? "",
            order: json["order"] as? String ?? "",
            mission: json["mission"] as? String ?? "",
            execution: json["execution"] as? String ?? "",
            logistics: json["logistics"] as? String ?? "",
            commandSignaling: json["commandSignaling"] as? String ?? "",
            recipientDeviceIds: toDeviceIds,
            direction: .incoming,
            isRead: false
        )

        logger.info("Order received: \(orderId)")

        DispatchQueue.main.async {
            TransportCoordinator.shared.orderListener?.onOrderReceived(order: order)
        }

        // Send DELIVERED ACK
        sendOrderAck(orderId: orderId, fromDeviceId: myDeviceId, toDeviceId: fromDeviceId, ackType: .delivered)
    }

    private func handleOrderAckMessage(_ json: [String: Any], fromHost: String) {
        guard let orderId = json["orderId"] as? String,
              let fromDeviceId = json["fromDeviceId"] as? String,
              let toDeviceId = json["toDeviceId"] as? String,
              let ackTypeStr = json["ackType"] as? String else {
            return
        }

        let myDeviceId = TransportCoordinator.shared.deviceId
        guard toDeviceId == myDeviceId else { return }

        let ackType = OrderAckType(rawValue: ackTypeStr) ?? .delivered
        let timestamp = json["timestampMillis"] as? Int64 ?? Date.currentMillis

        let ack = OrderAck(
            orderId: orderId,
            fromDeviceId: fromDeviceId,
            toDeviceId: toDeviceId,
            ackType: ackType,
            timestampMillis: timestamp
        )

        DispatchQueue.main.async {
            TransportCoordinator.shared.orderListener?.onOrderAckReceived(ack: ack)
        }
    }

    private func handleLinkedFormMessage(_ json: [String: Any], fromHost: String) {
        guard let id = json["id"] as? Int64,
              let opPinId = json["opPinId"] as? Int64,
              let formType = json["formType"] as? String else {
            return
        }

        let form = LinkedForm(
            id: id,
            opPinId: opPinId,
            opOriginDeviceId: json["opOriginDeviceId"] as? String ?? "",
            formType: formType,
            formData: json["formData"] as? String ?? "",
            submittedAtMillis: json["submittedAtMillis"] as? Int64 ?? Date.currentMillis,
            authorCallsign: json["authorCallsign"] as? String ?? "",
            targetLat: json["targetLat"] as? Double,
            targetLon: json["targetLon"] as? Double,
            observerLat: json["observerLat"] as? Double,
            observerLon: json["observerLon"] as? Double
        )

        logger.debug("LinkedForm from \(fromHost): \(formType)")

        DispatchQueue.main.async {
            TransportCoordinator.shared.linkedFormListener?.onLinkedFormReceived(form: form)
        }
    }

    // MARK: - Sending

    private func broadcast(_ data: Data) {
        // Broadcast to LAN
        broadcastConnection?.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.logger.error("Broadcast send error: \(error.localizedDescription)")
            }
        })

        // Unicast to known peers
        peersLock.lock()
        let peers = knownPeers
        peersLock.unlock()

        for peer in peers {
            sendToHost(data, host: peer)
        }
    }

    private func sendToHost(_ data: Data, host: String) {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: Self.UDP_PORT)!)

        if let connection = peerConnections[host], connection.state == .ready {
            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                if let error = error {
                    self?.logger.error("Send to \(host) error: \(error.localizedDescription)")
                }
            })
        } else {
            // Create new connection
            let params = NWParameters.udp
            let connection = NWConnection(to: endpoint, using: params)

            connection.stateUpdateHandler = { [weak self] state in
                if state == .ready {
                    connection.send(content: data, completion: .contentProcessed { error in
                        if let error = error {
                            self?.logger.error("Send to \(host) error: \(error.localizedDescription)")
                        }
                    })
                }
            }

            peerConnections[host] = connection
            connection.start(queue: networkQueue)
        }
    }

    // MARK: - Public Send Methods

    /// Send hello message
    public func sendHello(callsign: String, deviceId: String, nickname: String? = nil) {
        guard TransportCoordinator.shared.activeMode == .localUDP else { return }

        var json: [String: Any] = [
            "type": "hello",
            "callsign": callsign,
            "deviceId": deviceId
        ]
        if let nick = nickname {
            json["nickname"] = nick
            json["nick"] = nick  // Legacy key
        }

        sendJSON(json)
    }

    /// Send position update
    public func sendPosition(callsign: String, deviceId: String, latitude: Double, longitude: Double) {
        guard TransportCoordinator.shared.activeMode == .localUDP else { return }

        let json: [String: Any] = [
            "type": "pos",
            "callsign": callsign,
            "deviceId": deviceId,
            "lat": latitude,
            "lon": longitude,
            "ts": Date.currentMillis
        ]

        sendJSON(json)
    }

    /// Publish profile to all peers
    public func publishProfile(_ profile: ContactProfile, deviceId: String) {
        guard TransportCoordinator.shared.activeMode == .localUDP else { return }

        let json = profileToJSON(profile)
        sendJSON(json)
    }

    /// Publish profile to specific host
    public func publishProfileTo(host: String) {
        guard let profile = provideLocalProfile?() else { return }

        let json = profileToJSON(profile)
        if let data = try? JSONSerialization.data(withJSONObject: json) {
            sendToHost(data, host: host)
        }
    }

    /// Send profile request
    public func publishProfileRequest(to host: String, callsign: String?, deviceId: String?) {
        var json: [String: Any] = ["type": "profile_req"]
        if let cs = callsign { json["callsign"] = cs }
        if let devId = deviceId { json["deviceId"] = devId }

        if let data = try? JSONSerialization.data(withJSONObject: json) {
            sendToHost(data, host: host)
        }
    }

    /// Send pin
    public func publishPin(_ pin: NatoPin, deviceId: String, callsign: String) {
        guard TransportCoordinator.shared.activeMode == .localUDP else { return }

        var json: [String: Any] = [
            "type": "pin_add",
            "deviceId": deviceId,
            "callsign": callsign,
            "id": pin.id,
            "lat": pin.latitude,
            "lon": pin.longitude,
            "pinType": pin.type.rawValue,
            "title": pin.title,
            "description": pin.description,
            "ts": pin.createdAtMillis,
            "originDeviceId": pin.originDeviceId.isEmpty ? deviceId : pin.originDeviceId
        ]

        if let photo = pin.photoBase64 {
            json["photoBase64"] = photo
        }

        sendJSON(json)
    }

    /// Request all pins
    public func requestAllPins(callsign: String, deviceId: String) {
        guard TransportCoordinator.shared.activeMode == .localUDP else { return }

        let json: [String: Any] = [
            "type": "pin_req",
            "callsign": callsign,
            "deviceId": deviceId
        ]

        sendJSON(json)
    }

    /// Send chat message
    public func sendChat(threadId: String, fromDeviceId: String, toDeviceId: String, text: String) {
        guard TransportCoordinator.shared.activeMode == .localUDP else { return }

        let json: [String: Any] = [
            "type": "chat",
            "threadId": threadId,
            "fromDeviceId": fromDeviceId,
            "toDeviceId": toDeviceId,
            "text": text,
            "ts": Date.currentMillis
        ]

        sendJSON(json)
    }

    /// Send chat ACK
    public func sendChatAck(threadId: String, fromDeviceId: String, toDeviceId: String, timestamp: Int64) {
        let json: [String: Any] = [
            "type": "chat_ack",
            "threadId": threadId,
            "fromDeviceId": fromDeviceId,
            "toDeviceId": toDeviceId,
            "ts": timestamp
        ]

        sendJSON(json)
    }

    /// Send order
    public func sendOrder(_ order: Order) {
        guard TransportCoordinator.shared.activeMode == .localUDP else { return }

        let json: [String: Any] = [
            "type": "order",
            "orderId": order.id,
            "orderType": order.type.rawValue,
            "fromDeviceId": order.senderDeviceId,
            "fromCallsign": order.senderCallsign,
            "toDeviceIds": order.recipientDeviceIds,
            "createdAtMillis": order.createdAtMillis,
            "orientation": order.orientation,
            "decision": order.decision,
            "order": order.order,
            "mission": order.mission,
            "execution": order.execution,
            "logistics": order.logistics,
            "commandSignaling": order.commandSignaling
        ]

        sendJSON(json)
    }

    /// Send order ACK
    public func sendOrderAck(orderId: String, fromDeviceId: String, toDeviceId: String, ackType: OrderAckType) {
        let json: [String: Any] = [
            "type": "order_ack",
            "orderId": orderId,
            "fromDeviceId": fromDeviceId,
            "toDeviceId": toDeviceId,
            "ackType": ackType.rawValue,
            "timestampMillis": Date.currentMillis
        ]

        sendJSON(json)
    }

    /// Send linked form
    public func publishLinkedForm(_ form: LinkedForm, deviceId: String) {
        guard TransportCoordinator.shared.activeMode == .localUDP else { return }

        var json: [String: Any] = [
            "type": "linkedform",
            "deviceId": deviceId,
            "id": form.id,
            "opPinId": form.opPinId,
            "opOriginDeviceId": form.opOriginDeviceId,
            "formType": form.formType,
            "formData": form.formData,
            "submittedAtMillis": form.submittedAtMillis,
            "authorCallsign": form.authorCallsign
        ]

        if let lat = form.targetLat { json["targetLat"] = lat }
        if let lon = form.targetLon { json["targetLon"] = lon }
        if let lat = form.observerLat { json["observerLat"] = lat }
        if let lon = form.observerLon { json["observerLon"] = lon }

        sendJSON(json)
    }

    // MARK: - Helpers

    private func sendJSON(_ json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json) else {
            logger.error("Failed to serialize JSON for sending")
            return
        }
        broadcast(data)
    }

    private func profileToJSON(_ profile: ContactProfile) -> [String: Any] {
        var json: [String: Any] = [
            "type": "profile",
            "deviceId": profile.deviceId
        ]

        if let callsign = profile.callsign { json["callsign"] = callsign }
        if let nickname = profile.nickname {
            json["nickname"] = nickname
            json["nick"] = nickname  // Legacy key
        }
        if let first = profile.firstName { json["first"] = first }
        if let last = profile.lastName { json["last"] = last }
        if let company = profile.company { json["company"] = company }
        if let platoon = profile.platoon { json["platoon"] = platoon }
        if let squad = profile.squad { json["squad"] = squad }
        if let mobile = profile.mobile { json["mobile"] = mobile }
        if let email = profile.email { json["email"] = email }

        return json
    }

    private func isValidCoordinate(lat: Double, lon: Double) -> Bool {
        lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
    }

    // MARK: - Throttling

    private func shouldThrottleProfileRequest(for host: String) -> Bool {
        throttleLock.lock()
        defer { throttleLock.unlock() }

        let now = Date()
        if let last = lastProfileRequestTime[host] {
            let elapsed = now.timeIntervalSince(last) * 1000
            if elapsed < Double(profileRequestThrottleMs) {
                return true
            }
        }
        lastProfileRequestTime[host] = now
        return false
    }

    private func shouldThrottleProfileReply(for host: String) -> Bool {
        throttleLock.lock()
        defer { throttleLock.unlock() }

        let now = Date()
        if let last = lastProfileReplyTime[host] {
            let elapsed = now.timeIntervalSince(last) * 1000
            if elapsed < Double(profileReplyThrottleMs) {
                return true
            }
        }
        lastProfileReplyTime[host] = now
        return false
    }
}
