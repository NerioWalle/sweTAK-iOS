import XCTest
@testable import sweTAK

final class ModelTests: XCTestCase {

    // MARK: - Order Tests

    func testOrderCreation() {
        let order = Order(
            type: .obo,
            senderDeviceId: "device-123",
            senderCallsign: "Alpha-1",
            orientation: "Enemy forces observed at grid reference...",
            decision: "We will engage from the north",
            order: "Squad 1 advance on signal",
            recipientDeviceIds: ["device-456", "device-789"],
            direction: .outgoing
        )

        XCTAssertEqual(order.type, .obo)
        XCTAssertEqual(order.senderCallsign, "Alpha-1")
        XCTAssertEqual(order.recipientDeviceIds.count, 2)
        XCTAssertFalse(order.isRead)
    }

    func testOrderCodable() throws {
        let order = Order(
            type: .fiveP,
            senderDeviceId: "device-123",
            senderCallsign: "Alpha-1",
            orientation: "Orientation text",
            mission: "Mission text",
            execution: "Execution text",
            logistics: "Logistics text",
            commandSignaling: "Command text",
            recipientDeviceIds: ["device-456"],
            direction: .outgoing
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(order)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Order.self, from: data)

        XCTAssertEqual(decoded.id, order.id)
        XCTAssertEqual(decoded.type, .fiveP)
        XCTAssertEqual(decoded.mission, "Mission text")
    }

    // MARK: - Chat Message Tests

    func testChatMessageCreation() {
        let message = ChatMessage(
            threadId: "thread-123",
            fromDeviceId: "device-a",
            toDeviceId: "device-b",
            text: "Hello, this is a test message",
            direction: .outgoing
        )

        XCTAssertEqual(message.threadId, "thread-123")
        XCTAssertEqual(message.text, "Hello, this is a test message")
        XCTAssertFalse(message.acknowledged)
    }

    // MARK: - Contact Profile Tests

    func testContactProfileFromJSON() {
        let json: [String: Any] = [
            "callsign": "Bravo-2",
            "nick": "JohnD",
            "first": "John",
            "last": "Doe",
            "company": "Alpha Company",
            "platoon": "1st Platoon",
            "squad": "2nd Squad",
            "role": "SQUAD_LEADER"
        ]

        let profile = ContactProfile.fromJSON(json, deviceId: "device-123", fromIp: "192.168.1.100")

        XCTAssertEqual(profile.deviceId, "device-123")
        XCTAssertEqual(profile.callsign, "Bravo-2")
        XCTAssertEqual(profile.nickname, "JohnD")
        XCTAssertEqual(profile.firstName, "John")
        XCTAssertEqual(profile.role, .squadLeader)
        XCTAssertEqual(profile.fromIp, "192.168.1.100")
    }

    func testMilitaryRoleFromString() {
        XCTAssertEqual(MilitaryRole.from("SQUAD_LEADER"), .squadLeader)
        XCTAssertEqual(MilitaryRole.from("Squad Leader"), .squadLeader)
        XCTAssertEqual(MilitaryRole.from("SL"), .squadLeader)
        XCTAssertEqual(MilitaryRole.from("invalid"), .none)
        XCTAssertEqual(MilitaryRole.from(nil), .none)
    }

    // MARK: - NatoPin Tests

    func testNatoPinCreation() {
        let pin = NatoPin(
            latitude: 59.329323,
            longitude: 18.068581,
            type: .infantry,
            title: "Enemy Position",
            description: "Observed 5 soldiers"
        )

        XCTAssertEqual(pin.type, .infantry)
        XCTAssertEqual(pin.title, "Enemy Position")
        XCTAssertEqual(pin.coordinate.latitude, 59.329323, accuracy: 0.0001)
    }

    func testNatoTypeParsing() {
        XCTAssertEqual(NatoType.parse("INFANTRY"), .infantry)
        XCTAssertEqual(NatoType.parse("drone"), .droneObserved)
        XCTAssertEqual(NatoType.parse("UAV"), .droneObserved)
        XCTAssertEqual(NatoType.parse("OP"), .op)
        XCTAssertEqual(NatoType.parse("unknown"), .infantry) // Default
    }

    func testNatoPinJSON() {
        let pin = NatoPin(
            id: 12345,
            latitude: 59.329323,
            longitude: 18.068581,
            type: .surveillance,
            title: "Observation Point"
        )

        let json = pin.toJSON()

        XCTAssertEqual(json["id"] as? Int64, 12345)
        XCTAssertEqual(json["type"] as? String, "SURVEILLANCE")
        XCTAssertEqual(json["title"] as? String, "Observation Point")
    }

    // MARK: - METHANE Request Tests

    func testMethaneRequestCreation() {
        let methane = MethaneRequest(
            senderDeviceId: "device-123",
            senderCallsign: "Alpha-1",
            callsign: "Alpha-1",
            unit: "1st Infantry",
            incidentLocation: "33U VP 12345 67890",
            incidentTime: "301430",
            incidentType: "IED Strike",
            hazards: "Secondary device possible",
            approachRoutes: "Route Green from the north",
            casualtyCountP1: 2,
            casualtyCountP2: 1,
            assetsPresent: "2x stretchers, 1x medic",
            assetsRequired: "MEDEVAC helicopter",
            recipientDeviceIds: ["device-456"],
            direction: .outgoing
        )

        XCTAssertEqual(methane.totalCasualties, 3)
        XCTAssertEqual(methane.incidentType, "IED Strike")
    }

    // MARK: - MEDEVAC Report Tests

    func testMedevacReportCreation() {
        let medevac = MedevacReport(
            senderDeviceId: "device-123",
            senderCallsign: "Medic-1",
            soldierName: "Sgt. Johnson",
            priority: .p1,
            ageInfo: "Adult, approx 30",
            incidentTime: "301430",
            mechanismOfInjury: "Gunshot wound",
            injuryDescription: "GSW to left leg",
            signsSymptoms: "Heavy bleeding, conscious",
            pulse: "120 bpm",
            treatmentActions: "Tourniquet applied",
            caretakerName: "Cpl. Smith",
            recipientDeviceIds: ["device-456"],
            direction: .outgoing
        )

        XCTAssertEqual(medevac.priority, .p1)
        XCTAssertEqual(medevac.soldierName, "Sgt. Johnson")
    }

    // MARK: - Report Tests

    func testPEDARSReportCreation() {
        let report = Report(
            senderDeviceId: "device-123",
            senderCallsign: "Command-1",
            woundedCount: 2,
            deadCount: 0,
            capableCount: 28,
            replenishment: "Food for 2 days",
            fuel: "75% capacity",
            ammunition: "Resupply needed in 24h",
            equipment: "1x radio damaged",
            readiness: .yellow,
            readinessDetails: "Reduced mobility due to vehicle breakdown",
            recipientDeviceIds: ["device-456"],
            direction: .outgoing
        )

        XCTAssertEqual(report.readiness, .yellow)
        XCTAssertEqual(report.capableCount, 28)
    }
}
