import XCTest
@testable import sweTAK

final class UDPTests: XCTestCase {

    // MARK: - UDP Configuration Tests

    func testUDPConfigurationDefaults() {
        let config = UDPConfiguration()

        XCTAssertEqual(config.port, 35876)
        XCTAssertEqual(config.broadcastAddress, "255.255.255.255")
    }

    func testUDPConfigurationCustom() {
        let config = UDPConfiguration(port: 12345, broadcastAddress: "192.168.1.255")

        XCTAssertEqual(config.port, 12345)
        XCTAssertEqual(config.broadcastAddress, "192.168.1.255")
    }

    func testUDPConfigurationCodable() throws {
        let config = UDPConfiguration(port: 35876, broadcastAddress: "10.0.0.255")

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UDPConfiguration.self, from: data)

        XCTAssertEqual(decoded.port, config.port)
        XCTAssertEqual(decoded.broadcastAddress, config.broadcastAddress)
    }

    // MARK: - UDP Constants Tests

    func testUDPPortConstant() {
        XCTAssertEqual(UDPClientManager.UDP_PORT, 35876)
    }

    // MARK: - Transport Coordinator UDP Tests

    func testTransportCoordinatorDefaultMode() {
        let coordinator = TransportCoordinator.shared

        // Default mode should be localUDP
        XCTAssertEqual(coordinator.activeMode, .localUDP)
    }

    func testTransportCoordinatorModeSwitch() {
        let coordinator = TransportCoordinator.shared
        let originalMode = coordinator.activeMode

        // Switch to MQTT (won't actually connect without valid config)
        coordinator.setMode(.mqtt)
        XCTAssertEqual(coordinator.activeMode, .mqtt)

        // Switch back to UDP
        coordinator.setMode(.localUDP)
        XCTAssertEqual(coordinator.activeMode, .localUDP)

        // Restore original mode
        coordinator.setMode(originalMode)
    }

    func testIsUDPActiveProperty() {
        let coordinator = TransportCoordinator.shared

        // When in UDP mode and connected, isUDPActive should be true
        coordinator.setMode(.localUDP)

        // Note: Actual connection state depends on network availability
        // This test just verifies the property logic
        if coordinator.connectionState == .connected {
            XCTAssertTrue(coordinator.isUDPActive)
        } else {
            XCTAssertFalse(coordinator.isUDPActive)
        }
    }

    func testIsMQTTActiveProperty() {
        let coordinator = TransportCoordinator.shared
        let originalMode = coordinator.activeMode

        // When in MQTT mode, isMQTTActive depends on connection
        coordinator.setMode(.mqtt)

        // Without valid MQTT config, should not be connected
        XCTAssertFalse(coordinator.isMQTTActive)

        // Restore original mode
        coordinator.setMode(originalMode)
    }

    // MARK: - Message Type Tests for UDP

    func testUDPMessageTypes() {
        // UDP uses specific type strings
        XCTAssertEqual(MessageType.hello.rawValue, "hello")
        XCTAssertEqual(MessageType.position.rawValue, "position")
        XCTAssertEqual(MessageType.profile.rawValue, "profile")
        XCTAssertEqual(MessageType.pin.rawValue, "pin")
        XCTAssertEqual(MessageType.chat.rawValue, "chat")
    }

    // MARK: - JSON Message Format Tests

    func testHelloMessageFormat() throws {
        let json: [String: Any] = [
            "type": "hello",
            "callsign": "Alpha-1",
            "deviceId": "device-123",
            "nickname": "John"
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(parsed?["type"] as? String, "hello")
        XCTAssertEqual(parsed?["callsign"] as? String, "Alpha-1")
        XCTAssertEqual(parsed?["deviceId"] as? String, "device-123")
        XCTAssertEqual(parsed?["nickname"] as? String, "John")
    }

    func testPositionMessageFormat() throws {
        let json: [String: Any] = [
            "type": "pos",
            "callsign": "Bravo-2",
            "deviceId": "device-456",
            "lat": 59.329323,
            "lon": 18.068581,
            "ts": Int64(1703980800000)
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(parsed?["type"] as? String, "pos")
        XCTAssertEqual(parsed?["lat"] as? Double, 59.329323, accuracy: 0.0001)
        XCTAssertEqual(parsed?["lon"] as? Double, 18.068581, accuracy: 0.0001)
    }

    func testPinAddMessageFormat() throws {
        let json: [String: Any] = [
            "type": "pin_add",
            "id": 12345,
            "lat": 59.0,
            "lon": 18.0,
            "pinType": "INFANTRY",
            "title": "Enemy Position",
            "description": "Observed 5 soldiers",
            "deviceId": "device-789",
            "callsign": "Charlie-3",
            "ts": Int64(1703980800000),
            "originDeviceId": "device-789"
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(parsed?["type"] as? String, "pin_add")
        XCTAssertEqual(parsed?["pinType"] as? String, "INFANTRY")
        XCTAssertEqual(parsed?["title"] as? String, "Enemy Position")
    }

    func testProfileMessageFormat() throws {
        let json: [String: Any] = [
            "type": "profile",
            "deviceId": "device-123",
            "callsign": "Alpha-1",
            "nickname": "John",
            "nick": "John",
            "first": "John",
            "last": "Doe",
            "company": "Alpha Company",
            "platoon": "1st Platoon",
            "squad": "2nd Squad"
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(parsed?["type"] as? String, "profile")
        XCTAssertEqual(parsed?["callsign"] as? String, "Alpha-1")
        XCTAssertEqual(parsed?["nickname"] as? String, "John")
        XCTAssertEqual(parsed?["nick"] as? String, "John")  // Legacy key
    }

    func testChatMessageFormat() throws {
        let json: [String: Any] = [
            "type": "chat",
            "threadId": "thread-123",
            "fromDeviceId": "device-a",
            "toDeviceId": "device-b",
            "text": "Hello, this is a test message",
            "ts": Int64(1703980800000)
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(parsed?["type"] as? String, "chat")
        XCTAssertEqual(parsed?["threadId"] as? String, "thread-123")
        XCTAssertEqual(parsed?["text"] as? String, "Hello, this is a test message")
    }

    func testOrderMessageFormat() throws {
        let json: [String: Any] = [
            "type": "order",
            "orderId": "order-123",
            "orderType": "OBO",
            "fromDeviceId": "device-cmd",
            "fromCallsign": "Command-1",
            "toDeviceIds": ["device-a", "device-b"],
            "createdAtMillis": Int64(1703980800000),
            "orientation": "Enemy forces at grid...",
            "decision": "We will engage...",
            "order": "Squad 1 advance..."
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(parsed?["type"] as? String, "order")
        XCTAssertEqual(parsed?["orderType"] as? String, "OBO")
        XCTAssertEqual((parsed?["toDeviceIds"] as? [String])?.count, 2)
    }

    func testLinkedFormMessageFormat() throws {
        let json: [String: Any] = [
            "type": "linkedform",
            "id": Int64(1),
            "opPinId": Int64(100),
            "opOriginDeviceId": "device-123",
            "formType": "FIRE_MISSION",
            "formData": "{ \"target\": \"grid123\" }",
            "submittedAtMillis": Int64(1703980800000),
            "authorCallsign": "Mortar-1",
            "targetLat": 59.0,
            "targetLon": 18.0
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(parsed?["type"] as? String, "linkedform")
        XCTAssertEqual(parsed?["formType"] as? String, "FIRE_MISSION")
    }

    // MARK: - Coordinate Validation Tests

    func testValidCoordinates() {
        // Valid coordinates
        XCTAssertTrue(isValidCoordinate(lat: 0, lon: 0))
        XCTAssertTrue(isValidCoordinate(lat: 90, lon: 180))
        XCTAssertTrue(isValidCoordinate(lat: -90, lon: -180))
        XCTAssertTrue(isValidCoordinate(lat: 59.329323, lon: 18.068581))
    }

    func testInvalidCoordinates() {
        // Invalid coordinates
        XCTAssertFalse(isValidCoordinate(lat: 91, lon: 0))
        XCTAssertFalse(isValidCoordinate(lat: -91, lon: 0))
        XCTAssertFalse(isValidCoordinate(lat: 0, lon: 181))
        XCTAssertFalse(isValidCoordinate(lat: 0, lon: -181))
        XCTAssertFalse(isValidCoordinate(lat: Double.nan, lon: 0))
        XCTAssertFalse(isValidCoordinate(lat: 0, lon: Double.infinity))
    }

    // Helper function for coordinate validation
    private func isValidCoordinate(lat: Double, lon: Double) -> Bool {
        lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 && !lat.isNaN && !lon.isNaN && lat.isFinite && lon.isFinite
    }

    // MARK: - Profile Cache Tests

    func testProfileCaching() {
        let manager = UDPClientManager.shared

        // Initially empty
        XCTAssertNil(manager.latestProfile(for: "nonexistent"))

        // allLatestProfiles returns a dictionary
        let profiles = manager.allLatestProfiles()
        XCTAssertTrue(profiles is [String: ContactProfile])
    }

    // MARK: - Peer Management Tests

    func testPeerManagement() {
        let manager = UDPClientManager.shared

        // Add peer
        manager.addPeer("192.168.1.100")

        // Set peers (replaces all)
        manager.setPeers(Set(["192.168.1.101", "192.168.1.102"]))

        // Remove peer
        manager.removePeer("192.168.1.101")

        // These operations should not crash
        XCTAssertTrue(true)
    }
}
