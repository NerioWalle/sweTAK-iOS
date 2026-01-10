import Foundation
import Combine

// MARK: - Transport Mode

public enum TransportMode: String, Codable, CaseIterable {
    case localUDP = "LOCAL_UDP"
    case mqtt = "MQTT"

    public var displayName: String {
        switch self {
        case .localUDP: return "Local UDP"
        case .mqtt: return "MQTT"
        }
    }
}

// MARK: - Connection State

public enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

// MARK: - Transport Protocol

/// Protocol for network transport implementations (UDP, MQTT)
public protocol TransportProtocol: AnyObject {
    /// Current connection state
    var connectionState: AnyPublisher<ConnectionState, Never> { get }

    /// Start the transport
    func start()

    /// Stop the transport
    func stop()

    /// Send raw data
    func send(_ data: Data, to recipients: [String]?)

    /// Send a network message
    func send(message: NetworkMessage, to recipients: [String]?)

    /// Publisher for received messages
    var receivedMessages: AnyPublisher<NetworkMessage, Never> { get }
}

// MARK: - Transport Delegate

/// Delegate protocol for transport events
public protocol TransportDelegate: AnyObject {
    func transportDidConnect(_ transport: TransportProtocol)
    func transportDidDisconnect(_ transport: TransportProtocol, error: Error?)
    func transport(_ transport: TransportProtocol, didReceiveMessage message: NetworkMessage, fromHost: String?)
}

// MARK: - Message Listeners

/// Listener for position updates
public protocol PositionListener: AnyObject {
    func onPositionReceived(deviceId: String, callsign: String, latitude: Double, longitude: Double)
}

/// Listener for pin updates
public protocol PinListener: AnyObject {
    func onPinReceived(pin: NatoPin)
    func onPinDeleted(pinId: Int64, originDeviceId: String)
    func onPinRequestReceived(fromDeviceId: String)
}

/// Listener for profile updates
public protocol ProfileListener: AnyObject {
    func onProfileReceived(profile: ContactProfile)
}

/// Listener for chat messages
public protocol ChatListener: AnyObject {
    func onChatMessageReceived(message: ChatMessage)
    func onChatAckReceived(ack: ChatAck)
}

/// Listener for orders
public protocol OrderListener: AnyObject {
    func onOrderReceived(order: Order)
    func onOrderAckReceived(ack: OrderAck)
}

/// Listener for reports
public protocol ReportListener: AnyObject {
    func onReportReceived(report: Report)
    func onReportAckReceived(ack: ReportAck)
}

/// Listener for METHANE requests
public protocol MethaneListener: AnyObject {
    func onMethaneReceived(methane: MethaneRequest)
    func onMethaneAckReceived(ack: MethaneAck)
}

/// Listener for MEDEVAC reports
public protocol MedevacListener: AnyObject {
    func onMedevacReceived(medevac: MedevacReport)
    func onMedevacAckReceived(ack: MedevacAck)
}

/// Listener for linked forms
public protocol LinkedFormListener: AnyObject {
    func onLinkedFormReceived(form: LinkedForm)
}

/// Listener for hello/discovery messages
public protocol HelloListener: AnyObject {
    func onHelloReceived(deviceId: String, callsign: String, fromHost: String?)
}

// MARK: - MQTT Configuration

public struct MQTTConfiguration: Codable, Equatable {
    public var host: String
    public var port: Int
    public var useTLS: Bool
    public var username: String?
    public var password: String?
    public var clientId: String

    public init(
        host: String = "",
        port: Int = 8883,
        useTLS: Bool = true,
        username: String? = nil,
        password: String? = nil,
        clientId: String = UUID().uuidString
    ) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.username = username
        self.password = password
        self.clientId = clientId
    }

    public var isValid: Bool {
        !host.isEmpty && port > 0
    }
}

// MARK: - UDP Configuration

public struct UDPConfiguration: Codable, Equatable {
    public var port: Int
    public var broadcastAddress: String

    public init(
        port: Int = 35876,
        broadcastAddress: String = "255.255.255.255"
    ) {
        self.port = port
        self.broadcastAddress = broadcastAddress
    }
}

// MARK: - MQTT Topics

/// MQTT topic paths matching Android protocol
public enum MQTTTopic {
    public static let version = "v1"
    public static let prefix = "swetak/\(version)"

    // Primary topics
    public static let position = "\(prefix)/pos"
    public static let pin = "\(prefix)/pin"
    public static let profile = "\(prefix)/profile"
    public static let chat = "\(prefix)/chat"
    public static let order = "\(prefix)/order"
    public static let report = "\(prefix)/report"
    public static let methane = "\(prefix)/methane"
    public static let medevac = "\(prefix)/medevac"
    public static let linkedForm = "\(prefix)/linkedform"
    public static let photo = "\(prefix)/photo"

    // Request topics
    public static let pinRequest = "\(prefix)/pin_req"
    public static let profileRequest = "\(prefix)/profile_req"

    // ACK topics
    public static let orderAck = "\(prefix)/order_ack"
    public static let reportAck = "\(prefix)/report_ack"
    public static let methaneAck = "\(prefix)/methane_ack"
    public static let medevacAck = "\(prefix)/medevac_ack"

    public static var allTopics: [String] {
        [position, pin, profile, chat, order, report, methane, medevac, linkedForm, photo,
         pinRequest, profileRequest, orderAck, reportAck, methaneAck, medevacAck]
    }

    public static func topic(for messageType: MessageType) -> String {
        switch messageType {
        case .position: return position
        case .pin, .pinDelete: return pin
        case .pinRequest: return pinRequest
        case .profile: return profile
        case .hello: return profileRequest
        case .chat, .chatAck: return chat
        case .order: return order
        case .orderAck: return orderAck
        case .report: return report
        case .reportAck: return reportAck
        case .methane: return methane
        case .methaneAck: return methaneAck
        case .medevac: return medevac
        case .medevacAck: return medevacAck
        case .linkedForm: return linkedForm
        case .photo: return photo
        }
    }
}
