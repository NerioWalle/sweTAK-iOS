import Foundation
import Network
import os.log

// MARK: - Network Utilities

/// Network utility functions for peer discovery and management
/// Mirrors Android MapNetworkUtils functionality
public enum MapNetworkUtils {

    private static let logger = Logger(subsystem: "com.swetak", category: "MapNetwork")

    // MARK: - Local IP Address

    /// Get the local IPv4 address of the device, or nil if not available
    public static func getLocalIPAddress() -> String? {
        var address: String?

        // Get list of all interfaces
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }

        defer { freeifaddrs(ifaddr) }

        // Iterate through interfaces
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee

            // Check for IPv4
            let addrFamily = interface.ifa_addr.pointee.sa_family
            guard addrFamily == UInt8(AF_INET) else { continue }

            // Get interface name
            let name = String(cString: interface.ifa_name)

            // Skip loopback
            guard name != "lo0" else { continue }

            // Prefer WiFi (en0) or cellular (pdp_ip0)
            guard name == "en0" || name.hasPrefix("en") || name.hasPrefix("pdp_ip") else { continue }

            // Get address string
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 {
                address = String(cString: hostname)
                // Prefer en0 (WiFi)
                if name == "en0" {
                    break
                }
            }
        }

        return address
    }

    /// Get all local IPv4 addresses
    public static func getAllLocalIPAddresses() -> [String] {
        var addresses: [String] = []

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return []
        }

        defer { freeifaddrs(ifaddr) }

        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee

            let addrFamily = interface.ifa_addr.pointee.sa_family
            guard addrFamily == UInt8(AF_INET) else { continue }

            let name = String(cString: interface.ifa_name)
            guard name != "lo0" else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 {
                addresses.append(String(cString: hostname))
            }
        }

        return addresses
    }

    // MARK: - Subnet Utilities

    /// Get the broadcast address for the current network
    public static func getBroadcastAddress() -> String? {
        guard let localIP = getLocalIPAddress() else { return nil }

        // Parse IP components
        let components = localIP.split(separator: ".").compactMap { Int($0) }
        guard components.count == 4 else { return nil }

        // Assume /24 subnet (common for local networks)
        return "\(components[0]).\(components[1]).\(components[2]).255"
    }

    /// Check if an IP is in the same subnet as our local IP
    public static func isInLocalSubnet(_ ip: String) -> Bool {
        guard let localIP = getLocalIPAddress() else { return false }

        let localComponents = localIP.split(separator: ".").compactMap { Int($0) }
        let targetComponents = ip.split(separator: ".").compactMap { Int($0) }

        guard localComponents.count == 4, targetComponents.count == 4 else {
            return false
        }

        // Check first 3 octets match (assumes /24 subnet)
        return localComponents[0] == targetComponents[0] &&
               localComponents[1] == targetComponents[1] &&
               localComponents[2] == targetComponents[2]
    }

    // MARK: - Peer Management

    /// Friend/peer discovered on network
    public struct NetworkPeer: Hashable {
        public let deviceId: String
        public let host: String
        public let port: Int
        public var callsign: String?
        public var nickname: String?
        public var lastSeen: Date

        public init(
            deviceId: String,
            host: String,
            port: Int = 4242,
            callsign: String? = nil,
            nickname: String? = nil,
            lastSeen: Date = Date()
        ) {
            self.deviceId = deviceId
            self.host = host
            self.port = port
            self.callsign = callsign
            self.nickname = nickname
            self.lastSeen = lastSeen
        }

        public static func == (lhs: NetworkPeer, rhs: NetworkPeer) -> Bool {
            return lhs.deviceId == rhs.deviceId
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(deviceId)
        }
    }

    /// Build UDP peer set from current friends
    /// Only non-blocked friends are included
    public static func rebuildUDPPeers(
        friends: [String: NetworkPeer],
        blockedIds: Set<String>
    ) -> Set<NetworkPeer> {
        var result = Set<NetworkPeer>()

        for (deviceId, peer) in friends {
            // Skip blocked peers
            if blockedIds.contains(deviceId) || blockedIds.contains(peer.host) {
                continue
            }

            // Skip peers without valid host
            guard !peer.host.isEmpty else { continue }

            result.insert(peer)
        }

        return result
    }

    /// Build chat recipient list from friends
    public static func buildChatRecipients(
        friends: [String: NetworkPeer],
        blockedIds: Set<String>,
        myDeviceId: String,
        contacts: [String: ContactProfile]
    ) -> [ChatRecipient] {
        return friends.values
            .filter { peer in
                !peer.deviceId.isEmpty &&
                peer.deviceId != myDeviceId &&
                !blockedIds.contains(peer.deviceId) &&
                (peer.host.isEmpty || !blockedIds.contains(peer.host))
            }
            .map { peer in
                // Get effective profile
                let contact = contacts[peer.deviceId]
                let callsign = nullIfLiteral(contact?.callsign) ??
                               nullIfLiteral(peer.callsign) ??
                               "Unknown"
                let nickname = nullIfLiteral(contact?.nickname) ??
                               nullIfLiteral(peer.nickname)

                return ChatRecipient(
                    deviceId: peer.deviceId,
                    callsign: callsign,
                    nickname: nickname
                )
            }
            .uniqued(by: \.deviceId)
    }

    // MARK: - Connection Quality

    /// Estimate connection quality based on response times
    public enum ConnectionQuality {
        case excellent  // < 50ms
        case good       // < 150ms
        case fair       // < 300ms
        case poor       // >= 300ms
        case unknown

        public var displayName: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .fair: return "Fair"
            case .poor: return "Poor"
            case .unknown: return "Unknown"
            }
        }
    }

    /// Estimate connection quality from latency in milliseconds
    public static func estimateConnectionQuality(_ latencyMs: Int) -> ConnectionQuality {
        switch latencyMs {
        case ..<50: return .excellent
        case ..<150: return .good
        case ..<300: return .fair
        default: return .poor
        }
    }

    // MARK: - Network Monitoring

    /// Check if device is connected to WiFi
    public static func isOnWiFi() -> Bool {
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        var isWiFi = false
        let semaphore = DispatchSemaphore(value: 0)

        monitor.pathUpdateHandler = { path in
            isWiFi = path.status == .satisfied
            semaphore.signal()
        }

        let queue = DispatchQueue(label: "wifi.check")
        monitor.start(queue: queue)

        _ = semaphore.wait(timeout: .now() + 0.5)
        monitor.cancel()

        return isWiFi
    }

    /// Check if device has any network connection
    public static func hasNetworkConnection() -> Bool {
        let monitor = NWPathMonitor()
        var hasConnection = false
        let semaphore = DispatchSemaphore(value: 0)

        monitor.pathUpdateHandler = { path in
            hasConnection = path.status == .satisfied
            semaphore.signal()
        }

        let queue = DispatchQueue(label: "network.check")
        monitor.start(queue: queue)

        _ = semaphore.wait(timeout: .now() + 0.5)
        monitor.cancel()

        return hasConnection
    }
}

// MARK: - Chat Recipient

/// Represents a potential chat recipient
public struct ChatRecipient: Identifiable, Hashable {
    public let id: String
    public let deviceId: String
    public let callsign: String
    public let nickname: String?

    public init(deviceId: String, callsign: String, nickname: String? = nil) {
        self.id = deviceId
        self.deviceId = deviceId
        self.callsign = callsign
        self.nickname = nickname
    }

    /// Display name for the recipient
    public var displayName: String {
        if let nick = nickname, !nick.isEmpty {
            return "\(callsign) (\(nick))"
        }
        return callsign
    }
}

// MARK: - Sequence Extension

extension Sequence {
    /// Returns array with duplicates removed based on key
    func uniqued<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}
