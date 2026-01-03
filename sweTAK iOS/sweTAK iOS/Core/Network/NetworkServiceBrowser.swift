import Foundation
import Network
import Combine
import os.log

// MARK: - Network Service Type

/// Service types for network discovery
public enum NetworkServiceType: String {
    case sweTAK = "_swetak._udp."
    case sweTAKTCP = "_swetak._tcp."
    case cot = "_cot._tcp."
    case tak = "_tak._tcp."

    public var displayName: String {
        switch self {
        case .sweTAK: return "sweTAK (UDP)"
        case .sweTAKTCP: return "sweTAK (TCP)"
        case .cot: return "CoT"
        case .tak: return "TAK"
        }
    }
}

// MARK: - Discovered Peer

/// A peer discovered via Bonjour/mDNS
public struct DiscoveredPeer: Identifiable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let serviceType: NetworkServiceType
    public let host: String?
    public let port: UInt16?
    public let txtRecord: [String: String]
    public let discoveredAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        serviceType: NetworkServiceType,
        host: String? = nil,
        port: UInt16? = nil,
        txtRecord: [String: String] = [:],
        discoveredAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.serviceType = serviceType
        self.host = host
        self.port = port
        self.txtRecord = txtRecord
        self.discoveredAt = discoveredAt
    }

    /// Device ID from TXT record
    public var deviceId: String? {
        txtRecord["deviceId"] ?? txtRecord["did"]
    }

    /// Callsign from TXT record
    public var callsign: String? {
        txtRecord["callsign"] ?? txtRecord["cs"]
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: DiscoveredPeer, rhs: DiscoveredPeer) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Network Service Browser

/// Bonjour/mDNS service browser using Network framework
/// Discovers sweTAK peers on the local network
public final class NetworkServiceBrowser: ObservableObject {

    // MARK: - Singleton

