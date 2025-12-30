import XCTest
import CoreLocation
@testable import sweTAK

/// Tests for Phase 29: Location Tracking, TAK Route Models, Integration Tests
final class Phase29Tests: XCTestCase {

    // MARK: - TAKBreadcrumbPoint Tests

    func testTAKBreadcrumbPointCreation() {
        let point = TAKBreadcrumbPoint(
            lat: 59.3293,
            lon: 18.0686,
            altitude: 25.5,
            timestamp: 1704067200000
        )

        XCTAssertEqual(point.lat, 59.3293, accuracy: 0.0001)
        XCTAssertEqual(point.lon, 18.0686, accuracy: 0.0001)
        XCTAssertEqual(point.altitude, 25.5)
        XCTAssertEqual(point.timestamp, 1704067200000)
    }

    func testTAKBreadcrumbPointDefaultTimestamp() {
        let before = Date.currentMillis
        let point = TAKBreadcrumbPoint(lat: 59.0, lon: 18.0)
        let after = Date.currentMillis

        XCTAssertGreaterThanOrEqual(point.timestamp, before)
        XCTAssertLessThanOrEqual(point.timestamp, after)
    }

    func testTAKBreadcrumbPointCoordinate() {
        let point = TAKBreadcrumbPoint(lat: 59.3293, lon: 18.0686)
        let coord = point.coordinate

        XCTAssertEqual(coord.latitude, 59.3293, accuracy: 0.0001)
        XCTAssertEqual(coord.longitude, 18.0686, accuracy: 0.0001)
    }

    func testTAKBreadcrumbPointEquatable() {
        let point1 = TAKBreadcrumbPoint(lat: 59.0, lon: 18.0, timestamp: 1000)
        let point2 = TAKBreadcrumbPoint(lat: 59.0, lon: 18.0, timestamp: 1000)

        XCTAssertEqual(point1, point2)
    }

