import XCTest
import SwiftUI
@testable import sweTAK

final class ViewTests: XCTestCase {

    // MARK: - ContactBookScreen Tests

    func testContactBookScreenInitialization() {
        let screen = ContactBookScreen()
        XCTAssertNotNil(screen)
    }

    // MARK: - ChatScreen Tests

    func testChatScreenInitialization() {
        let screen = ChatScreen(
            threadId: "test-thread",
            peerCallsign: "Alpha-1",
            peerNickname: "John"
        )
        XCTAssertNotNil(screen)
    }

    func testChatThreadsScreenInitialization() {
        let screen = ChatThreadsScreen()
        XCTAssertNotNil(screen)
    }

    func testChatRecipientPickerInitialization() {
        let picker = ChatRecipientPicker { _ in }
        XCTAssertNotNil(picker)
    }

    // MARK: - SettingsScreen Tests

    func testSettingsScreenInitialization() {
        let screen = SettingsScreen()
        XCTAssertNotNil(screen)
    }

    // MARK: - OrdersScreen Tests

    func testOrdersListScreenInitialization() {
        let screen = OrdersListScreen()
        XCTAssertNotNil(screen)
    }

    func testOrderDetailScreenInitialization() {
        let order = Order(
            type: .obo,
            senderDeviceId: "device-123",
            senderCallsign: "Command-1",
            orientation: "Test orientation",
            decision: "Test decision",
            order: "Test order",
            recipientDeviceIds: ["device-a"],
            direction: .incoming
        )
        let screen = OrderDetailScreen(order: order)
        XCTAssertNotNil(screen)
    }

    // MARK: - MainView Tests

    func testMainViewInitialization() {
        let view = MainView()
        XCTAssertNotNil(view)
    }

    func testProfileScreenInitialization() {
        let screen = ProfileScreen()
        XCTAssertNotNil(screen)
    }

    // MARK: - Model Display Tests

    func testMilitaryRoleDisplay() {
        XCTAssertEqual(MilitaryRole.companyCommander.displayName, "Company Commander")
        XCTAssertEqual(MilitaryRole.companyCommander.abbreviation, "CC")

        XCTAssertEqual(MilitaryRole.platoonLeader.displayName, "Platoon Leader")
        XCTAssertEqual(MilitaryRole.platoonLeader.abbreviation, "PL")

        XCTAssertEqual(MilitaryRole.squadLeader.displayName, "Squad Leader")
        XCTAssertEqual(MilitaryRole.squadLeader.abbreviation, "SL")

        XCTAssertEqual(MilitaryRole.soldier.displayName, "Soldier")
        XCTAssertEqual(MilitaryRole.soldier.abbreviation, "Soldier")
    }

    func testMilitaryRoleParsing() {
        XCTAssertEqual(MilitaryRole.from("COMPANY_COMMANDER"), .companyCommander)
        XCTAssertEqual(MilitaryRole.from("Company Commander"), .companyCommander)
        XCTAssertEqual(MilitaryRole.from("CC"), .companyCommander)
        XCTAssertEqual(MilitaryRole.from(""), .none)
        XCTAssertEqual(MilitaryRole.from(nil), .none)
        XCTAssertEqual(MilitaryRole.from("invalid"), .none)
    }

    func testOrderTypeDisplay() {
        XCTAssertEqual(OrderType.obo.displayName, "OBO Order")
        XCTAssertEqual(OrderType.fiveP.displayName, "5P Order")
    }

    func testContactProfileDisplay() {
        let profile1 = ContactProfile(
            deviceId: "device-123",
            callsign: "Alpha-1",
            nickname: "John",
            firstName: "John",
            lastName: "Doe"
        )
        XCTAssertEqual(profile1.displayName, "Alpha-1")
        XCTAssertEqual(profile1.fullName, "John Doe")

        let profile2 = ContactProfile(
            deviceId: "device-456",
            nickname: "Jane"
        )
        XCTAssertEqual(profile2.displayName, "Jane")
        XCTAssertNil(profile2.fullName)

        let profile3 = ContactProfile(deviceId: "device-789")
        XCTAssertEqual(profile3.displayName, "device-789")
    }

    func testContactProfileOnlineStatus() {
        // Online (recent)
        let onlineProfile = ContactProfile(
            deviceId: "device-1",
            lastSeenMs: Int64(Date().timeIntervalSince1970 * 1000)
        )
        XCTAssertTrue(onlineProfile.isOnline)

        // Offline (old timestamp)
        let oldTimestamp = Int64((Date().timeIntervalSince1970 - 600) * 1000) // 10 minutes ago
        let offlineProfile = ContactProfile(
            deviceId: "device-2",
            lastSeenMs: oldTimestamp
        )
        XCTAssertFalse(offlineProfile.isOnline)
    }

    // MARK: - Settings Model Tests

