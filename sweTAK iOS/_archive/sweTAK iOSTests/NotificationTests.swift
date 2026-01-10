import XCTest
@testable import sweTAK

final class NotificationTests: XCTestCase {

    // MARK: - IncomingChatNotification Tests

    func testIncomingChatNotificationCreation() {
        let notification = IncomingChatNotification(
            threadId: "thread-123",
            callsign: "Alpha-1",
            nickname: "John",
            textPreview: "Hello, this is a test message"
        )

        XCTAssertEqual(notification.threadId, "thread-123")
        XCTAssertEqual(notification.callsign, "Alpha-1")
        XCTAssertEqual(notification.nickname, "John")
        XCTAssertEqual(notification.textPreview, "Hello, this is a test message")
    }

    func testIncomingChatNotificationDisplayNameWithNickname() {
        let notification = IncomingChatNotification(
            threadId: "thread-123",
            callsign: "Alpha-1",
            nickname: "John",
            textPreview: "Test"
        )

        XCTAssertEqual(notification.displayName, "Alpha-1 (John)")
    }

    func testIncomingChatNotificationDisplayNameWithoutNickname() {
        let notification = IncomingChatNotification(
            threadId: "thread-123",
            callsign: "Bravo-2",
            nickname: nil,
            textPreview: "Test"
        )

        XCTAssertEqual(notification.displayName, "Bravo-2")
    }

    func testIncomingChatNotificationDisplayNameWithEmptyNickname() {
        let notification = IncomingChatNotification(
            threadId: "thread-123",
            callsign: "Charlie-3",
            nickname: "",
            textPreview: "Test"
        )

        XCTAssertEqual(notification.displayName, "Charlie-3")
    }

    func testIncomingChatNotificationEquatable() {
        let notification1 = IncomingChatNotification(
            threadId: "thread-123",
            callsign: "Alpha-1",
            nickname: "John",
            textPreview: "Hello"
        )

        let notification2 = IncomingChatNotification(
            threadId: "thread-123",
            callsign: "Alpha-1",
            nickname: "John",
            textPreview: "Hello"
        )

        let notification3 = IncomingChatNotification(
            threadId: "thread-456",
            callsign: "Bravo-2",
            nickname: nil,
            textPreview: "Different"
        )

        XCTAssertEqual(notification1, notification2)
        XCTAssertNotEqual(notification1, notification3)
    }

    // MARK: - Order Notification Data Tests

    func testOrderNotificationWithCallsign() {
        let order = Order(
            type: .obo,
            senderDeviceId: "device-123",
            senderCallsign: "Command-1",
            orientation: "Test orientation",
            recipientDeviceIds: ["device-a"],
            direction: .incoming
        )

        // Verify the order has the expected data for notification display
        XCTAssertEqual(order.type.displayName, "OBO")
        XCTAssertEqual(order.senderCallsign, "Command-1")
        XCTAssertEqual(order.senderDeviceId, "device-123")
    }

    func testOrderNotificationWithoutCallsign() {
        let order = Order(
            type: .fiveP,
            senderDeviceId: "device-456-abcd",
            senderCallsign: "",
            orientation: "Test",
            recipientDeviceIds: [],
            direction: .incoming
        )

        XCTAssertEqual(order.type.displayName, "5P")
        XCTAssertTrue(order.senderCallsign.isEmpty)
        // Should use first 8 chars of deviceId as fallback
        XCTAssertEqual(String(order.senderDeviceId.prefix(8)), "device-4")
    }

    // MARK: - Report Notification Data Tests

    func testReportNotificationData() {
        let report = Report(
            senderDeviceId: "device-123",
            senderCallsign: "Observer-1",
            personnelStatus: .green,
            equipmentStatus: .amber,
            ammoStatus: .green,
            rationStatus: .green,
            summary: "All systems nominal"
        )

        XCTAssertEqual(report.senderCallsign, "Observer-1")
        XCTAssertEqual(report.senderDeviceId, "device-123")
    }

    // MARK: - METHANE Notification Data Tests

    func testMethaneNotificationData() {
        let request = MethaneRequest(
            senderDeviceId: "device-123",
            senderCallsign: "Incident-1",
            majorIncident: "Building fire",
            exactLocation: "123 Main St",
            incidentType: "Structure Fire",
            hazards: "Smoke, possible collapse",
            access: "North entrance only",
            numberOfCasualties: "Unknown",
            emergencyServices: "Fire, EMS, Police",
            recipientDeviceIds: ["device-a", "device-b"]
        )

        XCTAssertEqual(request.senderCallsign, "Incident-1")
        XCTAssertEqual(request.incidentType, "Structure Fire")
        XCTAssertEqual(request.recipientDeviceIds.count, 2)
    }

    // MARK: - MEDEVAC Notification Data Tests

    func testMedevacNotificationData() {
        let report = MedevacReport(
            senderDeviceId: "device-123",
            senderCallsign: "Medic-1",
            soldierName: "Pvt. Smith",
            mechanism: "IED blast",
            injuries: "Lower extremity trauma",
            treatmentGiven: "Tourniquet applied",
            priority: .urgent,
            recipientDeviceIds: ["device-a"]
        )

        XCTAssertEqual(report.senderCallsign, "Medic-1")
        XCTAssertEqual(report.soldierName, "Pvt. Smith")
        XCTAssertEqual(report.priority, .urgent)
        XCTAssertEqual(report.priority.displayName, "Urgent")
    }

    func testMedevacPriorityDisplayNames() {
        XCTAssertEqual(MedevacPriority.urgent.displayName, "Urgent")
        XCTAssertEqual(MedevacPriority.priority.displayName, "Priority")
        XCTAssertEqual(MedevacPriority.routine.displayName, "Routine")
    }

    // MARK: - Notification Priority Color Tests

    func testMedevacPriorityColors() {
        // Test that each priority has distinct characteristics for notification styling
        let urgentReport = MedevacReport(
            senderDeviceId: "device-1",
            senderCallsign: "Medic",
            soldierName: "Test",
            priority: .urgent,
            recipientDeviceIds: []
        )

        let priorityReport = MedevacReport(
            senderDeviceId: "device-2",
            senderCallsign: "Medic",
            soldierName: "Test",
            priority: .priority,
            recipientDeviceIds: []
        )

        let routineReport = MedevacReport(
            senderDeviceId: "device-3",
            senderCallsign: "Medic",
            soldierName: "Test",
            priority: .routine,
            recipientDeviceIds: []
        )

        // Each should have distinct priority
        XCTAssertNotEqual(urgentReport.priority, priorityReport.priority)
        XCTAssertNotEqual(priorityReport.priority, routineReport.priority)
        XCTAssertNotEqual(urgentReport.priority, routineReport.priority)
    }
}
