import XCTest
@testable import sweTAK

final class ReportTests: XCTestCase {

    // MARK: - MethaneRequest Tests

    func testMethaneRequestCreation() {
        let request = MethaneRequest(
            senderDeviceId: "device-123",
            senderCallsign: "Alpha-1",
            callsign: "Alpha-1",
            unit: "1st Platoon",
            incidentLocation: "Near building complex",
            incidentLatitude: 59.33,
            incidentLongitude: 18.06,
            incidentTime: "14:30",
            incidentType: "IED",
            hazards: "Secondary devices possible",
            approachRoutes: "From north",
            hlsLocation: "Open field 200m south",
            hlsLatitude: 59.328,
            hlsLongitude: 18.06,
            casualtyCountP1: 2,
            casualtyCountP2: 1,
            casualtyCountP3: 3,
            casualtyCountDeceased: 1,
            casualtyDetails: "2 severe leg injuries",
            assetsPresent: "1 medic",
            assetsRequired: "MEDEVAC helicopter",
            recipientDeviceIds: ["device-456"],
            direction: .outgoing
        )

        XCTAssertEqual(request.senderDeviceId, "device-123")
        XCTAssertEqual(request.callsign, "Alpha-1")
        XCTAssertEqual(request.incidentType, "IED")
        XCTAssertEqual(request.casualtyCountP1, 2)
        XCTAssertEqual(request.totalCasualties, 7)
        XCTAssertEqual(request.direction, .outgoing)
        XCTAssertFalse(request.isRead)
    }

    func testMethaneRequestTotalCasualties() {
        let request = MethaneRequest(
            senderDeviceId: "device-123",
            senderCallsign: "Alpha-1",
            callsign: "Alpha-1",
            unit: "1st Platoon",
            incidentLocation: "Location",
            incidentTime: "14:30",
            incidentType: "Ambush",
            hazards: "",
            approachRoutes: "",
            casualtyCountP1: 3,
            casualtyCountP2: 2,
            casualtyCountP3: 5,
            casualtyCountDeceased: 1,
            assetsPresent: "",
            assetsRequired: "",
            recipientDeviceIds: [],
            direction: .outgoing
        )

        XCTAssertEqual(request.totalCasualties, 11)
    }

    func testMethaneDirectionRawValues() {
        XCTAssertEqual(MethaneDirection.outgoing.rawValue, "OUTGOING")
        XCTAssertEqual(MethaneDirection.incoming.rawValue, "INCOMING")
    }

    func testMethaneRecipientStatusCreation() {
        let status = MethaneRecipientStatus(
            methaneId: "methane-123",
            recipientDeviceId: "device-456",
            recipientCallsign: "Bravo-1",
            sentAtMillis: 1234567890
        )

        XCTAssertEqual(status.methaneId, "methane-123")
        XCTAssertEqual(status.recipientDeviceId, "device-456")
        XCTAssertFalse(status.isDelivered)
        XCTAssertFalse(status.isRead)
    }

    func testMethaneRecipientStatusDelivered() {
        var status = MethaneRecipientStatus(
            methaneId: "methane-123",
            recipientDeviceId: "device-456",
            recipientCallsign: nil,
            sentAtMillis: 1234567890,
            deliveredAtMillis: 1234567900
        )

        XCTAssertTrue(status.isDelivered)
        XCTAssertFalse(status.isRead)

        status.readAtMillis = 1234567910
        XCTAssertTrue(status.isRead)
    }

    func testMethaneAckCreation() {
        let ack = MethaneAck(
            methaneId: "methane-123",
            fromDeviceId: "device-456",
            toDeviceId: "device-123",
            ackType: .delivered
        )

        XCTAssertEqual(ack.methaneId, "methane-123")
        XCTAssertEqual(ack.ackType, .delivered)
    }

    // MARK: - MedevacReport Tests

    func testMedevacReportCreation() {
        let report = MedevacReport(
            senderDeviceId: "device-123",
            senderCallsign: "Medic-1",
            soldierName: "SGT Johnson",
            priority: .p1,
            ageInfo: "~30",
            incidentTime: "291430",
            mechanismOfInjury: "GSW left leg",
            injuryDescription: "Entry wound left thigh",
            signsSymptoms: "Severe bleeding, pale",
            pulse: "120",
            bodyTemperature: "36.2",
            treatmentActions: "Tourniquet applied",
            medicinesGiven: "Morphine 10mg IV",
            caretakerName: "CPL Smith",
            recipientDeviceIds: ["device-456"],
            direction: .outgoing
        )

        XCTAssertEqual(report.soldierName, "SGT Johnson")
        XCTAssertEqual(report.priority, .p1)
        XCTAssertEqual(report.mechanismOfInjury, "GSW left leg")
        XCTAssertEqual(report.pulse, "120")
        XCTAssertEqual(report.direction, .outgoing)
        XCTAssertFalse(report.isRead)
    }

