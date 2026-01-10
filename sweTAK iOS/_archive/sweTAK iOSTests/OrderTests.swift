import XCTest
@testable import sweTAK

final class OrderTests: XCTestCase {

    // MARK: - OrderType Tests

    func testOrderTypeRawValues() {
        XCTAssertEqual(OrderType.obo.rawValue, "OBO")
        XCTAssertEqual(OrderType.fiveP.rawValue, "FIVE_P")
    }

    func testOrderTypeDisplayNames() {
        XCTAssertEqual(OrderType.obo.displayName, "OBO")
        XCTAssertEqual(OrderType.fiveP.displayName, "5P")
    }

    func testOrderTypeFieldCounts() {
        XCTAssertEqual(OrderType.obo.fieldCount, 3)
        XCTAssertEqual(OrderType.fiveP.fieldCount, 5)
    }

    func testOrderTypeCaseIterable() {
        XCTAssertEqual(OrderType.allCases.count, 2)
        XCTAssertTrue(OrderType.allCases.contains(.obo))
        XCTAssertTrue(OrderType.allCases.contains(.fiveP))
    }

    // MARK: - OrderDirection Tests

    func testOrderDirectionRawValues() {
        XCTAssertEqual(OrderDirection.outgoing.rawValue, "OUTGOING")
        XCTAssertEqual(OrderDirection.incoming.rawValue, "INCOMING")
    }

    // MARK: - OrderAckType Tests

    func testOrderAckTypeRawValues() {
        XCTAssertEqual(OrderAckType.delivered.rawValue, "DELIVERED")
        XCTAssertEqual(OrderAckType.read.rawValue, "READ")
    }

    // MARK: - OBO Order Tests

    func testOBOOrderCreation() {
        let order = Order(
            type: .obo,
            senderDeviceId: "device-123",
            senderCallsign: "Command-1",
            orientation: "Enemy forces spotted at grid reference",
            decision: "Engage from elevated position",
            order: "Squad 1 advance to waypoint Alpha",
            recipientDeviceIds: ["device-a", "device-b"],
            direction: .outgoing
        )

        XCTAssertEqual(order.type, .obo)
        XCTAssertEqual(order.senderDeviceId, "device-123")
        XCTAssertEqual(order.senderCallsign, "Command-1")
        XCTAssertEqual(order.orientation, "Enemy forces spotted at grid reference")
        XCTAssertEqual(order.decision, "Engage from elevated position")
        XCTAssertEqual(order.order, "Squad 1 advance to waypoint Alpha")
        XCTAssertEqual(order.recipientDeviceIds.count, 2)
        XCTAssertEqual(order.direction, .outgoing)
        XCTAssertFalse(order.isRead)
    }

    func testOBOOrderDefaultValues() {
        let order = Order(
            type: .obo,
            senderDeviceId: "device-123",
            senderCallsign: "Command-1",
            orientation: "Test orientation",
            recipientDeviceIds: [],
            direction: .outgoing
        )

        XCTAssertEqual(order.decision, "")
        XCTAssertEqual(order.order, "")
        XCTAssertEqual(order.mission, "")
        XCTAssertEqual(order.execution, "")
        XCTAssertEqual(order.logistics, "")
        XCTAssertEqual(order.commandSignaling, "")
        XCTAssertFalse(order.isRead)
    }

    // MARK: - 5P Order Tests

    func testFivePOrderCreation() {
        let order = Order(
            type: .fiveP,
            senderDeviceId: "device-456",
            senderCallsign: "HQ-1",
            orientation: "Current situation overview",
            mission: "Secure the perimeter",
            execution: "Phase 1: Recon, Phase 2: Secure",
            logistics: "Resupply at waypoint Bravo",
            commandSignaling: "Radio check every 30 minutes",
            recipientDeviceIds: ["device-x", "device-y", "device-z"],
            direction: .outgoing
        )

        XCTAssertEqual(order.type, .fiveP)
        XCTAssertEqual(order.senderDeviceId, "device-456")
        XCTAssertEqual(order.senderCallsign, "HQ-1")
        XCTAssertEqual(order.orientation, "Current situation overview")
        XCTAssertEqual(order.mission, "Secure the perimeter")
        XCTAssertEqual(order.execution, "Phase 1: Recon, Phase 2: Secure")
        XCTAssertEqual(order.logistics, "Resupply at waypoint Bravo")
        XCTAssertEqual(order.commandSignaling, "Radio check every 30 minutes")
        XCTAssertEqual(order.recipientDeviceIds.count, 3)
    }

