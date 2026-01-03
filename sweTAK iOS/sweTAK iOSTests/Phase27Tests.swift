import XCTest
import CoreLocation
@testable import sweTAK

/// Tests for Phase 27: Sync, Dispatch, Linked Forms, Recipient Status
final class Phase27Tests: XCTestCase {

    // MARK: - PinAddEvent Tests

    func testPinAddEventCreation() {
        let event = PinAddEvent(
            id: 123,
            lat: 59.3293,
            lon: 18.0686,
            typeName: "infantry",
            title: "Test Pin",
            description: "Test description",
            createdAtMillis: 1704067200000,
            originDeviceId: "device123"
        )

        XCTAssertEqual(event.id, 123)
        XCTAssertEqual(event.lat, 59.3293, accuracy: 0.0001)
        XCTAssertEqual(event.lon, 18.0686, accuracy: 0.0001)
        XCTAssertEqual(event.typeName, "infantry")
        XCTAssertEqual(event.title, "Test Pin")
        XCTAssertEqual(event.description, "Test description")
        XCTAssertEqual(event.originDeviceId, "device123")
        XCTAssertNil(event.photoBase64)
    }

    func testPinAddEventWithPhoto() {
        let event = PinAddEvent(
            id: 456,
            lat: 59.33,
            lon: 18.06,
            typeName: "photo",
            title: "Photo Pin",
            description: "",
            createdAtMillis: Date.currentMillis,
            originDeviceId: "device456",
            photoBase64: "base64EncodedPhotoData"
        )

        XCTAssertEqual(event.id, 456)
        XCTAssertEqual(event.photoBase64, "base64EncodedPhotoData")
    }

    func testPinAddEventEquality() {
        let event1 = PinAddEvent(
            id: 100,
            lat: 59.33,
            lon: 18.06,
            typeName: "infantry",
            title: "Test",
            description: "Desc",
            createdAtMillis: 1704067200000,
            originDeviceId: "dev1"
        )

        let event2 = PinAddEvent(
            id: 100,
            lat: 59.33,
            lon: 18.06,
            typeName: "infantry",
            title: "Test",
            description: "Desc",
            createdAtMillis: 1704067200000,
            originDeviceId: "dev1"
        )

        XCTAssertEqual(event1, event2)
    }

    // MARK: - PinSyncCoordinator Tests

    func testPinSyncCoordinatorSingleton() {
        let coordinator1 = PinSyncCoordinator.shared
        let coordinator2 = PinSyncCoordinator.shared
        XCTAssertTrue(coordinator1 === coordinator2)
    }

    func testPinSyncCoordinatorConfigurePinProvider() {
        let coordinator = PinSyncCoordinator.shared
        let deviceId = "testDevice"

        // Configure a pin provider
        coordinator.configurePinProvider({
            [
                NatoPin(
                    latitude: 59.33,
                    longitude: 18.06,
                    type: .infantry,
                    title: "Test",
                    description: "Test pin"
                )
            ]
        }, deviceId: deviceId)

        XCTAssertNotNil(coordinator.provideLocalPins)
    }

    func testPinSyncCoordinatorConfigureLinkedFormProvider() {
        let coordinator = PinSyncCoordinator.shared

        coordinator.configureLinkedFormProvider {
            [] // Empty array for testing
        }

        XCTAssertNotNil(coordinator.provideLocalLinkedForms)
    }

    // MARK: - LinkedFormType Tests

    func testLinkedFormTypeDisplayNames() {
        XCTAssertEqual(LinkedFormType.callForFire.displayName, "Call for Fire")
        XCTAssertEqual(LinkedFormType.medevac.displayName, "9-Line MEDEVAC")
        XCTAssertEqual(LinkedFormType.methane.displayName, "METHANE Report")
        XCTAssertEqual(LinkedFormType.sitrep.displayName, "Situation Report")
        XCTAssertEqual(LinkedFormType.contact.displayName, "Contact Report")
        XCTAssertEqual(LinkedFormType.spot.displayName, "Spot Report")
        XCTAssertEqual(LinkedFormType.intrep.displayName, "Intelligence Report")
        XCTAssertEqual(LinkedFormType.adjustment.displayName, "Fire Adjustment")
        XCTAssertEqual(LinkedFormType.observation.displayName, "Observation")
    }