    func testMedevacPriorityDisplayNames() {
        XCTAssertEqual(MedevacPriority.p1.displayName, "P1 - Immediate")
        XCTAssertEqual(MedevacPriority.p2.displayName, "P2 - Urgent")
        XCTAssertEqual(MedevacPriority.p3.displayName, "P3 - Delayed")
        XCTAssertEqual(MedevacPriority.deceased.displayName, "Deceased")
    }

    func testMedevacPriorityColors() {
        // Just verify colors are not nil (they're Color types)
        XCTAssertNotNil(MedevacPriority.p1.color)
        XCTAssertNotNil(MedevacPriority.p2.color)
        XCTAssertNotNil(MedevacPriority.p3.color)
        XCTAssertNotNil(MedevacPriority.deceased.color)
    }

    func testMedevacDirectionRawValues() {
        XCTAssertEqual(MedevacDirection.outgoing.rawValue, "OUTGOING")
        XCTAssertEqual(MedevacDirection.incoming.rawValue, "INCOMING")
    }

    func testMedevacRecipientStatusCreation() {
        let status = MedevacRecipientStatus(
            medevacId: "medevac-123",
            recipientDeviceId: "device-456",
            recipientCallsign: "Surgeon-1",
            sentAtMillis: 1234567890
        )

        XCTAssertEqual(status.medevacId, "medevac-123")
        XCTAssertEqual(status.recipientDeviceId, "device-456")
        XCTAssertFalse(status.isDelivered)
        XCTAssertFalse(status.isRead)
    }

    func testMedevacAckCreation() {
        let ack = MedevacAck(
            medevacId: "medevac-123",
            fromDeviceId: "device-456",
            toDeviceId: "device-123",
            ackType: .read
        )

        XCTAssertEqual(ack.medevacId, "medevac-123")
        XCTAssertEqual(ack.ackType, .read)
    }

    // MARK: - Casualty Priority Tests

    func testCasualtyPriorityDisplayNames() {
        XCTAssertEqual(CasualtyPriority.p1.displayName, "P1 - Immediate")
        XCTAssertEqual(CasualtyPriority.p2.displayName, "P2 - Urgent")
        XCTAssertEqual(CasualtyPriority.p3.displayName, "P3 - Delayed")
        XCTAssertEqual(CasualtyPriority.deceased.displayName, "Deceased")
    }

    func testCasualtyPriorityRawValues() {
        XCTAssertEqual(CasualtyPriority.p1.rawValue, "P1")
        XCTAssertEqual(CasualtyPriority.p2.rawValue, "P2")
        XCTAssertEqual(CasualtyPriority.p3.rawValue, "P3")
        XCTAssertEqual(CasualtyPriority.deceased.rawValue, "DECEASED")
    }

    // MARK: - Codable Tests