    // MARK: - Order JSON Serialization Tests

    func testOrderCodable() throws {
        let original = Order(
            type: .obo,
            senderDeviceId: "device-123",
            senderCallsign: "Alpha-1",
            orientation: "Test orientation",
            decision: "Test decision",
            order: "Test order",
            recipientDeviceIds: ["device-a"],
            direction: .outgoing
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Order.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.senderDeviceId, original.senderDeviceId)
        XCTAssertEqual(decoded.senderCallsign, original.senderCallsign)
        XCTAssertEqual(decoded.orientation, original.orientation)
        XCTAssertEqual(decoded.decision, original.decision)
        XCTAssertEqual(decoded.order, original.order)
        XCTAssertEqual(decoded.recipientDeviceIds, original.recipientDeviceIds)
        XCTAssertEqual(decoded.direction, original.direction)
    }

    func testFivePOrderCodable() throws {
        let original = Order(
            type: .fiveP,
            senderDeviceId: "device-456",
            senderCallsign: "HQ-1",
            orientation: "Orientation text",
            mission: "Mission text",
            execution: "Execution text",
            logistics: "Logistics text",
            commandSignaling: "Command text",
            recipientDeviceIds: ["device-a", "device-b"],
            direction: .incoming,
            isRead: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Order.self, from: data)

        XCTAssertEqual(decoded.type, .fiveP)
        XCTAssertEqual(decoded.mission, original.mission)
        XCTAssertEqual(decoded.execution, original.execution)
        XCTAssertEqual(decoded.logistics, original.logistics)
        XCTAssertEqual(decoded.commandSignaling, original.commandSignaling)
        XCTAssertEqual(decoded.direction, .incoming)
        XCTAssertTrue(decoded.isRead)
    }

    // MARK: - OrderRecipientStatus Tests

    func testOrderRecipientStatusCreation() {
        let status = OrderRecipientStatus(
            orderId: "order-123",
            recipientDeviceId: "device-a",
            recipientCallsign: "Alpha-1",
            sentAtMillis: 1234567890000
        )

        XCTAssertEqual(status.orderId, "order-123")
        XCTAssertEqual(status.recipientDeviceId, "device-a")
        XCTAssertEqual(status.recipientCallsign, "Alpha-1")
        XCTAssertEqual(status.sentAtMillis, 1234567890000)
        XCTAssertNil(status.deliveredAtMillis)
        XCTAssertNil(status.readAtMillis)
        XCTAssertFalse(status.isDelivered)
        XCTAssertFalse(status.isRead)
    }

    func testOrderRecipientStatusDelivered() {
        let status = OrderRecipientStatus(
            orderId: "order-123",
            recipientDeviceId: "device-a",
            recipientCallsign: "Alpha-1",
            sentAtMillis: 1234567890000,
            deliveredAtMillis: 1234567891000
        )

        XCTAssertTrue(status.isDelivered)
        XCTAssertFalse(status.isRead)
    }

    func testOrderRecipientStatusRead() {
        let status = OrderRecipientStatus(
            orderId: "order-123",
            recipientDeviceId: "device-a",
            recipientCallsign: "Alpha-1",
            sentAtMillis: 1234567890000,
            deliveredAtMillis: 1234567891000,
            readAtMillis: 1234567892000
        )

        XCTAssertTrue(status.isDelivered)
        XCTAssertTrue(status.isRead)
    }

    func testOrderRecipientStatusId() {
        let status = OrderRecipientStatus(
            orderId: "order-123",
            recipientDeviceId: "device-a",
            recipientCallsign: nil,
            sentAtMillis: 1234567890000
        )

        XCTAssertEqual(status.id, "order-123-device-a")
    }