    func testLinkedFormTypeAbbreviations() {
        XCTAssertEqual(LinkedFormType.callForFire.abbreviation, "CFF")
        XCTAssertEqual(LinkedFormType.medevac.abbreviation, "MEDEVAC")
        XCTAssertEqual(LinkedFormType.methane.abbreviation, "METHANE")
        XCTAssertEqual(LinkedFormType.sitrep.abbreviation, "SITREP")
        XCTAssertEqual(LinkedFormType.contact.abbreviation, "CONTACT")
        XCTAssertEqual(LinkedFormType.spot.abbreviation, "SPOT")
        XCTAssertEqual(LinkedFormType.intrep.abbreviation, "INTREP")
        XCTAssertEqual(LinkedFormType.adjustment.abbreviation, "ADJUST")
        XCTAssertEqual(LinkedFormType.observation.abbreviation, "OBS")
    }

    // MARK: - CallForFireData Tests

    func testCallForFireDataCreation() {
        let cff = CallForFireData(
            observerId: "Alpha-1",
            targetLocation: "33VWN1234567890",
            targetDescription: "Enemy bunker",
            remarks: "Request immediate fire"
        )

        XCTAssertEqual(cff.observerId, "Alpha-1")
        XCTAssertEqual(cff.warningOrder, "FIRE MISSION")
        XCTAssertEqual(cff.targetLocation, "33VWN1234567890")
        XCTAssertEqual(cff.targetDescription, "Enemy bunker")
        XCTAssertEqual(cff.methodOfEngagement, "ADJUST FIRE")
        XCTAssertEqual(cff.methodOfFireControl, "AT MY COMMAND")
        XCTAssertEqual(cff.remarks, "Request immediate fire")
    }

    func testCallForFireDataJSONSerialization() {
        let cff = CallForFireData(
            observerId: "Bravo-2",
            targetLocation: "33VWN9876543210",
            targetDescription: "Vehicle convoy"
        )

        let jsonString = cff.toJSONString()
        XCTAssertNotNil(jsonString)

        if let json = jsonString {
            let decoded = CallForFireData.fromJSONString(json)
            XCTAssertNotNil(decoded)
            XCTAssertEqual(decoded?.observerId, "Bravo-2")
            XCTAssertEqual(decoded?.targetLocation, "33VWN9876543210")
        }
    }

    // MARK: - FireAdjustmentData Tests

    func testFireAdjustmentDataCreation() {
        let adjustment = FireAdjustmentData(
            originalFormId: 12345,
            adjustmentType: .add,
            distance: 100,
            fireCommand: "FFE"
        )

        XCTAssertEqual(adjustment.originalFormId, 12345)
        XCTAssertEqual(adjustment.adjustmentType, .add)
        XCTAssertEqual(adjustment.distance, 100)
        XCTAssertEqual(adjustment.fireCommand, "FFE")
    }

    func testFireAdjustmentTypes() {
        XCTAssertEqual(FireAdjustmentData.AdjustmentType.add.rawValue, "ADD")
        XCTAssertEqual(FireAdjustmentData.AdjustmentType.drop.rawValue, "DROP")
        XCTAssertEqual(FireAdjustmentData.AdjustmentType.left.rawValue, "LEFT")
        XCTAssertEqual(FireAdjustmentData.AdjustmentType.right.rawValue, "RIGHT")
        XCTAssertEqual(FireAdjustmentData.AdjustmentType.fireForEffect.rawValue, "FFE")
        XCTAssertEqual(FireAdjustmentData.AdjustmentType.repeat_.rawValue, "REPEAT")
        XCTAssertEqual(FireAdjustmentData.AdjustmentType.endOfMission.rawValue, "EOM")
    }

    // MARK: - SpotReportData Tests

    func testSpotReportDataCreation() {
        let spot = SpotReportData(
            size: "Squad size, 8-10 personnel",
            activity: "Moving east along road",
            location: "33VWN1234567890",
            unit: "Hostile militia",
            time: "1430L",
            equipment: "Small arms, 1x technical"
        )

        XCTAssertEqual(spot.size, "Squad size, 8-10 personnel")
        XCTAssertEqual(spot.activity, "Moving east along road")
        XCTAssertEqual(spot.location, "33VWN1234567890")
        XCTAssertEqual(spot.unit, "Hostile militia")
        XCTAssertEqual(spot.time, "1430L")
        XCTAssertEqual(spot.equipment, "Small arms, 1x technical")
    }

