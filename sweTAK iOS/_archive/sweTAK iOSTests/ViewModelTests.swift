import XCTest
import CoreLocation
@testable import sweTAK

final class ViewModelTests: XCTestCase {

    // MARK: - MapViewModel Tests

    func testMapViewModelSingleton() {
        let vm1 = MapViewModel.shared
        let vm2 = MapViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    func testMapViewModelDefaultState() {
        let vm = MapViewModel.shared

        XCTAssertNil(vm.myPosition)
        XCTAssertEqual(vm.zoom, 14.0)
        XCTAssertEqual(vm.mapBearing, 0.0)
        XCTAssertFalse(vm.followMe)
        XCTAssertFalse(vm.hasCenteredInitially)
    }

    func testMapViewModelPositionUpdate() {
        let vm = MapViewModel.shared
        let testCoord = CLLocationCoordinate2D(latitude: 59.329323, longitude: 18.068581)

        vm.updateMyPosition(testCoord, altitude: 100.0)

        XCTAssertNotNil(vm.myPosition)
        XCTAssertEqual(vm.myPosition?.latitude, 59.329323, accuracy: 0.0001)
        XCTAssertEqual(vm.myPosition?.longitude, 18.068581, accuracy: 0.0001)
        XCTAssertEqual(vm.myAltitudeMeters, 100.0)
    }

    func testMapViewModelFollowModeToggle() {
        let vm = MapViewModel.shared
        let initialState = vm.followMe

        vm.toggleFollowMe()
        XCTAssertNotEqual(vm.followMe, initialState)

        vm.toggleFollowMe()
        XCTAssertEqual(vm.followMe, initialState)
    }

    func testMapOrientationModes() {
        XCTAssertEqual(MapOrientationMode.northUp.rawValue, "NORTH_UP")
        XCTAssertEqual(MapOrientationMode.freeRotate.rawValue, "FREE_ROTATE")
        XCTAssertEqual(MapOrientationMode.headingUp.rawValue, "HEADING_UP")

        XCTAssertEqual(MapOrientationMode.northUp.displayName, "North Up")
        XCTAssertEqual(MapOrientationMode.freeRotate.displayName, "Free Rotate")
        XCTAssertEqual(MapOrientationMode.headingUp.displayName, "Heading Up")
    }

    func testCameraState() {
        let camera = CameraState(latitude: 59.0, longitude: 18.0, zoom: 15.0, bearing: 45.0)

        XCTAssertEqual(camera.latitude, 59.0)
        XCTAssertEqual(camera.longitude, 18.0)
        XCTAssertEqual(camera.zoom, 15.0)
        XCTAssertEqual(camera.bearing, 45.0)
        XCTAssertEqual(camera.coordinate.latitude, 59.0)
        XCTAssertEqual(camera.coordinate.longitude, 18.0)
    }

    func testPeerPosition() {
        let peer = PeerPosition(
            deviceId: "device-123",
            callsign: "Alpha-1",
            latitude: 59.329323,
            longitude: 18.068581
        )

        XCTAssertEqual(peer.id, "device-123")
        XCTAssertEqual(peer.callsign, "Alpha-1")
        XCTAssertEqual(peer.coordinate.latitude, 59.329323)
        XCTAssertEqual(peer.coordinate.longitude, 18.068581)
    }

    // MARK: - PinsViewModel Tests

    func testPinsViewModelSingleton() {
        let vm1 = PinsViewModel.shared
        let vm2 = PinsViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    func testPinsViewModelGeneratePinId() {
        let vm = PinsViewModel.shared
        let id1 = vm.generatePinId()
        let id2 = vm.generatePinId()

        // IDs should be unique (though not necessarily sequential after pin additions)
        XCTAssertGreaterThan(id1, 0)
        XCTAssertGreaterThan(id2, 0)
    }

    // MARK: - ContactsViewModel Tests

    func testContactsViewModelSingleton() {
        let vm1 = ContactsViewModel.shared
        let vm2 = ContactsViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    func testContactsViewModelBlocking() {
        let vm = ContactsViewModel.shared
        let testDeviceId = "test-blocked-device"

        // Block
        vm.blockDevice(testDeviceId)
        XCTAssertTrue(vm.isBlocked(testDeviceId))

        // Unblock
        vm.unblockDevice(testDeviceId)
        XCTAssertFalse(vm.isBlocked(testDeviceId))
    }

    // MARK: - ChatViewModel Tests

    func testChatViewModelSingleton() {
        let vm1 = ChatViewModel.shared
        let vm2 = ChatViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    func testChatUIStateDefaults() {
        let state = ChatUIState()

        XCTAssertTrue(state.messages.isEmpty)
        XCTAssertTrue(state.inputText.isEmpty)
        XCTAssertFalse(state.isSendEnabled)
    }

    func testChatViewModelInputHandling() {
        let vm = ChatViewModel.shared

        // Empty input should not enable send
        vm.onInputTextChanged("")
        XCTAssertFalse(vm.uiState.isSendEnabled)

        // Whitespace only should not enable send
        vm.onInputTextChanged("   ")
        XCTAssertFalse(vm.uiState.isSendEnabled)

        // Valid input should enable send
        vm.onInputTextChanged("Hello")
        XCTAssertTrue(vm.uiState.isSendEnabled)
        XCTAssertEqual(vm.uiState.inputText, "Hello")

        // Clear for next test
        vm.onInputTextChanged("")
    }

    // MARK: - SettingsViewModel Tests

    func testSettingsViewModelSingleton() {
        let vm1 = SettingsViewModel.shared
        let vm2 = SettingsViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    func testSettingsStateDefaults() {
        let state = SettingsState()

        XCTAssertFalse(state.isDarkMode)
        XCTAssertEqual(state.unitSystem, .metric)
        XCTAssertEqual(state.coordFormat, .mgrs)
        XCTAssertEqual(state.mapStyle, .satellite)
        XCTAssertFalse(state.messageSigningEnabled)
    }

    func testCoordinateFormats() {
        XCTAssertEqual(CoordinateFormat.mgrs.rawValue, "MGRS")
        XCTAssertEqual(CoordinateFormat.decimal.rawValue, "Decimal")
        XCTAssertEqual(CoordinateFormat.dms.rawValue, "DMS")
        XCTAssertEqual(CoordinateFormat.utm.rawValue, "UTM")
    }

    func testUnitSystems() {
        XCTAssertEqual(UnitSystem.metric.rawValue, "Metric")
        XCTAssertEqual(UnitSystem.imperial.rawValue, "Imperial")
    }

    func testMapStyles() {
        XCTAssertEqual(MapStyle.satellite.rawValue, "Satellite")
        XCTAssertEqual(MapStyle.terrain.rawValue, "Terrain")
        XCTAssertEqual(MapStyle.streets.rawValue, "Streets")
        XCTAssertEqual(MapStyle.dark.rawValue, "Dark")
    }

    func testGPSInterval() {
        let interval1 = GPSInterval(value: 5, unit: "s")
        XCTAssertEqual(interval1.totalSeconds, 5)
        XCTAssertEqual(interval1.displayString, "5s")

        let interval2 = GPSInterval(value: 2, unit: "m")
        XCTAssertEqual(interval2.totalSeconds, 120)
        XCTAssertEqual(interval2.displayString, "2m")
    }

    func testMQTTSettings() {
        var settings = MQTTSettings()

        XCTAssertTrue(settings.host.isEmpty)
        XCTAssertEqual(settings.port, 8883)
        XCTAssertTrue(settings.useTls)
        XCTAssertFalse(settings.isValid)

        settings.host = "mqtt.example.com"
        XCTAssertTrue(settings.isValid)
    }

    // MARK: - OrdersViewModel Tests

    func testOrdersViewModelSingleton() {
        let vm1 = OrdersViewModel.shared
        let vm2 = OrdersViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    func testOrderRecipientStatus() {
        let status = OrderRecipientStatus(
            orderId: "order-123",
            recipientDeviceId: "device-456",
            recipientCallsign: "Alpha-1",
            sentAtMillis: 1000000,
            deliveredAtMillis: nil,
            readAtMillis: nil
        )

        XCTAssertEqual(status.id, "order-123-device-456")
        XCTAssertEqual(status.orderId, "order-123")
        XCTAssertEqual(status.recipientDeviceId, "device-456")
        XCTAssertFalse(status.isDelivered)
        XCTAssertFalse(status.isRead)

        let deliveredStatus = OrderRecipientStatus(
            orderId: "order-123",
            recipientDeviceId: "device-456",
            deliveredAtMillis: 2000000
        )
        XCTAssertTrue(deliveredStatus.isDelivered)
        XCTAssertFalse(deliveredStatus.isRead)

        let readStatus = OrderRecipientStatus(
            orderId: "order-123",
            recipientDeviceId: "device-456",
            deliveredAtMillis: 2000000,
            readAtMillis: 3000000
        )
        XCTAssertTrue(readStatus.isDelivered)
        XCTAssertTrue(readStatus.isRead)
    }

    // MARK: - Model Integration Tests

    func testOrderCreation() {
        let order = Order(
            type: .obo,
            senderDeviceId: "sender-123",
            senderCallsign: "Command-1",
            orientation: "Enemy forces at...",
            decision: "We will engage...",
            order: "Squad 1 advance...",
            recipientDeviceIds: ["device-a", "device-b"],
            direction: .outgoing
        )

        XCTAssertEqual(order.type, .obo)
        XCTAssertEqual(order.senderCallsign, "Command-1")
        XCTAssertEqual(order.recipientDeviceIds.count, 2)
        XCTAssertEqual(order.direction, .outgoing)
        XCTAssertFalse(order.isRead)
    }

    func testChatMessageCreation() {
        let message = ChatMessage(
            threadId: "thread-123",
            fromDeviceId: "device-a",
            toDeviceId: "device-b",
            text: "Hello, World!",
            direction: .outgoing
        )

        XCTAssertEqual(message.threadId, "thread-123")
        XCTAssertEqual(message.text, "Hello, World!")
        XCTAssertEqual(message.direction, .outgoing)
        XCTAssertFalse(message.acknowledged)
    }

    func testContactProfileCreation() {
        let profile = ContactProfile(
            deviceId: "device-123",
            callsign: "Alpha-1",
            nickname: "John",
            firstName: "John",
            lastName: "Doe",
            role: .squadLeader
        )

        XCTAssertEqual(profile.deviceId, "device-123")
        XCTAssertEqual(profile.callsign, "Alpha-1")
        XCTAssertEqual(profile.nickname, "John")
        XCTAssertEqual(profile.role, .squadLeader)
        XCTAssertEqual(profile.displayName, "Alpha-1")
    }
}