    func testOrderRecipientStatusCodable() throws {
        let original = OrderRecipientStatus(
            orderId: "order-123",
            recipientDeviceId: "device-a",
            recipientCallsign: "Alpha-1",
            sentAtMillis: 1234567890000,
            deliveredAtMillis: 1234567891000,
            readAtMillis: 1234567892000
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OrderRecipientStatus.self, from: data)

        XCTAssertEqual(decoded.orderId, original.orderId)
        XCTAssertEqual(decoded.recipientDeviceId, original.recipientDeviceId)
        XCTAssertEqual(decoded.recipientCallsign, original.recipientCallsign)
        XCTAssertEqual(decoded.sentAtMillis, original.sentAtMillis)
        XCTAssertEqual(decoded.deliveredAtMillis, original.deliveredAtMillis)
        XCTAssertEqual(decoded.readAtMillis, original.readAtMillis)
    }

    // MARK: - OrderAck Tests

    func testOrderAckCreation() {
        let ack = OrderAck(
            orderId: "order-123",
            fromDeviceId: "device-a",
            toDeviceId: "device-sender",
            ackType: .delivered
        )

        XCTAssertEqual(ack.orderId, "order-123")
        XCTAssertEqual(ack.fromDeviceId, "device-a")
        XCTAssertEqual(ack.toDeviceId, "device-sender")
        XCTAssertEqual(ack.ackType, .delivered)
    }

    func testOrderAckReadType() {
        let ack = OrderAck(
            orderId: "order-123",
            fromDeviceId: "device-a",
            toDeviceId: "device-sender",
            ackType: .read,
            timestampMillis: 1234567890000
        )

        XCTAssertEqual(ack.ackType, .read)
        XCTAssertEqual(ack.timestampMillis, 1234567890000)
    }

    func testOrderAckCodable() throws {
        let original = OrderAck(
            orderId: "order-123",
            fromDeviceId: "device-a",
            toDeviceId: "device-b",
            ackType: .read,
            timestampMillis: 1234567890000
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OrderAck.self, from: data)

        XCTAssertEqual(decoded.orderId, original.orderId)
        XCTAssertEqual(decoded.fromDeviceId, original.fromDeviceId)
        XCTAssertEqual(decoded.toDeviceId, original.toDeviceId)
        XCTAssertEqual(decoded.ackType, original.ackType)
        XCTAssertEqual(decoded.timestampMillis, original.timestampMillis)
    }

    // MARK: - Order Identifiable Tests

    func testOrderIdentifiable() {
        let order1 = Order(
            id: "unique-id-1",
            type: .obo,
            senderDeviceId: "device-123",
            senderCallsign: "Alpha-1",
            orientation: "Test",
            recipientDeviceIds: [],
            direction: .outgoing
        )

        let order2 = Order(
            id: "unique-id-2",
            type: .obo,
            senderDeviceId: "device-123",
            senderCallsign: "Alpha-1",
            orientation: "Test",
            recipientDeviceIds: [],
            direction: .outgoing
        )

        XCTAssertNotEqual(order1.id, order2.id)
        XCTAssertEqual(order1.id, "unique-id-1")
        XCTAssertEqual(order2.id, "unique-id-2")
    }

    // MARK: - Order Equatable Tests

    func testOrderEquatable() {
        let order1 = Order(
            id: "same-id",
            type: .obo,
            createdAtMillis: 1234567890000,
            senderDeviceId: "device-123",
            senderCallsign: "Alpha-1",
            orientation: "Test orientation",
            decision: "Test decision",
            order: "Test order",
            recipientDeviceIds: ["device-a"],
            direction: .outgoing,
            isRead: false
        )

        let order2 = Order(
            id: "same-id",
            type: .obo,
            createdAtMillis: 1234567890000,
            senderDeviceId: "device-123",
            senderCallsign: "Alpha-1",
            orientation: "Test orientation",
            decision: "Test decision",
            order: "Test order",
            recipientDeviceIds: ["device-a"],
            direction: .outgoing,
            isRead: false
        )

        XCTAssertEqual(order1, order2)
    }

    // MARK: - OrdersViewModel Tests

    func testOrdersViewModelSingleton() {
        let vm1 = OrdersViewModel.shared
        let vm2 = OrdersViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    func testOrdersViewModelProperties() {
        let vm = OrdersViewModel.shared
        // Verify properties exist and don't crash
        _ = vm.incomingOrders
        _ = vm.outgoingOrders
    }
}