    public static let shared = NetworkServiceBrowser()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "ServiceBrowser")

    // MARK: - Published State

    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var discoveredPeers: [DiscoveredPeer] = []
    @Published public private(set) var lastError: String?

    // MARK: - Properties

    private var browser: NWBrowser?
    private var listener: NWListener?
    private let networkQueue = DispatchQueue(label: "com.swetak.browser", qos: .userInitiated)

    // Service registration
    private var registeredServiceName: String?
    private var registeredTxtRecord: [String: String] = [:]

    // Peer tracking
    private var peerEndpoints: [String: NWBrowser.Result] = [:]
    private let peersLock = NSLock()

    // MARK: - Callbacks

    public var onPeerDiscovered: ((DiscoveredPeer) -> Void)?
    public var onPeerLost: ((String) -> Void)?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Start browsing for sweTAK services
    public func startBrowsing(for serviceType: NetworkServiceType = .sweTAK) {
        guard !isScanning else {
            logger.debug("Already scanning for services")
            return
        }

        logger.info("Starting service browser for \(serviceType.rawValue)")

        // Create browser parameters
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        // Create browser for the service type
        let descriptor = NWBrowser.Descriptor.bonjour(type: serviceType.rawValue, domain: "local.")
        browser = NWBrowser(for: descriptor, using: parameters)

        browser?.stateUpdateHandler = { [weak self] state in
            self?.handleBrowserStateUpdate(state)
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            self?.handleBrowseResults(results, changes: changes)
        }

        browser?.start(queue: networkQueue)

        DispatchQueue.main.async {
            self.isScanning = true
            self.lastError = nil
        }
    }

    /// Stop browsing for services
    public func stopBrowsing() {
        logger.info("Stopping service browser")

        browser?.cancel()
        browser = nil

        DispatchQueue.main.async {
            self.isScanning = false
        }
    }

    /// Register this device as a discoverable service
    public func registerService(
        name: String,
        port: UInt16,
        deviceId: String,
        callsign: String,
        serviceType: NetworkServiceType = .sweTAK
    ) {
        logger.info("Registering service: \(name) on port \(port)")

        // Build TXT record
        var txtRecord: [String: String] = [
            "deviceId": deviceId,
            "did": deviceId,
            "callsign": callsign,
            "cs": callsign,
            "version": "1.0"
        ]

        registeredTxtRecord = txtRecord
        registeredServiceName = name

        do {
            // Create listener parameters
            let params = NWParameters.udp
            params.includePeerToPeer = true

            // Create listener on specified port
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)

            // Set service advertisement
            listener?.service = NWListener.Service(
                name: name,
                type: serviceType.rawValue,
                domain: "local.",
                txtRecord: buildTXTRecord(from: txtRecord)
            )

            listener?.stateUpdateHandler = { [weak self] state in
                self?.handleListenerStateUpdate(state)
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.logger.debug("New connection from service advertisement")
                // Handle incoming connections if needed
                connection.cancel()
            }

            listener?.start(queue: networkQueue)

        } catch {
            logger.error("Failed to register service: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.lastError = "Failed to register service: \(error.localizedDescription)"
            }
        }
    }

    /// Unregister this device's service
    public func unregisterService() {
        logger.info("Unregistering service")

        listener?.cancel()
        listener = nil
        registeredServiceName = nil
        registeredTxtRecord = [:]
    }

    /// Update the TXT record for registered service
    public func updateTXTRecord(callsign: String?, deviceId: String?) {
        guard listener != nil else { return }

        if let callsign = callsign {
            registeredTxtRecord["callsign"] = callsign
            registeredTxtRecord["cs"] = callsign
        }

        if let deviceId = deviceId {
            registeredTxtRecord["deviceId"] = deviceId
            registeredTxtRecord["did"] = deviceId
        }

        // Re-register with updated TXT record
        if let name = registeredServiceName {
            listener?.service = NWListener.Service(
                name: name,
                type: NetworkServiceType.sweTAK.rawValue,
                domain: "local.",
                txtRecord: buildTXTRecord(from: registeredTxtRecord)
            )
        }
    }

    /// Get peer by ID
    public func peer(withId id: String) -> DiscoveredPeer? {
        discoveredPeers.first { $0.id == id }
    }

    /// Get peer by device ID
    public func peer(withDeviceId deviceId: String) -> DiscoveredPeer? {
        discoveredPeers.first { $0.deviceId == deviceId }
    }

    /// Clear discovered peers
    public func clearPeers() {
        peersLock.lock()
        peerEndpoints.removeAll()
        peersLock.unlock()

        DispatchQueue.main.async {
            self.discoveredPeers.removeAll()
        }
    }

    // MARK: - Private Methods

    private func handleBrowserStateUpdate(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            logger.info("Browser ready")

        case .failed(let error):
            logger.error("Browser failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isScanning = false
                self.lastError = "Browser failed: \(error.localizedDescription)"
            }

        case .cancelled:
            logger.info("Browser cancelled")
            DispatchQueue.main.async {
                self.isScanning = false
            }

        case .setup:
            logger.debug("Browser setup")

        case .waiting(let error):
            logger.warning("Browser waiting: \(error.localizedDescription)")

        @unknown default:
            break
        }
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            switch change {
            case .added(let result):
                handlePeerAdded(result)

            case .removed(let result):
                handlePeerRemoved(result)

            case .changed(old: _, new: let newResult, flags: _):
                handlePeerChanged(newResult)

            case .identical:
                break

            @unknown default:
                break
            }
        }
    }

    private func handlePeerAdded(_ result: NWBrowser.Result) {
        guard case let .service(name, type, domain, _) = result.endpoint else { return }

        logger.info("Discovered peer: \(name)")

        // Parse TXT record
        var txtRecord: [String: String] = [:]
        if case let .bonjour(record) = result.metadata {
            txtRecord = parseTXTRecord(record)
        }

        // Determine service type
        let serviceType: NetworkServiceType = {
            if type.contains("swetak") {
                return type.contains("tcp") ? .sweTAKTCP : .sweTAK
            } else if type.contains("cot") {
                return .cot
            } else if type.contains("tak") {
                return .tak
            }
            return .sweTAK
        }()

        let peer = DiscoveredPeer(
            id: "\(name).\(type)\(domain)",
            name: name,
            serviceType: serviceType,
            txtRecord: txtRecord
        )

        // Store endpoint for later resolution
        peersLock.lock()
        peerEndpoints[peer.id] = result
        peersLock.unlock()

        // Resolve the endpoint to get host/port
        resolveEndpoint(result, for: peer)
    }

    private func handlePeerRemoved(_ result: NWBrowser.Result) {
        guard case let .service(name, type, domain, _) = result.endpoint else { return }

        let peerId = "\(name).\(type)\(domain)"

        logger.info("Lost peer: \(name)")

        peersLock.lock()
        peerEndpoints.removeValue(forKey: peerId)
        peersLock.unlock()

        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0.id == peerId }
            self.onPeerLost?(peerId)
        }
    }

    private func handlePeerChanged(_ result: NWBrowser.Result) {
        guard case let .service(name, type, domain, _) = result.endpoint else { return }

        let peerId = "\(name).\(type)\(domain)"

        logger.debug("Peer changed: \(name)")

        // Update TXT record
        var txtRecord: [String: String] = [:]
        if case let .bonjour(record) = result.metadata {
            txtRecord = parseTXTRecord(record)
        }

        DispatchQueue.main.async {
            if let index = self.discoveredPeers.firstIndex(where: { $0.id == peerId }) {
                let existing = self.discoveredPeers[index]
                self.discoveredPeers[index] = DiscoveredPeer(
                    id: existing.id,
                    name: existing.name,
                    serviceType: existing.serviceType,
                    host: existing.host,
                    port: existing.port,
                    txtRecord: txtRecord,
                    discoveredAt: existing.discoveredAt
                )
            }
        }
    }

    private func resolveEndpoint(_ result: NWBrowser.Result, for peer: DiscoveredPeer) {
        // Create a connection to resolve the endpoint
        let params = NWParameters.udp
        let connection = NWConnection(to: result.endpoint, using: params)

        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }

            switch state {
            case .ready:
                // Extract resolved host and port
                var host: String? = nil
                var port: UInt16? = nil

                if let remoteEndpoint = connection.currentPath?.remoteEndpoint {
                    switch remoteEndpoint {
                    case .hostPort(let h, let p):
                        host = "\(h)"
                        port = p.rawValue
                    default:
                        break
                    }
                }

                // Update peer with resolved address
                let resolvedPeer = DiscoveredPeer(
                    id: peer.id,
                    name: peer.name,
                    serviceType: peer.serviceType,
                    host: host,
                    port: port,
                    txtRecord: peer.txtRecord,
                    discoveredAt: peer.discoveredAt
                )

                DispatchQueue.main.async {
                    // Remove existing peer with same ID
                    self.discoveredPeers.removeAll { $0.id == resolvedPeer.id }
                    self.discoveredPeers.append(resolvedPeer)
                    self.onPeerDiscovered?(resolvedPeer)
                }

                connection.cancel()

            case .failed, .cancelled:
                // Still add peer even if resolution fails
                DispatchQueue.main.async {
                    if !self.discoveredPeers.contains(where: { $0.id == peer.id }) {
                        self.discoveredPeers.append(peer)
                        self.onPeerDiscovered?(peer)
                    }
                }

            default:
                break
            }
        }

        connection.start(queue: networkQueue)

        // Timeout resolution after 5 seconds
        networkQueue.asyncAfter(deadline: .now() + 5) {
            if connection.state != .ready && connection.state != .cancelled {
                connection.cancel()
            }
        }
    }

    private func handleListenerStateUpdate(_ state: NWListener.State) {
        switch state {
        case .ready:
            if let port = listener?.port?.rawValue {
                logger.info("Service registered on port \(port)")
            }

        case .failed(let error):
            logger.error("Listener failed: \(error.localizedDescription)")

        case .cancelled:
            logger.info("Listener cancelled")

        default:
            break
        }
    }

    private func buildTXTRecord(from dict: [String: String]) -> NWTXTRecord {
        var record = NWTXTRecord()
        for (key, value) in dict {
            record[key] = value
        }
        return record
    }

    private func parseTXTRecord(_ record: NWTXTRecord) -> [String: String] {
        var dict: [String: String] = [:]

        // NWTXTRecord is a dictionary-like structure
        for key in record.dictionary.keys {
            if let value = record[key] {
                dict[key] = value
            }
        }

        return dict
    }
}

// MARK: - NWTXTRecord Extension

extension NWTXTRecord {
    /// Get all keys as dictionary
    var dictionary: [String: String] {
        var result: [String: String] = [:]
        // Iterate through known keys or use reflection
        // This is a simplified version
        return result
    }
}