    func testMapStyleCases() {
        XCTAssertEqual(MapStyle.allCases.count, 4)
        XCTAssertTrue(MapStyle.allCases.contains(.satellite))
        XCTAssertTrue(MapStyle.allCases.contains(.terrain))
        XCTAssertTrue(MapStyle.allCases.contains(.streets))
        XCTAssertTrue(MapStyle.allCases.contains(.dark))
    }

    func testCoordinateFormatCases() {
        XCTAssertEqual(CoordinateFormat.allCases.count, 4)
        XCTAssertTrue(CoordinateFormat.allCases.contains(.mgrs))
        XCTAssertTrue(CoordinateFormat.allCases.contains(.decimal))
        XCTAssertTrue(CoordinateFormat.allCases.contains(.dms))
        XCTAssertTrue(CoordinateFormat.allCases.contains(.utm))
    }

    func testUnitSystemCases() {
        XCTAssertEqual(UnitSystem.allCases.count, 2)
        XCTAssertTrue(UnitSystem.allCases.contains(.metric))
        XCTAssertTrue(UnitSystem.allCases.contains(.imperial))
    }

    func testMapOrientationModeCases() {
        XCTAssertEqual(MapOrientationMode.allCases.count, 3)
        XCTAssertTrue(MapOrientationMode.allCases.contains(.northUp))
        XCTAssertTrue(MapOrientationMode.allCases.contains(.freeRotate))
        XCTAssertTrue(MapOrientationMode.allCases.contains(.headingUp))
    }

    // MARK: - Chat Model Tests

    func testChatMessageCreationIncoming() {
        let message = ChatMessage(
            threadId: "thread-1",
            fromDeviceId: "device-a",
            toDeviceId: "device-b",
            text: "Hello!",
            direction: .incoming
        )

        XCTAssertEqual(message.threadId, "thread-1")
        XCTAssertEqual(message.fromDeviceId, "device-a")
        XCTAssertEqual(message.text, "Hello!")
        XCTAssertEqual(message.direction, .incoming)
        XCTAssertFalse(message.acknowledged)
    }

    func testChatMessageCreationOutgoing() {
        let message = ChatMessage(
            threadId: "thread-1",
            fromDeviceId: "device-b",
            toDeviceId: "device-a",
            text: "Hi there!",
            direction: .outgoing
        )

        XCTAssertEqual(message.direction, .outgoing)
    }

    // MARK: - Order Model Tests

    func testOrderCreationOBO() {
        let order = Order(
            type: .obo,
            senderDeviceId: "sender-123",
            senderCallsign: "Command",
            orientation: "Enemy at grid...",
            decision: "We will attack...",
            order: "Squad 1 move...",
            recipientDeviceIds: ["r1", "r2"],
            direction: .outgoing
        )

        XCTAssertEqual(order.type, .obo)
        XCTAssertEqual(order.senderCallsign, "Command")
        XCTAssertEqual(order.recipientDeviceIds.count, 2)
        XCTAssertFalse(order.isRead)
    }

    func testOrderCreation5P() {
        let order = Order(
            type: .fiveP,
            senderDeviceId: "sender-456",
            senderCallsign: "HQ",
            orientation: "Purpose...",
            decision: "Plan...",
            order: "Preconditions...",
            mission: "Mission details...",
            execution: "Execution plan...",
            logistics: "Supply routes...",
            commandSignaling: "Radio frequencies...",
            recipientDeviceIds: ["r1"],
            direction: .outgoing
        )

        XCTAssertEqual(order.type, .fiveP)
        XCTAssertNotNil(order.mission)
        XCTAssertNotNil(order.execution)
        XCTAssertNotNil(order.logistics)
        XCTAssertNotNil(order.commandSignaling)
    }

    // MARK: - GPS Interval Tests

    func testGPSIntervalSeconds() {
        let interval = GPSInterval(value: 30, unit: "s")
        XCTAssertEqual(interval.totalSeconds, 30)
        XCTAssertEqual(interval.displayString, "30s")
    }

    func testGPSIntervalMinutes() {
        let interval = GPSInterval(value: 5, unit: "m")
        XCTAssertEqual(interval.totalSeconds, 300)
        XCTAssertEqual(interval.displayString, "5m")
    }

    // MARK: - MQTT Settings Tests

    func testMQTTSettingsValidation() {
        var settings = MQTTSettings()
        XCTAssertFalse(settings.isValid)

        settings.host = "mqtt.example.com"
        XCTAssertTrue(settings.isValid)

        settings.port = 0
        XCTAssertFalse(settings.isValid)

        settings.port = 8883
        XCTAssertTrue(settings.isValid)
    }

    func testMQTTSettingsDefaults() {
        let settings = MQTTSettings()
        XCTAssertEqual(settings.port, 8883)
        XCTAssertTrue(settings.useTls)
        XCTAssertEqual(settings.maxMessageAgeMinutes, 360)
    }
}