    func testMethaneRequestCodable() throws {
        let original = MethaneRequest(
            senderDeviceId: "device-123",
            senderCallsign: "Alpha-1",
            callsign: "Alpha-1",
            unit: "1st Platoon",
            incidentLocation: "Near building",
            incidentLatitude: 59.33,
            incidentLongitude: 18.06,
            incidentTime: "14:30",
            incidentType: "IED",
            hazards: "Secondary devices",
            approachRoutes: "From north",
            casualtyCountP1: 2,
            casualtyCountP2: 1,
            casualtyCountP3: 0,
            casualtyCountDeceased: 0,
            assetsPresent: "1 medic",
            assetsRequired: "Helicopter",
            recipientDeviceIds: ["device-456"],
            direction: .outgoing
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MethaneRequest.self, from: data)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.incidentType, decoded.incidentType)
        XCTAssertEqual(original.casualtyCountP1, decoded.casualtyCountP1)
        XCTAssertEqual(original.incidentLatitude, decoded.incidentLatitude)
        XCTAssertEqual(original.direction, decoded.direction)
    }

    func testMedevacReportCodable() throws {
        let original = MedevacReport(
            senderDeviceId: "device-123",
            senderCallsign: "Medic-1",
            soldierName: "SGT Johnson",
            priority: .p1,
            ageInfo: "30",
            incidentTime: "291430",
            mechanismOfInjury: "GSW",
            injuryDescription: "Left leg wound",
            signsSymptoms: "Bleeding",
            pulse: "120",
            bodyTemperature: "36.5",
            treatmentActions: "Tourniquet",
            medicinesGiven: "Morphine",
            caretakerName: "CPL Smith",
            recipientDeviceIds: ["device-456"],
            direction: .outgoing
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MedevacReport.self, from: data)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.soldierName, decoded.soldierName)
        XCTAssertEqual(original.priority, decoded.priority)
        XCTAssertEqual(original.pulse, decoded.pulse)
        XCTAssertEqual(original.direction, decoded.direction)
    }

    // MARK: - MethaneViewModel Tests

    func testMethaneViewModelSingleton() {
        let vm1 = MethaneViewModel.shared
        let vm2 = MethaneViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    func testMethaneViewModelComputedProperties() {
        let vm = MethaneViewModel.shared
        // Just verify computed properties don't crash
        _ = vm.incomingRequests
        _ = vm.outgoingRequests
        _ = vm.unreadIncomingCount
    }

    // MARK: - MedevacViewModel Tests

    func testMedevacViewModelSingleton() {
        let vm1 = MedevacViewModel.shared
        let vm2 = MedevacViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    func testMedevacViewModelComputedProperties() {
        let vm = MedevacViewModel.shared
        // Just verify computed properties don't crash
        _ = vm.incomingReports
        _ = vm.outgoingReports
        _ = vm.unreadIncomingCount
    }

    // MARK: - ACK Type Tests

    func testMethaneAckTypeRawValues() {
        XCTAssertEqual(MethaneAckType.delivered.rawValue, "DELIVERED")
        XCTAssertEqual(MethaneAckType.read.rawValue, "READ")
    }

    func testMedevacAckTypeRawValues() {
        XCTAssertEqual(MedevacAckType.delivered.rawValue, "DELIVERED")
        XCTAssertEqual(MedevacAckType.read.rawValue, "READ")
    }

    // MARK: - PEDARS Report Tests

    func testPedarsReportCreation() {
        let report = Report(
            senderDeviceId: "device-123",
            senderCallsign: "Alpha-1",
            woundedCount: 2,
            deadCount: 0,
            capableCount: 15,
            replenishment: "Need water and rations",
            fuel: "Diesel: 200L needed",
            ammunition: "5.56mm: 1000 rounds",
            equipment: "Radio batteries",
            readiness: .green,
            readinessDetails: "",
            recipientDeviceIds: ["device-456"],
            direction: .outgoing
        )

        XCTAssertEqual(report.senderDeviceId, "device-123")
        XCTAssertEqual(report.senderCallsign, "Alpha-1")
        XCTAssertEqual(report.woundedCount, 2)
        XCTAssertEqual(report.deadCount, 0)
        XCTAssertEqual(report.capableCount, 15)
        XCTAssertEqual(report.readiness, .green)
        XCTAssertEqual(report.direction, .outgoing)
        XCTAssertFalse(report.isRead)
    }

    func testPedarsReportWithYellowReadiness() {
        let report = Report(
            senderDeviceId: "device-123",
            senderCallsign: "Bravo-1",
            woundedCount: 3,
            deadCount: 1,
            capableCount: 10,
            replenishment: "",
            fuel: "",
            ammunition: "Low on 7.62mm",
            equipment: "Vehicle needs repair",
            readiness: .yellow,
            readinessDetails: "Limited mobility due to vehicle damage",
            recipientDeviceIds: ["device-456", "device-789"],
            direction: .outgoing
        )

        XCTAssertEqual(report.readiness, .yellow)
        XCTAssertEqual(report.readinessDetails, "Limited mobility due to vehicle damage")
        XCTAssertEqual(report.recipientDeviceIds.count, 2)
    }

    func testPedarsReportWithRedReadiness() {
        let report = Report(
            senderDeviceId: "device-123",
            senderCallsign: "Charlie-1",
            woundedCount: 5,
            deadCount: 2,
            capableCount: 3,
            replenishment: "Critical supply shortage",
            fuel: "No fuel available",
            ammunition: "Nearly depleted",
            equipment: "Most equipment damaged",
            readiness: .red,
            readinessDetails: "Cannot perform missions without immediate resupply",
            recipientDeviceIds: ["device-456"],
            direction: .outgoing
        )

        XCTAssertEqual(report.readiness, .red)
        XCTAssertFalse(report.readinessDetails.isEmpty)
        XCTAssertEqual(report.capableCount, 3)
    }

    func testReadinessLevelDisplayNames() {
        XCTAssertEqual(ReadinessLevel.green.displayName, "Green - No limitations")
        XCTAssertEqual(ReadinessLevel.yellow.displayName, "Yellow - With limitations")
        XCTAssertEqual(ReadinessLevel.red.displayName, "Red - Cannot solve missions")
    }

    func testReadinessLevelRawValues() {
        XCTAssertEqual(ReadinessLevel.green.rawValue, "GREEN")
        XCTAssertEqual(ReadinessLevel.yellow.rawValue, "YELLOW")
        XCTAssertEqual(ReadinessLevel.red.rawValue, "RED")
    }

    func testReadinessLevelColors() {
        // Just verify colors are not nil
        XCTAssertNotNil(ReadinessLevel.green.color)
        XCTAssertNotNil(ReadinessLevel.yellow.color)
        XCTAssertNotNil(ReadinessLevel.red.color)
    }

    func testReportDirectionRawValues() {
        XCTAssertEqual(ReportDirection.outgoing.rawValue, "OUTGOING")
        XCTAssertEqual(ReportDirection.incoming.rawValue, "INCOMING")
    }

    func testReportRecipientStatusCreation() {
        let status = ReportRecipientStatus(
            reportId: "report-123",
            recipientDeviceId: "device-456",
            recipientCallsign: "Delta-1",
            sentAtMillis: 1234567890
        )

        XCTAssertEqual(status.reportId, "report-123")
        XCTAssertEqual(status.recipientDeviceId, "device-456")
        XCTAssertEqual(status.recipientCallsign, "Delta-1")
        XCTAssertFalse(status.isDelivered)
        XCTAssertFalse(status.isRead)
    }

    func testReportRecipientStatusDelivered() {
        var status = ReportRecipientStatus(
            reportId: "report-123",
            recipientDeviceId: "device-456",
            recipientCallsign: nil,
            sentAtMillis: 1234567890,
            deliveredAtMillis: 1234567900
        )

        XCTAssertTrue(status.isDelivered)
        XCTAssertFalse(status.isRead)

        status.readAtMillis = 1234567910
        XCTAssertTrue(status.isRead)
    }

    func testReportAckCreation() {
        let ack = ReportAck(
            reportId: "report-123",
            fromDeviceId: "device-456",
            toDeviceId: "device-123",
            ackType: .delivered
        )

        XCTAssertEqual(ack.reportId, "report-123")
        XCTAssertEqual(ack.fromDeviceId, "device-456")
        XCTAssertEqual(ack.toDeviceId, "device-123")
        XCTAssertEqual(ack.ackType, .delivered)
    }

    func testReportAckTypeRawValues() {
        XCTAssertEqual(ReportAckType.delivered.rawValue, "DELIVERED")
        XCTAssertEqual(ReportAckType.read.rawValue, "READ")
    }

    func testPedarsReportCodable() throws {
        let original = Report(
            senderDeviceId: "device-123",
            senderCallsign: "Alpha-1",
            woundedCount: 2,
            deadCount: 1,
            capableCount: 12,
            replenishment: "Need supplies",
            fuel: "Need diesel",
            ammunition: "Need 5.56mm",
            equipment: "Need batteries",
            readiness: .yellow,
            readinessDetails: "Limited capacity",
            recipientDeviceIds: ["device-456"],
            direction: .outgoing
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Report.self, from: data)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.woundedCount, decoded.woundedCount)
        XCTAssertEqual(original.deadCount, decoded.deadCount)
        XCTAssertEqual(original.capableCount, decoded.capableCount)
        XCTAssertEqual(original.readiness, decoded.readiness)
        XCTAssertEqual(original.readinessDetails, decoded.readinessDetails)
        XCTAssertEqual(original.direction, decoded.direction)
    }

    // MARK: - ReportsViewModel Tests

    func testReportsViewModelSingleton() {
        let vm1 = ReportsViewModel.shared
        let vm2 = ReportsViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    func testReportsViewModelComputedProperties() {
        let vm = ReportsViewModel.shared
        // Just verify computed properties don't crash
        _ = vm.incomingReports
        _ = vm.outgoingReports
        _ = vm.unreadIncomingCount
    }
}