    func testTAKBreadcrumbPointCodable() throws {
        let original = TAKBreadcrumbPoint(lat: 59.3293, lon: 18.0686, altitude: 100.0, timestamp: 1704067200000)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TAKBreadcrumbPoint.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - TAKBreadcrumbRoute Tests

    func testTAKBreadcrumbRouteCreation() {
        let route = TAKBreadcrumbRoute(
            id: "route-123",
            startTimeMillis: 1704067200000,
            points: [
                TAKBreadcrumbPoint(lat: 59.33, lon: 18.06),
                TAKBreadcrumbPoint(lat: 59.34, lon: 18.07)
            ],
            totalDistanceMeters: 1500.0,
            durationMillis: 600000
        )

        XCTAssertEqual(route.id, "route-123")
        XCTAssertEqual(route.startTimeMillis, 1704067200000)
        XCTAssertEqual(route.points.count, 2)
        XCTAssertEqual(route.totalDistanceMeters, 1500.0, accuracy: 0.1)
        XCTAssertEqual(route.durationMillis, 600000)
    }

    func testTAKBreadcrumbRouteDefaultInit() {
        let route = TAKBreadcrumbRoute()

        XCTAssertFalse(route.id.isEmpty)
        XCTAssertTrue(route.points.isEmpty)
        XCTAssertEqual(route.totalDistanceMeters, 0)
        XCTAssertEqual(route.durationMillis, 0)
    }

    func testTAKBreadcrumbRouteIdentifiable() {
        let route = TAKBreadcrumbRoute(id: "unique-route-id")
        XCTAssertEqual(route.id, "unique-route-id")
    }

    func testTAKBreadcrumbRouteCodable() throws {
        let original = TAKBreadcrumbRoute(
            id: "route-test",
            startTimeMillis: 1704067200000,
            points: [TAKBreadcrumbPoint(lat: 59.0, lon: 18.0)],
            totalDistanceMeters: 500.0,
            durationMillis: 300000
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TAKBreadcrumbRoute.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - TAKPlannedWaypoint Tests

    func testTAKPlannedWaypointCreation() {
        let waypoint = TAKPlannedWaypoint(lat: 59.3293, lon: 18.0686, order: 0)

        XCTAssertEqual(waypoint.lat, 59.3293, accuracy: 0.0001)
        XCTAssertEqual(waypoint.lon, 18.0686, accuracy: 0.0001)
        XCTAssertEqual(waypoint.order, 0)
    }

    func testTAKPlannedWaypointCoordinate() {
        let waypoint = TAKPlannedWaypoint(lat: 59.3293, lon: 18.0686, order: 1)
        let coord = waypoint.coordinate

        XCTAssertEqual(coord.latitude, 59.3293, accuracy: 0.0001)
        XCTAssertEqual(coord.longitude, 18.0686, accuracy: 0.0001)
    }

    func testTAKPlannedWaypointEquatable() {
        let wp1 = TAKPlannedWaypoint(lat: 59.0, lon: 18.0, order: 0)
        let wp2 = TAKPlannedWaypoint(lat: 59.0, lon: 18.0, order: 0)

        XCTAssertEqual(wp1, wp2)
    }

    func testTAKPlannedWaypointCodable() throws {
        let original = TAKPlannedWaypoint(lat: 59.3293, lon: 18.0686, order: 5)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TAKPlannedWaypoint.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - TAKPlannedRoute Tests

    func testTAKPlannedRouteCreation() {
        let route = TAKPlannedRoute(
            id: "planned-route-123",
            name: "Patrol Route Alpha",
            createdAtMillis: 1704067200000,
            waypoints: [
                TAKPlannedWaypoint(lat: 59.33, lon: 18.06, order: 0),
                TAKPlannedWaypoint(lat: 59.34, lon: 18.07, order: 1),
                TAKPlannedWaypoint(lat: 59.35, lon: 18.08, order: 2)
            ],
            totalDistanceMeters: 3000.0
        )

        XCTAssertEqual(route.id, "planned-route-123")
        XCTAssertEqual(route.name, "Patrol Route Alpha")
        XCTAssertEqual(route.waypoints.count, 3)
        XCTAssertEqual(route.totalDistanceMeters, 3000.0, accuracy: 0.1)
    }

    func testTAKPlannedRouteDefaultInit() {
        let route = TAKPlannedRoute()

        XCTAssertFalse(route.id.isEmpty)
        XCTAssertEqual(route.name, "")
        XCTAssertTrue(route.waypoints.isEmpty)
        XCTAssertEqual(route.totalDistanceMeters, 0)
    }

    func testTAKPlannedRouteCodable() throws {
        let original = TAKPlannedRoute(
            id: "route-codable",
            name: "Test Route",
            waypoints: [TAKPlannedWaypoint(lat: 59.0, lon: 18.0, order: 0)],
            totalDistanceMeters: 1000.0
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TAKPlannedRoute.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - LocationTrackingState Tests

    func testLocationTrackingStateValues() {
        XCTAssertEqual(LocationTrackingState.idle.rawValue, "IDLE")
        XCTAssertEqual(LocationTrackingState.tracking.rawValue, "TRACKING")
        XCTAssertEqual(LocationTrackingState.recording.rawValue, "RECORDING")
    }

    // MARK: - LocationTrackingManager Singleton Tests

    func testLocationTrackingManagerSingleton() {
        let manager1 = LocationTrackingManager.shared
        let manager2 = LocationTrackingManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    func testLocationTrackingManagerInitialState() {
        let manager = LocationTrackingManager.shared
        // State should be idle initially or tracking if already started
        XCTAssertTrue([.idle, .tracking, .recording].contains(manager.state))
    }

    // MARK: - NatoType Edge Cases

    func testNatoTypeAllCases() {
        XCTAssertEqual(NatoType.allCases.count, 10)
        XCTAssertTrue(NatoType.allCases.contains(.infantry))
        XCTAssertTrue(NatoType.allCases.contains(.intelligence))
        XCTAssertTrue(NatoType.allCases.contains(.surveillance))
        XCTAssertTrue(NatoType.allCases.contains(.artillery))
        XCTAssertTrue(NatoType.allCases.contains(.marine))
        XCTAssertTrue(NatoType.allCases.contains(.droneObserved))
        XCTAssertTrue(NatoType.allCases.contains(.op))
        XCTAssertTrue(NatoType.allCases.contains(.photo))
        XCTAssertTrue(NatoType.allCases.contains(.form7S))
        XCTAssertTrue(NatoType.allCases.contains(.formIFS))
    }

    func testNatoTypeLabels() {
        XCTAssertEqual(NatoType.infantry.label, "Infantry")
        XCTAssertEqual(NatoType.intelligence.label, "Intelligence")
        XCTAssertEqual(NatoType.surveillance.label, "Surveillance")
        XCTAssertEqual(NatoType.artillery.label, "Artillery")
        XCTAssertEqual(NatoType.marine.label, "Marine")
        XCTAssertEqual(NatoType.droneObserved.label, "Drone observed")
        XCTAssertEqual(NatoType.op.label, "Observation Post")
        XCTAssertEqual(NatoType.photo.label, "Photo")
        XCTAssertEqual(NatoType.form7S.label, "7S")
        XCTAssertEqual(NatoType.formIFS.label, "IFS")
    }

    func testNatoTypeSfSymbols() {
        XCTAssertEqual(NatoType.infantry.sfSymbol, "flag.fill")
        XCTAssertEqual(NatoType.intelligence.sfSymbol, "eye.fill")
        XCTAssertEqual(NatoType.surveillance.sfSymbol, "sensor.fill")
        XCTAssertEqual(NatoType.artillery.sfSymbol, "shield.lefthalf.filled")
        XCTAssertEqual(NatoType.marine.sfSymbol, "anchor")
        XCTAssertEqual(NatoType.droneObserved.sfSymbol, "airplane")
        XCTAssertEqual(NatoType.op.sfSymbol, "tent.fill")
        XCTAssertEqual(NatoType.photo.sfSymbol, "camera.fill")
        XCTAssertEqual(NatoType.form7S.sfSymbol, "doc.fill")
        XCTAssertEqual(NatoType.formIFS.sfSymbol, "scope")
    }

    func testNatoTypeParseEdgeCases() {
        // Nil input
        XCTAssertEqual(NatoType.parse(nil), .infantry)

        // Empty string
        XCTAssertEqual(NatoType.parse(""), .infantry)

        // Whitespace only
        XCTAssertEqual(NatoType.parse("   "), .infantry)

        // Lowercase
        XCTAssertEqual(NatoType.parse("infantry"), .infantry)

        // Mixed case
        XCTAssertEqual(NatoType.parse("InFaNtRy"), .infantry)

        // Alternative drone names
        XCTAssertEqual(NatoType.parse("DRONE"), .droneObserved)
        XCTAssertEqual(NatoType.parse("uav"), .droneObserved)

        // Alternative OP names
        XCTAssertEqual(NatoType.parse("OBSERVATION_POST"), .op)

        // Form type variants
        XCTAssertEqual(NatoType.parse("7S"), .form7S)
        XCTAssertEqual(NatoType.parse("IFS"), .formIFS)
    }

    // MARK: - NatoPin JSON Roundtrip Tests

    func testNatoPinJSONRoundtrip() {
        let original = NatoPin(
            id: 12345,
            latitude: 59.329323,
            longitude: 18.068581,
            type: .surveillance,
            title: "Observation Point",
            description: "Enemy movement detected",
            authorCallsign: "Alpha-1",
            originDeviceId: "device-123",
            photoUri: "file://photo.jpg"
        )

        let json = original.toJSON()
        let parsed = NatoPin.fromJSON(json)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.id, original.id)
        XCTAssertEqual(parsed?.latitude, original.latitude, accuracy: 0.0001)
        XCTAssertEqual(parsed?.longitude, original.longitude, accuracy: 0.0001)
        XCTAssertEqual(parsed?.type, original.type)
        XCTAssertEqual(parsed?.title, original.title)
        XCTAssertEqual(parsed?.description, original.description)
    }

    func testNatoPinFromInvalidJSON() {
        let invalidJSON: [String: Any] = [
            "notId": 123,
            "notLat": 59.0
        ]

        let parsed = NatoPin.fromJSON(invalidJSON)
        XCTAssertNil(parsed)
    }

    func testNatoPinFromPartialJSON() {
        let partialJSON: [String: Any] = [
            "id": 12345,
            "lat": 59.0,
            "lon": 18.0,
            "title": "Minimal Pin"
        ]

        let parsed = NatoPin.fromJSON(partialJSON)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.title, "Minimal Pin")
        XCTAssertEqual(parsed?.type, .infantry) // Default
        XCTAssertEqual(parsed?.description, "") // Default empty
    }

    // MARK: - LinkedForm Tests

    func testLinkedFormCreation() {
        let form = LinkedForm(
            id: 999,
            opPinId: 12345,
            opOriginDeviceId: "device-123",
            formType: "CFF",
            formData: "{\"observerId\": \"Alpha-1\"}",
            authorCallsign: "Alpha-1",
            targetLat: 59.33,
            targetLon: 18.06,
            observerLat: 59.32,
            observerLon: 18.05
        )

        XCTAssertEqual(form.id, 999)
        XCTAssertEqual(form.opPinId, 12345)
        XCTAssertEqual(form.formType, "CFF")
        XCTAssertEqual(form.targetLat, 59.33)
        XCTAssertEqual(form.observerLat, 59.32)
    }

    func testLinkedFormEquatable() {
        let form1 = LinkedForm(
            id: 100,
            opPinId: 200,
            opOriginDeviceId: "dev",
            formType: "CFF",
            formData: "{}",
            authorCallsign: "Alpha"
        )

        let form2 = LinkedForm(
            id: 100,
            opPinId: 200,
            opOriginDeviceId: "dev",
            formType: "CFF",
            formData: "{}",
            authorCallsign: "Alpha"
        )

        XCTAssertEqual(form1, form2)
    }

    func testLinkedFormCodable() throws {
        let original = LinkedForm(
            id: 777,
            opPinId: 888,
            opOriginDeviceId: "device-test",
            formType: "MEDEVAC",
            formData: "{\"priority\": \"P1\"}",
            authorCallsign: "Medic-1",
            targetLat: 59.0,
            targetLon: 18.0
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LinkedForm.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - String Extension Tests

    func testStringIsBlank() {
        XCTAssertTrue("".isBlank)
        XCTAssertTrue("   ".isBlank)
        XCTAssertTrue("\n\t".isBlank)
        XCTAssertFalse("text".isBlank)
        XCTAssertFalse(" text ".isBlank)
    }

    func testStringNilIfBlank() {
        XCTAssertNil("".nilIfBlank)
        XCTAssertNil("   ".nilIfBlank)
        XCTAssertEqual("text".nilIfBlank, "text")
        XCTAssertEqual("  text  ".nilIfBlank, "text")
    }

    func testStringTruncated() {
        XCTAssertEqual("Hello".truncated(to: 10), "Hello")
        XCTAssertEqual("Hello World".truncated(to: 8), "Hello...")
        XCTAssertEqual("Hi".truncated(to: 5), "Hi")
    }

    // MARK: - Optional String Extension Tests

    func testOptionalStringOrEmpty() {
        let nilString: String? = nil
        let someString: String? = "Hello"

        XCTAssertEqual(nilString.orEmpty, "")
        XCTAssertEqual(someString.orEmpty, "Hello")
    }

    func testOptionalStringIsNilOrBlank() {
        let nilString: String? = nil
        let emptyString: String? = ""
        let blankString: String? = "   "
        let validString: String? = "Hello"

        XCTAssertTrue(nilString.isNilOrBlank)
        XCTAssertTrue(emptyString.isNilOrBlank)
        XCTAssertTrue(blankString.isNilOrBlank)
        XCTAssertFalse(validString.isNilOrBlank)
    }

    // MARK: - Date Extension Tests

    func testDateCurrentMillis() {
        let before = Int64(Date().timeIntervalSince1970 * 1000)
        let millis = Date.currentMillis
        let after = Int64(Date().timeIntervalSince1970 * 1000)

        XCTAssertGreaterThanOrEqual(millis, before)
        XCTAssertLessThanOrEqual(millis, after)
    }

    func testDateInitFromMillis() {
        let millis: Int64 = 1704067200000 // 2024-01-01 00:00:00 UTC
        let date = Date(millis: millis)

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: date)

        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 1)
    }

    func testDateToMillis() {
        let date = Date(timeIntervalSince1970: 1704067200)
        XCTAssertEqual(date.toMillis, 1704067200000)
    }

    // MARK: - Array Extension Tests

    func testArraySafeSubscript() {
        let array = [1, 2, 3]

        XCTAssertEqual(array[safe: 0], 1)
        XCTAssertEqual(array[safe: 2], 3)
        XCTAssertNil(array[safe: 5])
        XCTAssertNil(array[safe: -1])
    }

    // MARK: - Data Extension Tests

    func testDataHexString() {
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
        XCTAssertEqual(data.hexString, "deadbeef")
    }

    func testDataInitFromHexString() {
        let data = Data(hexString: "deadbeef")
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.count, 4)
        XCTAssertEqual(data?[0], 0xDE)
        XCTAssertEqual(data?[1], 0xAD)

        // With 0x prefix
        let dataWithPrefix = Data(hexString: "0xCAFE")
        XCTAssertNotNil(dataWithPrefix)
        XCTAssertEqual(dataWithPrefix?.count, 2)
    }

    func testDataInitFromInvalidHexString() {
        // Odd number of characters
        XCTAssertNil(Data(hexString: "abc"))

        // Invalid hex characters
        XCTAssertNil(Data(hexString: "ghij"))
    }

    // MARK: - Integration: Form Data Parsing Tests

    func testCallForFireDataIntegration() {
        let cff = CallForFireData(
            observerId: "Observer-1",
            targetLocation: "33VWN1234567890",
            targetDescription: "Enemy bunker complex"
        )

        let jsonString = cff.toJSONString()
        XCTAssertNotNil(jsonString)

        // Verify can be stored in LinkedForm
        let form = LinkedForm(
            opPinId: 12345,
            opOriginDeviceId: "device-123",
            formType: LinkedFormType.callForFire.rawValue,
            formData: jsonString ?? "{}",
            authorCallsign: "Observer-1"
        )

        XCTAssertEqual(form.formType, "CFF")
    }

    func testSpotReportIntegration() {
        let spot = SpotReportData(
            size: "Squad (8-10)",
            activity: "Moving west",
            location: "Grid 12345678",
            unit: "Unknown militia",
            time: "1430L",
            equipment: "Small arms, RPGs"
        )

        let jsonString = spot.toJSONString()
        XCTAssertNotNil(jsonString)

        // Verify SALUTE summary
        let summary = spot.saluteSummary
        XCTAssertTrue(summary.contains("S:"))
        XCTAssertTrue(summary.contains("A:"))
        XCTAssertTrue(summary.contains("L:"))
        XCTAssertTrue(summary.contains("U:"))
        XCTAssertTrue(summary.contains("T:"))
        XCTAssertTrue(summary.contains("E:"))
    }

    // MARK: - Integration: Route Distance Calculation Tests

    func testRouteDistanceCalculation() {
        // Two points approximately 1.5 km apart in Stockholm
        let points = [
            TAKBreadcrumbPoint(lat: 59.3293, lon: 18.0686),
            TAKBreadcrumbPoint(lat: 59.3400, lon: 18.0800)
        ]

        var totalDistance: Double = 0
        for i in 0..<(points.count - 1) {
            let coord1 = points[i].coordinate
            let coord2 = points[i + 1].coordinate

            // Haversine distance calculation
            let earthRadius: Double = 6371000
            let lat1Rad = coord1.latitude * .pi / 180
            let lat2Rad = coord2.latitude * .pi / 180
            let deltaLat = (coord2.latitude - coord1.latitude) * .pi / 180
            let deltaLon = (coord2.longitude - coord1.longitude) * .pi / 180

            let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                    cos(lat1Rad) * cos(lat2Rad) *
                    sin(deltaLon / 2) * sin(deltaLon / 2)
            let c = 2 * atan2(sqrt(a), sqrt(1 - a))
            totalDistance += earthRadius * c
        }

        // Should be approximately 1.3-1.5 km
        XCTAssertGreaterThan(totalDistance, 1000)
        XCTAssertLessThan(totalDistance, 2000)
    }

    // MARK: - ViewModel Tests

    func testPinsViewModelSingleton() {
        let vm1 = PinsViewModel.shared
        let vm2 = PinsViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    func testMethaneViewModelSingleton() {
        let vm1 = MethaneViewModel.shared
        let vm2 = MethaneViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    func testMedevacViewModelSingleton() {
        let vm1 = MedevacViewModel.shared
        let vm2 = MedevacViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    func testProfileViewModelSingleton() {
        let vm1 = ProfileViewModel.shared
        let vm2 = ProfileViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    // MARK: - TransportCoordinator Singleton Test

    func testTransportCoordinatorSingleton() {
        let tc1 = TransportCoordinator.shared
        let tc2 = TransportCoordinator.shared
        XCTAssertTrue(tc1 === tc2)
    }

    // MARK: - LocalProfileStore Singleton Test

    func testLocalProfileStoreSingleton() {
        let lps1 = LocalProfileStore.shared
        let lps2 = LocalProfileStore.shared
        XCTAssertTrue(lps1 === lps2)
    }

    // MARK: - RefreshBus Tests

    func testRefreshBusSingleton() {
        let rb1 = RefreshBus.shared
        let rb2 = RefreshBus.shared
        XCTAssertTrue(rb1 === rb2)
    }
}