    func testSpotReportSaluteSummary() {
        let spot = SpotReportData(
            size: "10 personnel",
            activity: "Patrolling",
            location: "Grid 123456",
            unit: "Unknown",
            time: "1500",
            equipment: "Small arms"
        )

        let summary = spot.saluteSummary
        XCTAssertTrue(summary.contains("S: 10 personnel"))
        XCTAssertTrue(summary.contains("A: Patrolling"))
        XCTAssertTrue(summary.contains("L: Grid 123456"))
        XCTAssertTrue(summary.contains("U: Unknown"))
        XCTAssertTrue(summary.contains("T: 1500"))
        XCTAssertTrue(summary.contains("E: Small arms"))
    }

    // MARK: - ContactReportData Tests

    func testContactReportDataCreation() {
        let contact = ContactReportData(
            contactType: .directFire,
            location: "33VWN1234567890",
            enemySize: "Platoon strength",
            enemyActivity: "Attacking from north",
            friendlyCasualties: "1 WIA",
            friendlyActions: "Returning fire, taking cover",
            supportRequest: "Need CAS",
            status: .ongoing
        )

        XCTAssertEqual(contact.contactType, .directFire)
        XCTAssertEqual(contact.status, .ongoing)
        XCTAssertEqual(contact.friendlyCasualties, "1 WIA")
        XCTAssertEqual(contact.supportRequest, "Need CAS")
    }

    func testContactTypeDisplayNames() {
        XCTAssertEqual(ContactReportData.ContactType.directFire.displayName, "Direct Fire")
        XCTAssertEqual(ContactReportData.ContactType.indirectFire.displayName, "Indirect Fire")
        XCTAssertEqual(ContactReportData.ContactType.ied.displayName, "IED/UXO")
        XCTAssertEqual(ContactReportData.ContactType.ambush.displayName, "Ambush")
        XCTAssertEqual(ContactReportData.ContactType.sniper.displayName, "Sniper")
        XCTAssertEqual(ContactReportData.ContactType.sighting.displayName, "Enemy Sighting")
    }

    func testContactStatusDisplayNames() {
        XCTAssertEqual(ContactReportData.ContactStatus.ongoing.displayName, "Ongoing")
        XCTAssertEqual(ContactReportData.ContactStatus.breaking.displayName, "Breaking Contact")
        XCTAssertEqual(ContactReportData.ContactStatus.concluded.displayName, "Concluded")
    }

    // MARK: - ObservationNoteData Tests

    func testObservationNoteDataCreation() {
        let note = ObservationNoteData(
            content: "Enemy patrol observed",
            priority: .priority,
            weatherConditions: "Clear",
            visibility: "Good"
        )

        XCTAssertEqual(note.content, "Enemy patrol observed")
        XCTAssertEqual(note.priority, .priority)
        XCTAssertEqual(note.weatherConditions, "Clear")
        XCTAssertEqual(note.visibility, "Good")
    }

    func testObservationPriorityLevels() {
        XCTAssertEqual(ObservationNoteData.Priority.routine.displayName, "Routine")
        XCTAssertEqual(ObservationNoteData.Priority.priority.displayName, "Priority")
        XCTAssertEqual(ObservationNoteData.Priority.immediate.displayName, "Immediate")
        XCTAssertEqual(ObservationNoteData.Priority.flash.displayName, "Flash")
    }

    // MARK: - DeliveryStatus Tests

    func testDeliveryStatusValues() {
        XCTAssertEqual(DeliveryStatus.pending.rawValue, "PENDING")
        XCTAssertEqual(DeliveryStatus.sent.rawValue, "SENT")
        XCTAssertEqual(DeliveryStatus.delivered.rawValue, "DELIVERED")
        XCTAssertEqual(DeliveryStatus.read.rawValue, "READ")
        XCTAssertEqual(DeliveryStatus.failed.rawValue, "FAILED")
    }

    func testDeliveryStatusDisplayNames() {
        XCTAssertEqual(DeliveryStatus.pending.displayName, "Pending")
        XCTAssertEqual(DeliveryStatus.sent.displayName, "Sent")
        XCTAssertEqual(DeliveryStatus.delivered.displayName, "Delivered")
        XCTAssertEqual(DeliveryStatus.read.displayName, "Read")
        XCTAssertEqual(DeliveryStatus.failed.displayName, "Failed")
    }

