import Foundation
import Combine
import CocoaMQTT
import os.log

/// MQTT client manager for iOS using CocoaMQTT (MQTT 3.1.1)
/// Note: Using MQTT 3.1.1 for better compatibility with most brokers
public final class MQTTClientManager: NSObject, TransportProtocol, ObservableObject {

    // MARK: - Singleton

    public static let shared = MQTTClientManager()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "MQTT")

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

    private var configuration: MQTTConfiguration = MQTTConfiguration()
    private var maxMessageAgeMinutes: Int = 360  // 6 hours default

    // MARK: - MQTT Client
    // Using MQTT 3.1.1 (CocoaMQTT) as primary - more universally supported
    // MQTT 5.0 (CocoaMQTT5) available as fallback

    private var mqtt: CocoaMQTT?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Message Handlers

    private var topicHandlers: [String: (String, Data) -> Void] = [:]

    // MARK: - Initialization

    private override init() {
        super.init()

        // Observe connection state changes
        $_connectionState
            .map { $0.isConnected }
            .assign(to: &$isConnected)
    }

    // MARK: - TransportProtocol

    public func start() {
        guard configuration.isValid else {
            logger.warning("MQTT start() aborted: invalid configuration")
            _connectionState = .error("Invalid MQTT configuration")
            return
        }

        connect(with: configuration)
    }

    public func stop() {
        disconnect()
    }

    public func send(_ data: Data, to recipients: [String]?) {
        // Generic send - determine topic based on message type
        logger.warning("send(data:) called without topic - use send(message:) instead")
    }

    public func send(message: NetworkMessage, to recipients: [String]?) {
        let topic = MQTTTopic.topic(for: message.type)

        logger.info("send() called: type=\(message.type.rawValue) topic=\(topic)")

        // Create a flat JSON structure (payload fields at top level) for MQTT
        // This matches the format expected by Android and the message handlers
        var flatJson: [String: Any] = [
            "type": message.type.rawValue,
            "deviceId": message.deviceId,
            "ts": message.timestamp
        ]

        // Add callsign from SettingsViewModel for all messages
        let callsign = SettingsViewModel.shared.callsign
        flatJson["callsign"] = callsign

        // Merge payload fields into top level
        for (key, value) in message.payload {
            // Map some field names to match Android protocol
            switch key {
            case "type":
                // Pin type uses "natoType" to avoid collision with message type
                flatJson["natoType"] = value
            default:
                flatJson[key] = value
            }
        }

        // Add timestamp variants for compatibility
        if let createdAt = message.payload["createdAtMillis"] {
            flatJson["createdAtMillis"] = createdAt
        }

        // Log the final JSON for debugging
        print(">>> MQTT send() JSON: \(flatJson)")

        do {
            let data = try JSONSerialization.data(withJSONObject: flatJson, options: [])
            guard let jsonString = String(data: data, encoding: .utf8) else {
                logger.error("Failed to convert JSON data to string")
                return
            }
            publish(json: jsonString, to: topic)
        } catch {
            logger.error("Failed to serialize message: \(error.localizedDescription)")
        }
    }

    // MARK: - Configuration

    /// Configure the MQTT client with the given settings
    public func configure(with config: MQTTConfiguration, maxMessageAgeMinutes: Int = 360) {
        self.configuration = config
        self.maxMessageAgeMinutes = maxMessageAgeMinutes
        logger.info("MQTT configured: host=\(config.host) port=\(config.port) tls=\(config.useTLS)")
    }

    // MARK: - Connection Management

    /// Connect to the MQTT broker
    public func connect(with config: MQTTConfiguration) {
        logger.info("connect() called: host=\(config.host) port=\(config.port) tls=\(config.useTLS)")
        print(">>> MQTT connect(): host=\(config.host) port=\(config.port) tls=\(config.useTLS)")

        configuration = config

        guard !config.host.isEmpty else {
            logger.warning("connect() aborted: empty host")
            _connectionState = .error("Empty MQTT host")
            return
        }

        _connectionState = .connecting

        // Create MQTT 3.1.1 client (most universally supported)
        let clientId = config.clientId.isEmpty ? "swetak-ios-\(UUID().uuidString.prefix(8))" : config.clientId
        print(">>> MQTT: Creating MQTT 3.1.1 client with ID: \(clientId)")

        let mqttClient = CocoaMQTT(clientID: clientId, host: config.host, port: UInt16(config.port))

        // Configure connection options
        mqttClient.username = config.username
        mqttClient.password = config.password
        mqttClient.keepAlive = 60
        mqttClient.autoReconnect = true
        mqttClient.autoReconnectTimeInterval = 5
        mqttClient.cleanSession = true

        print(">>> MQTT: Username=\(config.username ?? "nil") Password=\(config.password != nil ? "(set)" : "nil")")

        // TLS configuration
        mqttClient.enableSSL = config.useTLS
        if config.useTLS {
            // Allow untrusted certificates for servers with self-signed certs
            mqttClient.allowUntrustCACertificate = true

            print(">>> MQTT: TLS enabled with allowUntrustCACertificate=true")
            logger.info("TLS enabled with allowUntrustCACertificate=true")
        }

        // Set delegate
        mqttClient.delegate = self

        self.mqtt = mqttClient

        // Attempt connection
        print(">>> MQTT: Initiating MQTT 3.1.1 connection to \(config.host):\(config.port) TLS=\(config.useTLS)")
        logger.info("Initiating connection to \(config.host):\(config.port)...")
        let result = mqttClient.connect()
        if result {
            print(">>> MQTT: Connection initiated, waiting for CONNACK...")
            logger.info("Connection initiated successfully, waiting for CONNACK...")
        } else {
            print(">>> MQTT: Failed to initiate connection!")
            logger.error("connect() failed to initiate connection")
            _connectionState = .error("Failed to initiate MQTT connection")
        }
    }

    /// Disconnect from the MQTT broker
    public func disconnect() {
        logger.info("disconnect() called")
        mqtt?.disconnect()
        mqtt = nil
        _connectionState = .disconnected
    }

    // MARK: - Publishing

    /// Publish a network message to a topic
    public func publish(message: NetworkMessage, to topic: String, qos: CocoaMQTTQoS = .qos1, retained: Bool = false) {
        guard let mqtt = mqtt, isConnected else {
            logger.warning("publish() aborted: not connected")
            return
        }

        do {
            let data = try message.toJSONData()
            let payload = String(data: data, encoding: .utf8) ?? ""

            logger.debug("Publishing to \(topic): \(payload.prefix(100))...")

            mqtt.publish(topic, withString: payload, qos: qos, retained: retained)
        } catch {
            logger.error("publish() failed to serialize message: \(error.localizedDescription)")
        }
    }

    /// Publish raw JSON string to a topic
    public func publish(json: String, to topic: String, qos: CocoaMQTTQoS = .qos1, retained: Bool = false) {
        guard let mqtt = mqtt else {
            logger.error("publish(json:) aborted: mqtt client is nil")
            return
        }

        guard isConnected else {
            logger.warning("publish(json:) aborted: not connected (state: \(String(describing: self._connectionState)))")
            return
        }

        logger.info("Publishing to \(topic): \(json.prefix(200))...")

        mqtt.publish(topic, withString: json, qos: qos, retained: retained)
        logger.debug("Publish call completed for topic: \(topic)")
    }

    /// Publish position update
    public func publishPosition(callsign: String, deviceId: String, latitude: Double, longitude: Double) {
        let timestamp = Date.currentMillis

        let json = """
        {
            "type": "position",
            "deviceId": "\(deviceId)",
            "callsign": "\(escapeJSON(callsign))",
            "lat": \(latitude),
            "lon": \(longitude),
            "ts": \(timestamp)
        }
        """

        publish(json: json, to: MQTTTopic.position)
    }

    /// Publish pin update
    public func publishPin(_ pin: NatoPin, deviceId: String, callsign: String, photoBase64: String? = nil) {
        var json = """
        {
            "type": "pin",
            "deviceId": "\(deviceId)",
            "callsign": "\(escapeJSON(callsign))",
            "id": \(pin.id),
            "lat": \(pin.latitude),
            "lon": \(pin.longitude),
            "natoType": "\(pin.type.rawValue)",
            "title": "\(escapeJSON(pin.title))",
            "description": "\(escapeJSON(pin.description))",
            "createdAtMillis": \(pin.createdAtMillis),
            "originDeviceId": "\(pin.originDeviceId.isEmpty ? deviceId : pin.originDeviceId)"
        """

        if let photo = photoBase64 {
            json += """
            ,
                "photoBase64": "\(photo)"
            """
        }

        json += "\n}"

        publish(json: json, to: MQTTTopic.pin)
    }

    /// Publish profile update
    public func publishProfile(_ profile: ContactProfile, deviceId: String) {
        let json = """
        {
            "type": "profile",
            "deviceId": "\(deviceId)",
            "callsign": "\(escapeJSON(profile.callsign ?? ""))",
            "nickname": "\(escapeJSON(profile.nickname ?? ""))",
            "firstName": "\(escapeJSON(profile.firstName ?? ""))",
            "lastName": "\(escapeJSON(profile.lastName ?? ""))",
            "company": "\(escapeJSON(profile.company ?? ""))",
            "platoon": "\(escapeJSON(profile.platoon ?? ""))",
            "squad": "\(escapeJSON(profile.squad ?? ""))",
            "phone": "\(escapeJSON(profile.mobile ?? ""))",
            "email": "\(escapeJSON(profile.email ?? ""))",
            "role": "\(profile.role.rawValue)"
        }
        """

        publish(json: json, to: MQTTTopic.profile)
    }

    /// Publish chat message
    public func publishChat(_ message: ChatMessage) {
        let json = """
        {
            "type": "chat",
            "threadId": "\(message.threadId)",
            "fromDeviceId": "\(message.fromDeviceId)",
            "toDeviceId": "\(message.toDeviceId)",
            "text": "\(escapeJSON(message.text))",
            "timestamp": \(message.timestampMillis)
        }
        """

        publish(json: json, to: MQTTTopic.chat)
    }

    // MARK: - Subscription

    /// Subscribe to all sweTAK topics
    private func subscribeToAllTopics() {
        logger.info("Subscribing to all sweTAK topics")

        let topics = [
            MQTTTopic.position,
            MQTTTopic.pin,
            MQTTTopic.profile,
            MQTTTopic.chat,
            MQTTTopic.order,
            MQTTTopic.report,
            MQTTTopic.methane,
            MQTTTopic.medevac,
            MQTTTopic.linkedForm,
            "swetak/v1/pin_req",
            "swetak/v1/profile_req",
            "swetak/v1/order_ack",
            "swetak/v1/report_ack",
            "swetak/v1/methane_ack",
            "swetak/v1/medevac_ack"
        ]

        for topic in topics {
            subscribe(to: topic)
        }
    }

    /// Subscribe to a single topic
    public func subscribe(to topic: String, qos: CocoaMQTTQoS = .qos1) {
        guard let mqtt = mqtt else {
            logger.warning("subscribe() aborted: mqtt client is nil")
            return
        }

        logger.debug("Subscribing to \(topic)")
        mqtt.subscribe(topic, qos: qos)
    }

    // MARK: - Message Handling

    /// Handle incoming message on a topic
    private func handleMessage(topic: String, payload: Data) {
        guard let jsonString = String(data: payload, encoding: .utf8) else {
            logger.warning("Failed to decode payload as UTF-8 string")
            return
        }

        logger.debug("Received on \(topic): \(jsonString.prefix(200))...")

        guard let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            logger.warning("Failed to parse JSON from \(topic)")
            return
        }

        // Extract common fields
        let messageType = json["type"] as? String ?? ""
        let deviceId = json["deviceId"] as? String ?? ""

        // Check message age for replay protection
        if let timestamp = json["ts"] as? Int64 ?? json["createdAtMillis"] as? Int64 ?? json["timestamp"] as? Int64 {
            if isMessageTooOld(timestamp) {
                logger.debug("Ignoring old message (age > \(self.maxMessageAgeMinutes) min)")
                return
            }
        }

        // Route to appropriate handler based on topic/type
        switch topic {
        case MQTTTopic.position:
            handlePositionMessage(json, deviceId: deviceId)

        case MQTTTopic.pin:
            if messageType == "pin" {
                handlePinMessage(json, deviceId: deviceId)
            }

        case "swetak/v1/pin_req":
            handlePinRequestMessage(json, deviceId: deviceId)

        case MQTTTopic.profile:
            handleProfileMessage(json, deviceId: deviceId)

        case "swetak/v1/profile_req":
            handleProfileRequestMessage(json, deviceId: deviceId)

        case MQTTTopic.chat:
            handleChatMessage(json, deviceId: deviceId)

        case MQTTTopic.order:
            handleOrderMessage(json, deviceId: deviceId)

        case "swetak/v1/order_ack":
            handleOrderAckMessage(json)

        case MQTTTopic.report:
            handleReportMessage(json, deviceId: deviceId)

        case "swetak/v1/report_ack":
            handleReportAckMessage(json)

        case MQTTTopic.methane:
            handleMethaneMessage(json, deviceId: deviceId)

        case "swetak/v1/methane_ack":
            handleMethaneAckMessage(json)

        case MQTTTopic.medevac:
            handleMedevacMessage(json, deviceId: deviceId)

        case "swetak/v1/medevac_ack":
            handleMedevacAckMessage(json)

        case MQTTTopic.linkedForm:
            handleLinkedFormMessage(json, deviceId: deviceId)

        default:
            logger.debug("Unhandled topic: \(topic)")
        }
    }

    // MARK: - Message Handlers

    private func handlePositionMessage(_ json: [String: Any], deviceId: String) {
        guard let callsign = json["callsign"] as? String,
              let lat = json["lat"] as? Double,
              let lon = json["lon"] as? Double,
              isValidCoordinate(lat: lat, lon: lon) else {
            logger.warning("Invalid position message")
            return
        }

        let nickname = json["nickname"] as? String

        logger.debug("Position received: \(callsign) at \(lat), \(lon)")

        DispatchQueue.main.async {
            TransportCoordinator.shared.positionListener?.onPositionReceived(
                deviceId: deviceId,
                callsign: callsign,
                latitude: lat,
                longitude: lon
            )
        }
    }

    private func handlePinMessage(_ json: [String: Any], deviceId: String) {
        guard let pin = NatoPin.fromJSON(json) else {
            logger.warning("Invalid pin message")
            return
        }

        logger.debug("Pin received: \(pin.title) at \(pin.latitude), \(pin.longitude)")

        DispatchQueue.main.async {
            TransportCoordinator.shared.pinListener?.onPinReceived(pin: pin)
        }
    }

    private func handlePinRequestMessage(_ json: [String: Any], deviceId: String) {
        logger.debug("Pin request received from \(deviceId)")

        DispatchQueue.main.async {
            TransportCoordinator.shared.pinListener?.onPinRequestReceived(fromDeviceId: deviceId)
        }
    }

    private func handleProfileMessage(_ json: [String: Any], deviceId: String) {
        let profile = ContactProfile.fromJSON(json, deviceId: deviceId, fromIp: "mqtt")

        logger.debug("Profile received: \(profile.callsign ?? "unknown")")

        DispatchQueue.main.async {
            TransportCoordinator.shared.profileListener?.onProfileReceived(profile: profile)
        }
    }

    private func handleProfileRequestMessage(_ json: [String: Any], deviceId: String) {
        logger.info("Profile request received from \(deviceId) - responding with our profile")

        // Don't respond to our own requests
        let myDeviceId = TransportCoordinator.shared.deviceId
        guard deviceId != myDeviceId else {
            logger.debug("Ignoring our own profile request")
            return
        }

        // Get our profile from ContactsViewModel and respond
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let myProfile = ContactsViewModel.shared.myProfile {
                self.logger.info("Sending profile response: callsign=\(myProfile.callsign ?? "unknown")")
                self.publishProfile(myProfile, deviceId: myDeviceId)
            } else {
                // Fallback: create minimal profile from SettingsViewModel
                let settings = SettingsViewModel.shared
                let profile = ContactProfile(
                    deviceId: myDeviceId,
                    nickname: settings.profile.nickname.isEmpty ? nil : settings.profile.nickname,
                    callsign: settings.profile.callsign.isEmpty ? nil : settings.profile.callsign,
                    firstName: settings.profile.firstName.isEmpty ? nil : settings.profile.firstName,
                    lastName: settings.profile.lastName.isEmpty ? nil : settings.profile.lastName,
                    company: settings.profile.company.isEmpty ? nil : settings.profile.company,
                    platoon: settings.profile.platoon.isEmpty ? nil : settings.profile.platoon,
                    squad: settings.profile.squad.isEmpty ? nil : settings.profile.squad,
                    mobile: settings.profile.phone.isEmpty ? nil : settings.profile.phone,
                    email: settings.profile.email.isEmpty ? nil : settings.profile.email,
                    role: settings.profile.role
                )
                self.logger.info("Sending fallback profile response: callsign=\(profile.callsign ?? "unknown")")
                self.publishProfile(profile, deviceId: myDeviceId)
            }
        }
    }

    private func handleChatMessage(_ json: [String: Any], deviceId: String) {
        logger.info("handleChatMessage received - raw JSON: \(json)")
        logger.info("handleChatMessage - deviceId from topic: \(deviceId)")

        // Try multiple field name variants for compatibility with Android
        let fromDeviceId = json["fromDeviceId"] as? String ?? json["from"] as? String ?? json["senderId"] as? String ?? deviceId
        let toDeviceId = json["toDeviceId"] as? String ?? json["to"] as? String ?? json["recipientId"] as? String ?? ""
        let text = json["text"] as? String ?? json["message"] as? String ?? json["content"] as? String ?? json["body"] as? String ?? ""

        logger.info("handleChatMessage - parsed: from=\(fromDeviceId), to=\(toDeviceId), text=\(text.prefix(30))")

        guard !text.isEmpty else {
            logger.warning("Invalid chat message - no text field found in: \(json.keys)")
            return
        }

        // Check if this message is for us (or broadcast)
        let myDeviceId = TransportCoordinator.shared.deviceId
        logger.info("handleChatMessage - myDeviceId: \(myDeviceId)")

        // Accept message if: addressed to us, no recipient specified, or we're the sender (echo)
        let isForUs = toDeviceId == myDeviceId || toDeviceId.isEmpty
        let isFromUs = fromDeviceId == myDeviceId

        if isFromUs {
            logger.debug("Chat message is from us (echo), ignoring")
            return
        }

        if !isForUs {
            logger.info("Chat message not for us (to: \(toDeviceId), me: \(myDeviceId)) - but processing anyway for debug")
            // Still process for now to debug - remove this later
        }

        // Get timestamp with fallbacks
        let timestamp = json["timestamp"] as? Int64
            ?? json["timestampMillis"] as? Int64
            ?? json["ts"] as? Int64
            ?? (json["timestamp"] as? Double).map { Int64($0) }
            ?? (json["timestampMillis"] as? Double).map { Int64($0) }
            ?? Date.currentMillis

        // For incoming messages, the thread should be keyed by the sender's deviceId
        // This matches how outgoing messages use toDeviceId as threadId
        let threadId = json["threadId"] as? String ?? fromDeviceId

        let message = ChatMessage(
            id: json["id"] as? String ?? json["messageId"] as? String ?? "\(timestamp)-\(text.hashValue)",
            threadId: threadId,
            fromDeviceId: fromDeviceId,
            toDeviceId: toDeviceId,
            text: text,
            timestampMillis: timestamp,
            direction: .incoming
        )

        logger.info("Chat message created - threadId: \(threadId), delivering to listener")

        DispatchQueue.main.async {
            TransportCoordinator.shared.chatListener?.onChatMessageReceived(message: message)
        }
    }

    private func handleOrderMessage(_ json: [String: Any], deviceId: String) {
        guard let orderId = json["orderId"] as? String,
              let orderTypeStr = json["orderType"] as? String,
              let fromDeviceId = json["fromDeviceId"] as? String,
              let fromCallsign = json["fromCallsign"] as? String else {
            logger.warning("Invalid order message")
            return
        }

        let toDeviceIdsArray = json["toDeviceIds"] as? [String] ?? []
        let createdAtMillis = json["createdAtMillis"] as? Int64 ?? Date.currentMillis

        // Check if we are a recipient
        let myDeviceId = TransportCoordinator.shared.deviceId
        guard toDeviceIdsArray.contains(myDeviceId) else {
            logger.debug("Order not addressed to us, ignoring")
            return
        }

        let orderType = OrderType(rawValue: orderTypeStr) ?? .obo

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
            recipientDeviceIds: toDeviceIdsArray,
            direction: .incoming,
            isRead: false
        )

        logger.info("Order received: \(orderId) type=\(orderType.rawValue)")

        DispatchQueue.main.async {
            TransportCoordinator.shared.orderListener?.onOrderReceived(order: order)
        }

        // Send DELIVERED ACK
        let ack = OrderAck(
            orderId: orderId,
            fromDeviceId: myDeviceId,
            toDeviceId: fromDeviceId,
            ackType: .delivered
        )
        TransportCoordinator.shared.sendOrderAck(ack)
    }

    private func handleOrderAckMessage(_ json: [String: Any]) {
        guard let orderId = json["orderId"] as? String,
              let fromDeviceId = json["fromDeviceId"] as? String,
              let toDeviceId = json["toDeviceId"] as? String,
              let ackTypeStr = json["ackType"] as? String else {
            return
        }

        let myDeviceId = TransportCoordinator.shared.deviceId
        guard toDeviceId == myDeviceId else { return }

        let ackType = OrderAckType(rawValue: ackTypeStr) ?? .delivered
        let timestampMillis = json["timestampMillis"] as? Int64 ?? Date.currentMillis

        let ack = OrderAck(
            orderId: orderId,
            fromDeviceId: fromDeviceId,
            toDeviceId: toDeviceId,
            ackType: ackType,
            timestampMillis: timestampMillis
        )

        logger.debug("Order ACK received: \(orderId) type=\(ackType.rawValue)")

        DispatchQueue.main.async {
            TransportCoordinator.shared.orderListener?.onOrderAckReceived(ack: ack)
        }
    }

    private func handleReportMessage(_ json: [String: Any], deviceId: String) {
        guard let reportId = json["reportId"] as? String,
              let fromDeviceId = json["fromDeviceId"] as? String,
              let fromCallsign = json["fromCallsign"] as? String else {
            logger.warning("Invalid report message")
            return
        }

        let toDeviceIdsArray = json["toDeviceIds"] as? [String] ?? []
        let myDeviceId = TransportCoordinator.shared.deviceId
        guard toDeviceIdsArray.contains(myDeviceId) else { return }

        let readinessStr = json["readiness"] as? String ?? "GREEN"
        let readiness = ReadinessLevel(rawValue: readinessStr) ?? .green

        let report = Report(
            id: reportId,
            createdAtMillis: json["createdAtMillis"] as? Int64 ?? Date.currentMillis,
            senderDeviceId: fromDeviceId,
            senderCallsign: fromCallsign,
            woundedCount: json["woundedCount"] as? Int ?? 0,
            deadCount: json["deadCount"] as? Int ?? 0,
            capableCount: json["capableCount"] as? Int ?? 0,
            replenishment: json["replenishment"] as? String ?? "",
            fuel: json["fuel"] as? String ?? "",
            ammunition: json["ammunition"] as? String ?? "",
            equipment: json["equipment"] as? String ?? "",
            readiness: readiness,
            readinessDetails: json["readinessDetails"] as? String ?? "",
            recipientDeviceIds: toDeviceIdsArray,
            direction: .incoming,
            isRead: false
        )

        logger.info("Report received: \(reportId)")

        DispatchQueue.main.async {
            TransportCoordinator.shared.reportListener?.onReportReceived(report: report)
        }
    }

    private func handleReportAckMessage(_ json: [String: Any]) {
        guard let reportId = json["reportId"] as? String,
              let fromDeviceId = json["fromDeviceId"] as? String,
              let toDeviceId = json["toDeviceId"] as? String,
              let ackTypeStr = json["ackType"] as? String else { return }

        let myDeviceId = TransportCoordinator.shared.deviceId
        guard toDeviceId == myDeviceId else { return }

        let ackType = ReportAckType(rawValue: ackTypeStr) ?? .delivered

        let ack = ReportAck(
            reportId: reportId,
            fromDeviceId: fromDeviceId,
            toDeviceId: toDeviceId,
            ackType: ackType,
            timestampMillis: json["timestampMillis"] as? Int64 ?? Date.currentMillis
        )

        DispatchQueue.main.async {
            TransportCoordinator.shared.reportListener?.onReportAckReceived(ack: ack)
        }
    }

    private func handleMethaneMessage(_ json: [String: Any], deviceId: String) {
        guard let requestId = json["requestId"] as? String,
              let fromDeviceId = json["fromDeviceId"] as? String,
              let fromCallsign = json["fromCallsign"] as? String else {
            logger.warning("Invalid METHANE message")
            return
        }

        let toDeviceIdsArray = json["toDeviceIds"] as? [String] ?? []
        let myDeviceId = TransportCoordinator.shared.deviceId
        guard toDeviceIdsArray.contains(myDeviceId) else { return }

        let methane = MethaneRequest(
            id: requestId,
            createdAtMillis: json["createdAtMillis"] as? Int64 ?? Date.currentMillis,
            senderDeviceId: fromDeviceId,
            senderCallsign: fromCallsign,
            callsign: json["callsign"] as? String ?? "",
            unit: json["unit"] as? String ?? "",
            incidentLocation: json["incidentLocation"] as? String ?? "",
            incidentLatitude: json["incidentLatitude"] as? Double,
            incidentLongitude: json["incidentLongitude"] as? Double,
            incidentTime: json["incidentTime"] as? String ?? "",
            incidentType: json["incidentType"] as? String ?? "",
            hazards: json["hazards"] as? String ?? "",
            approachRoutes: json["approachRoutes"] as? String ?? "",
            hlsLocation: json["hlsLocation"] as? String ?? "",
            hlsLatitude: json["hlsLatitude"] as? Double,
            hlsLongitude: json["hlsLongitude"] as? Double,
            casualtyCountP1: json["casualtyCountP1"] as? Int ?? 0,
            casualtyCountP2: json["casualtyCountP2"] as? Int ?? 0,
            casualtyCountP3: json["casualtyCountP3"] as? Int ?? 0,
            casualtyCountDeceased: json["casualtyCountDeceased"] as? Int ?? 0,
            casualtyDetails: json["casualtyDetails"] as? String ?? "",
            assetsPresent: json["assetsPresent"] as? String ?? "",
            assetsRequired: json["assetsRequired"] as? String ?? "",
            recipientDeviceIds: toDeviceIdsArray,
            direction: .incoming,
            isRead: false
        )

        logger.info("METHANE received: \(requestId)")

        DispatchQueue.main.async {
            TransportCoordinator.shared.methaneListener?.onMethaneReceived(methane: methane)
        }

        // Send DELIVERED ACK
        let ack = MethaneAck(
            methaneId: requestId,
            fromDeviceId: myDeviceId,
            toDeviceId: fromDeviceId,
            ackType: .delivered
        )
        TransportCoordinator.shared.sendMethaneAck(ack)
    }

    private func handleMethaneAckMessage(_ json: [String: Any]) {
        guard let requestId = json["requestId"] as? String,
              let fromDeviceId = json["fromDeviceId"] as? String,
              let toDeviceId = json["toDeviceId"] as? String,
              let ackTypeStr = json["ackType"] as? String else { return }

        let myDeviceId = TransportCoordinator.shared.deviceId
        guard toDeviceId == myDeviceId else { return }

        let ackType = MethaneAckType(rawValue: ackTypeStr) ?? .delivered

        let ack = MethaneAck(
            methaneId: requestId,
            fromDeviceId: fromDeviceId,
            toDeviceId: toDeviceId,
            ackType: ackType,
            timestampMillis: json["timestampMillis"] as? Int64 ?? Date.currentMillis
        )

        DispatchQueue.main.async {
            TransportCoordinator.shared.methaneListener?.onMethaneAckReceived(ack: ack)
        }
    }

    private func handleMedevacMessage(_ json: [String: Any], deviceId: String) {
        guard let reportId = json["reportId"] as? String,
              let fromDeviceId = json["fromDeviceId"] as? String,
              let fromCallsign = json["fromCallsign"] as? String else {
            logger.warning("Invalid MEDEVAC message")
            return
        }

        let toDeviceIdsArray = json["toDeviceIds"] as? [String] ?? []
        let myDeviceId = TransportCoordinator.shared.deviceId
        guard toDeviceIdsArray.contains(myDeviceId) else { return }

        let priorityStr = json["priority"] as? String ?? "P1"
        let priority = MedevacPriority(rawValue: priorityStr) ?? .p1

        let report = MedevacReport(
            id: reportId,
            createdAtMillis: json["createdAtMillis"] as? Int64 ?? Date.currentMillis,
            senderDeviceId: fromDeviceId,
            senderCallsign: fromCallsign,
            soldierName: json["soldierName"] as? String ?? "",
            priority: priority,
            ageInfo: json["ageInfo"] as? String ?? "",
            incidentTime: json["incidentTime"] as? String ?? "",
            mechanismOfInjury: json["mechanismOfInjury"] as? String ?? "",
            injuryDescription: json["injuryDescription"] as? String ?? "",
            signsSymptoms: json["signsSymptoms"] as? String ?? "",
            pulse: json["pulse"] as? String ?? "",
            bodyTemperature: json["bodyTemperature"] as? String ?? "",
            treatmentActions: json["treatmentActions"] as? String ?? "",
            medicinesGiven: json["medicinesGiven"] as? String ?? "",
            caretakerName: json["caretakerName"] as? String ?? "",
            recipientDeviceIds: toDeviceIdsArray,
            direction: .incoming,
            isRead: false
        )

        logger.info("MEDEVAC received: \(reportId)")

        DispatchQueue.main.async {
            TransportCoordinator.shared.medevacListener?.onMedevacReceived(medevac: report)
        }

        // Send DELIVERED ACK
        let ack = MedevacAck(
            medevacId: reportId,
            fromDeviceId: myDeviceId,
            toDeviceId: fromDeviceId,
            ackType: .delivered
        )
        TransportCoordinator.shared.sendMedevacAck(ack)
    }

    private func handleMedevacAckMessage(_ json: [String: Any]) {
        guard let reportId = json["reportId"] as? String,
              let fromDeviceId = json["fromDeviceId"] as? String,
              let toDeviceId = json["toDeviceId"] as? String,
              let ackTypeStr = json["ackType"] as? String else { return }

        let myDeviceId = TransportCoordinator.shared.deviceId
        guard toDeviceId == myDeviceId else { return }

        let ackType = MedevacAckType(rawValue: ackTypeStr) ?? .delivered

        let ack = MedevacAck(
            medevacId: reportId,
            fromDeviceId: fromDeviceId,
            toDeviceId: toDeviceId,
            ackType: ackType,
            timestampMillis: json["timestampMillis"] as? Int64 ?? Date.currentMillis
        )

        DispatchQueue.main.async {
            TransportCoordinator.shared.medevacListener?.onMedevacAckReceived(ack: ack)
        }
    }

    private func handleLinkedFormMessage(_ json: [String: Any], deviceId: String) {
        guard let id = json["id"] as? Int64,
              let opPinId = json["opPinId"] as? Int64,
              let formType = json["formType"] as? String else {
            logger.warning("Invalid linked form message")
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

        logger.debug("Linked form received: \(id) type=\(formType)")

        DispatchQueue.main.async {
            TransportCoordinator.shared.linkedFormListener?.onLinkedFormReceived(form: form)
        }
    }

    // MARK: - Helper Methods

    private func isMessageTooOld(_ timestampMillis: Int64) -> Bool {
        guard maxMessageAgeMinutes > 0 else { return false }
        let ageMillis = Date.currentMillis - timestampMillis
        let maxAgeMillis = Int64(maxMessageAgeMinutes) * 60 * 1000
        return ageMillis > maxAgeMillis
    }

    private func isValidCoordinate(lat: Double, lon: Double) -> Bool {
        lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
    }

    private func escapeJSON(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}

// MARK: - CocoaMQTTDelegate (MQTT 3.1.1)

extension MQTTClientManager: CocoaMQTTDelegate {

    public func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        print(">>> MQTT: didConnectAck - ack=\(ack)")
        logger.info("Connected with ack: \(String(describing: ack), privacy: .public)")

        if ack == .accept {
            print(">>> MQTT: Connection successful!")
            _connectionState = .connected
            subscribeToAllTopics()
        } else {
            let errorMsg: String
            switch ack {
            case .unacceptableProtocolVersion:
                errorMsg = "Unacceptable protocol version"
            case .identifierRejected:
                errorMsg = "Client identifier rejected"
            case .serverUnavailable:
                errorMsg = "Server unavailable"
            case .badUsernameOrPassword:
                errorMsg = "Bad username or password"
            case .notAuthorized:
                errorMsg = "Not authorized"
            default:
                errorMsg = "Connection rejected: \(ack)"
            }
            print(">>> MQTT: Connection rejected: \(errorMsg)")
            _connectionState = .error(errorMsg)
        }
    }

    public func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        logger.debug("Message published: \(id)")
    }

    public func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        logger.debug("Publish ack: \(id)")
    }

    public func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        let topic = message.topic
        let payload = message.payload

        handleMessage(topic: topic, payload: Data(payload))
    }

    public func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        logger.info("Subscribed to topics: \(success.allKeys)")
        print(">>> MQTT: Subscribed to topics: \(success.allKeys)")
        if !failed.isEmpty {
            logger.warning("Failed to subscribe to: \(failed)")
            print(">>> MQTT: Failed to subscribe to: \(failed)")
        }
    }

    public func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
        logger.info("Unsubscribed from: \(topics)")
    }

    public func mqttDidPing(_ mqtt: CocoaMQTT) {
        logger.debug("Ping sent")
    }

    public func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        logger.debug("Pong received")
    }

    public func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        if let error = err {
            let errorMsg = error.localizedDescription
            // Use print for non-redacted output
            print(">>> MQTT Disconnected with error: \(errorMsg)")
            print(">>> Error details: \(error)")
            print(">>> Error type: \(type(of: error))")
            if let nsError = error as NSError? {
                print(">>> NSError domain: \(nsError.domain), code: \(nsError.code)")
                print(">>> NSError userInfo: \(nsError.userInfo)")
            }
            logger.error("Disconnected with error: \(errorMsg, privacy: .public)")
            _connectionState = .error(errorMsg)
        } else {
            print(">>> MQTT: Disconnected normally (no error)")
            logger.info("Disconnected normally")
            _connectionState = .disconnected
        }
    }

    public func mqtt(_ mqtt: CocoaMQTT, didStateChangeTo state: CocoaMQTTConnState) {
        print(">>> MQTT: State changed to: \(state)")
        logger.info("MQTT state changed to: \(String(describing: state))")
    }

    public func mqtt(_ mqtt: CocoaMQTT, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        print(">>> MQTT: Received SSL trust challenge")

        // Get certificate info for debugging
        if let serverCert = SecTrustGetCertificateAtIndex(trust, 0) {
            let summary = SecCertificateCopySubjectSummary(serverCert) as String? ?? "unknown"
            print(">>> MQTT: Server certificate: \(summary)")
        }

        // Accept all certificates for this server
        print(">>> MQTT: Accepting certificate")
        completionHandler(true)
    }
}