    func testDeliveryStatusIcons() {
        XCTAssertEqual(DeliveryStatus.pending.icon, "clock")
        XCTAssertEqual(DeliveryStatus.sent.icon, "checkmark")
        XCTAssertEqual(DeliveryStatus.delivered.icon, "checkmark.circle")
        XCTAssertEqual(DeliveryStatus.read.icon, "checkmark.circle.fill")
        XCTAssertEqual(DeliveryStatus.failed.icon, "exclamationmark.circle")
    }

    func testDeliveryStatusIsCompleted() {
        XCTAssertFalse(DeliveryStatus.pending.isCompleted)
        XCTAssertFalse(DeliveryStatus.sent.isCompleted)
        XCTAssertTrue(DeliveryStatus.delivered.isCompleted)
        XCTAssertTrue(DeliveryStatus.read.isCompleted)
        XCTAssertFalse(DeliveryStatus.failed.isCompleted)
    }

    // MARK: - DeliverySummary Tests

    func testDeliverySummaryFromStatuses() {
        let statuses: [DeliveryStatus] = [
            .pending, .sent, .delivered, .read, .read, .failed
        ]

        let summary = DeliverySummary(from: statuses)

        XCTAssertEqual(summary.total, 6)
        XCTAssertEqual(summary.pending, 1)
        XCTAssertEqual(summary.sent, 1)
        XCTAssertEqual(summary.delivered, 1)
        XCTAssertEqual(summary.read, 2)
        XCTAssertEqual(summary.failed, 1)
    }

    func testDeliverySummaryFullyDelivered() {
        let statuses: [DeliveryStatus] = [.delivered, .delivered, .read]
        let summary = DeliverySummary(from: statuses)

        XCTAssertTrue(summary.isFullyDelivered)
        XCTAssertFalse(summary.isFullyRead)
    }

    func testDeliverySummaryFullyRead() {
        let statuses: [DeliveryStatus] = [.read, .read, .read]
        let summary = DeliverySummary(from: statuses)

        XCTAssertTrue(summary.isFullyDelivered)
        XCTAssertTrue(summary.isFullyRead)
    }

    func testDeliverySummarySummaryText() {
        let emptyStatuses: [DeliveryStatus] = []
        let emptySummary = DeliverySummary(from: emptyStatuses)
        XCTAssertEqual(emptySummary.summaryText, "No recipients")

        let readStatuses: [DeliveryStatus] = [.read, .read]
        let readSummary = DeliverySummary(from: readStatuses)
        XCTAssertEqual(readSummary.summaryText, "Read by all (2)")

        let deliveredStatuses: [DeliveryStatus] = [.delivered, .delivered]
        let deliveredSummary = DeliverySummary(from: deliveredStatuses)
        XCTAssertEqual(deliveredSummary.summaryText, "Delivered to all (2)")
    }

    // MARK: - MethaneResponseType Tests

    func testMethaneResponseTypeValues() {
        XCTAssertEqual(MethaneResponseType.acknowledged.rawValue, "ACKNOWLEDGED")
        XCTAssertEqual(MethaneResponseType.enRoute.rawValue, "EN_ROUTE")
        XCTAssertEqual(MethaneResponseType.onScene.rawValue, "ON_SCENE")
        XCTAssertEqual(MethaneResponseType.resourcesDeployed.rawValue, "RESOURCES_DEPLOYED")
        XCTAssertEqual(MethaneResponseType.unableToRespond.rawValue, "UNABLE_TO_RESPOND")
    }

    func testMethaneResponseTypeDisplayNames() {
        XCTAssertEqual(MethaneResponseType.acknowledged.displayName, "Acknowledged")
        XCTAssertEqual(MethaneResponseType.enRoute.displayName, "En Route")
        XCTAssertEqual(MethaneResponseType.onScene.displayName, "On Scene")
        XCTAssertEqual(MethaneResponseType.resourcesDeployed.displayName, "Resources Deployed")
        XCTAssertEqual(MethaneResponseType.unableToRespond.displayName, "Unable to Respond")
    }

    // MARK: - MedevacRequestPriority Tests

    func testMedevacRequestPriorityValues() {
        XCTAssertEqual(MedevacRequestPriority.urgent.rawValue, "URGENT")
        XCTAssertEqual(MedevacRequestPriority.priority.rawValue, "PRIORITY")
        XCTAssertEqual(MedevacRequestPriority.routine.rawValue, "ROUTINE")
        XCTAssertEqual(MedevacRequestPriority.convenience.rawValue, "CONVENIENCE")
    }

    func testMedevacRequestPriorityDisplayNames() {
        XCTAssertEqual(MedevacRequestPriority.urgent.displayName, "Urgent (T1)")
        XCTAssertEqual(MedevacRequestPriority.priority.displayName, "Priority (T2)")
        XCTAssertEqual(MedevacRequestPriority.routine.displayName, "Routine (T3)")
        XCTAssertEqual(MedevacRequestPriority.convenience.displayName, "Convenience (T4)")
    }

    func testMedevacRequestPriorityColors() {
        XCTAssertEqual(MedevacRequestPriority.urgent.color, "red")
        XCTAssertEqual(MedevacRequestPriority.priority.color, "yellow")
        XCTAssertEqual(MedevacRequestPriority.routine.color, "green")
        XCTAssertEqual(MedevacRequestPriority.convenience.color, "blue")
    }

    // MARK: - StatusTrackingUtils Tests

    func testStatusTrackingUtilsFormatTimestamp() {
        let now = Date.currentMillis
        let result = StatusTrackingUtils.formatTimestamp(now)
        XCTAssertEqual(result, "Just now")

        let fiveMinutesAgo = now - 5 * 60 * 1000
        let result2 = StatusTrackingUtils.formatTimestamp(fiveMinutesAgo)
        XCTAssertTrue(result2.contains("m ago"))

        let twoHoursAgo = now - 2 * 60 * 60 * 1000
        let result3 = StatusTrackingUtils.formatTimestamp(twoHoursAgo)
        XCTAssertTrue(result3.contains("h ago"))
    }

    // MARK: - TacDispatcher Tests

    func testTacDispatcherDeviceId() {
        // Just verify the property is accessible
        _ = TacDispatcher.deviceId
    }

    func testTacDispatcherCallsign() {
        // Just verify the property is accessible
        _ = TacDispatcher.callsign
    }

    func testTacDispatcherIsConnected() {
        // Just verify the property is accessible
        _ = TacDispatcher.isConnected
    }

    func testTacDispatcherTransportMode() {
        // Just verify the property is accessible
        let mode = TacDispatcher.transportMode
        XCTAssertTrue([TransportMode.mqtt, TransportMode.localUDP].contains(mode))
    }

    // MARK: - JSON Serialization Tests

    func testFireAdjustmentDataJSONSerialization() {
        let adjustment = FireAdjustmentData(
            originalFormId: 99999,
            adjustmentType: .fireForEffect,
            direction: "LEFT 50",
            distance: 200
        )

        let jsonString = adjustment.toJSONString()
        XCTAssertNotNil(jsonString)

        if let json = jsonString {
            let decoded = FireAdjustmentData.fromJSONString(json)
            XCTAssertNotNil(decoded)
            XCTAssertEqual(decoded?.originalFormId, 99999)
            XCTAssertEqual(decoded?.adjustmentType, .fireForEffect)
            XCTAssertEqual(decoded?.direction, "LEFT 50")
            XCTAssertEqual(decoded?.distance, 200)
        }
    }

    func testSpotReportDataJSONSerialization() {
        let spot = SpotReportData(
            size: "Company",
            activity: "Defending",
            location: "Hill 101",
            unit: "Regular Army",
            time: "0600",
            equipment: "Heavy weapons",
            remarks: "Well fortified"
        )

        let jsonString = spot.toJSONString()
        XCTAssertNotNil(jsonString)

        if let json = jsonString {
            let decoded = SpotReportData.fromJSONString(json)
            XCTAssertNotNil(decoded)
            XCTAssertEqual(decoded?.size, "Company")
            XCTAssertEqual(decoded?.remarks, "Well fortified")
        }
    }

    func testContactReportDataJSONSerialization() {
        let contact = ContactReportData(
            contactType: .ambush,
            location: "Route Blue",
            enemySize: "Unknown",
            enemyActivity: "Fled",
            friendlyActions: "Pursued briefly",
            status: .concluded
        )

        let jsonString = contact.toJSONString()
        XCTAssertNotNil(jsonString)

        if let json = jsonString {
            let decoded = ContactReportData.fromJSONString(json)
            XCTAssertNotNil(decoded)
            XCTAssertEqual(decoded?.contactType, .ambush)
            XCTAssertEqual(decoded?.status, .concluded)
        }
    }

    func testObservationNoteDataJSONSerialization() {
        let note = ObservationNoteData(
            content: "All quiet on the front",
            priority: .routine
        )

        let jsonString = note.toJSONString()
        XCTAssertNotNil(jsonString)

        if let json = jsonString {
            let decoded = ObservationNoteData.fromJSONString(json)
            XCTAssertNotNil(decoded)
            XCTAssertEqual(decoded?.content, "All quiet on the front")
            XCTAssertEqual(decoded?.priority, .routine)
        }
    }

    // MARK: - LinkedFormType CaseIterable Tests

    func testLinkedFormTypeAllCases() {
        let allCases = LinkedFormType.allCases
        XCTAssertEqual(allCases.count, 9)
        XCTAssertTrue(allCases.contains(.callForFire))
        XCTAssertTrue(allCases.contains(.medevac))
        XCTAssertTrue(allCases.contains(.methane))
        XCTAssertTrue(allCases.contains(.sitrep))
        XCTAssertTrue(allCases.contains(.contact))
        XCTAssertTrue(allCases.contains(.spot))
        XCTAssertTrue(allCases.contains(.intrep))
        XCTAssertTrue(allCases.contains(.adjustment))
        XCTAssertTrue(allCases.contains(.observation))
    }

    // MARK: - ContactType CaseIterable Tests

    func testContactTypeAllCases() {
        let allCases = ContactReportData.ContactType.allCases
        XCTAssertEqual(allCases.count, 7)
        XCTAssertTrue(allCases.contains(.directFire))
        XCTAssertTrue(allCases.contains(.indirectFire))
        XCTAssertTrue(allCases.contains(.ied))
        XCTAssertTrue(allCases.contains(.ambush))
        XCTAssertTrue(allCases.contains(.sniper))
        XCTAssertTrue(allCases.contains(.sighting))
        XCTAssertTrue(allCases.contains(.other))
    }

    // MARK: - ContactStatus CaseIterable Tests

    func testContactStatusAllCases() {
        let allCases = ContactReportData.ContactStatus.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.ongoing))
        XCTAssertTrue(allCases.contains(.breaking))
        XCTAssertTrue(allCases.contains(.concluded))
    }

    // MARK: - ObservationPriority CaseIterable Tests

    func testObservationPriorityAllCases() {
        let allCases = ObservationNoteData.Priority.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.routine))
        XCTAssertTrue(allCases.contains(.priority))
        XCTAssertTrue(allCases.contains(.immediate))
        XCTAssertTrue(allCases.contains(.flash))
    }

    // MARK: - DeliveryStatus CaseIterable Tests

    func testDeliveryStatusAllCases() {
        let allCases = DeliveryStatus.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.pending))
        XCTAssertTrue(allCases.contains(.sent))
        XCTAssertTrue(allCases.contains(.delivered))
        XCTAssertTrue(allCases.contains(.read))
        XCTAssertTrue(allCases.contains(.failed))
    }

    // MARK: - MethaneResponseType CaseIterable Tests

    func testMethaneResponseTypeAllCases() {
        let allCases = MethaneResponseType.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.acknowledged))
        XCTAssertTrue(allCases.contains(.enRoute))
        XCTAssertTrue(allCases.contains(.onScene))
        XCTAssertTrue(allCases.contains(.resourcesDeployed))
        XCTAssertTrue(allCases.contains(.unableToRespond))
    }

    // MARK: - MedevacRequestPriority CaseIterable Tests

    func testMedevacRequestPriorityAllCases() {
        let allCases = MedevacRequestPriority.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.urgent))
        XCTAssertTrue(allCases.contains(.priority))
        XCTAssertTrue(allCases.contains(.routine))
        XCTAssertTrue(allCases.contains(.convenience))
    }

    // MARK: - LinkedForm Extension Tests

    func testLinkedFormGenerateId() {
        let id1 = LinkedForm.generateId()
        Thread.sleep(forTimeInterval: 0.01)
        let id2 = LinkedForm.generateId()

        XCTAssertNotEqual(id1, id2)
        XCTAssertGreaterThan(id1, 0)
        XCTAssertGreaterThan(id2, 0)
    }
}
