import XCTest
import CoreLocation
@testable import sweTAK

/// Tests for Phase 24: Map Coordinate and Profile Utilities
final class MapUtilitiesPhase24Tests: XCTestCase {

    // MARK: - Coordinate Validation Tests

    func testValidLatitude() {
        XCTAssertTrue(MapCoordinateUtils.isValidLatitude(0))
        XCTAssertTrue(MapCoordinateUtils.isValidLatitude(45.5))
        XCTAssertTrue(MapCoordinateUtils.isValidLatitude(-45.5))
        XCTAssertTrue(MapCoordinateUtils.isValidLatitude(90))
        XCTAssertTrue(MapCoordinateUtils.isValidLatitude(-90))

        XCTAssertFalse(MapCoordinateUtils.isValidLatitude(90.1))
        XCTAssertFalse(MapCoordinateUtils.isValidLatitude(-90.1))
        XCTAssertFalse(MapCoordinateUtils.isValidLatitude(.nan))
        XCTAssertFalse(MapCoordinateUtils.isValidLatitude(.infinity))
    }

    func testValidLongitude() {
        XCTAssertTrue(MapCoordinateUtils.isValidLongitude(0))
        XCTAssertTrue(MapCoordinateUtils.isValidLongitude(90.5))
        XCTAssertTrue(MapCoordinateUtils.isValidLongitude(-90.5))
        XCTAssertTrue(MapCoordinateUtils.isValidLongitude(180))
        XCTAssertTrue(MapCoordinateUtils.isValidLongitude(-180))

        XCTAssertFalse(MapCoordinateUtils.isValidLongitude(180.1))
        XCTAssertFalse(MapCoordinateUtils.isValidLongitude(-180.1))
        XCTAssertFalse(MapCoordinateUtils.isValidLongitude(.nan))
    }

    func testClampLatitude() {
        XCTAssertEqual(MapCoordinateUtils.clampLatitude(45), 45)
        XCTAssertEqual(MapCoordinateUtils.clampLatitude(95), 90)
        XCTAssertEqual(MapCoordinateUtils.clampLatitude(-95), -90)
        XCTAssertNil(MapCoordinateUtils.clampLatitude(.nan))
    }

    func testClampLongitude() {
        XCTAssertEqual(MapCoordinateUtils.clampLongitude(90), 90)
        XCTAssertEqual(MapCoordinateUtils.clampLongitude(200), 180)
        XCTAssertEqual(MapCoordinateUtils.clampLongitude(-200), -180)
        XCTAssertNil(MapCoordinateUtils.clampLongitude(.infinity))
    }

    // MARK: - Coordinate Parsing Tests

    func testParseLatLonWithComma() {
        let result = MapCoordinateUtils.parseLatLon("59.3293, 18.0686")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.latitude ?? 0, 59.3293, accuracy: 0.0001)
        XCTAssertEqual(result?.longitude ?? 0, 18.0686, accuracy: 0.0001)
    }

    func testParseLatLonWithSpace() {
        let result = MapCoordinateUtils.parseLatLon("59.3293 18.0686")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.latitude ?? 0, 59.3293, accuracy: 0.0001)
        XCTAssertEqual(result?.longitude ?? 0, 18.0686, accuracy: 0.0001)
    }

    func testParseLatLonInvalid() {
        XCTAssertNil(MapCoordinateUtils.parseLatLon("invalid"))
        XCTAssertNil(MapCoordinateUtils.parseLatLon("59.3293"))
        XCTAssertNil(MapCoordinateUtils.parseLatLon("95, 18.0686")) // Invalid latitude
    }

    // MARK: - MGRS Conversion Tests

    func testMgrsConversion() {
        // Stockholm coordinates
        let mgrs = MapCoordinateUtils.toMgrs(lat: 59.3293, lon: 18.0686)
        XCTAssertFalse(mgrs.isEmpty)

        // MGRS should start with zone number
        let firstChar = mgrs.first
        XCTAssertNotNil(firstChar)
        XCTAssertTrue(firstChar?.isNumber ?? false)
    }

    func testMgrsRoundTrip() {
        let originalLat = 59.3293
        let originalLon = 18.0686

        let mgrs = MapCoordinateUtils.toMgrs(lat: originalLat, lon: originalLon)
        guard let parsed = MapCoordinateUtils.parseMgrs(mgrs) else {
            XCTFail("Failed to parse generated MGRS")
            return
        }

        // Should be within ~1 meter accuracy
        XCTAssertEqual(parsed.latitude, originalLat, accuracy: 0.0001)
        XCTAssertEqual(parsed.longitude, originalLon, accuracy: 0.0001)
    }

    // MARK: - Distance Calculation Tests

    func testHaversineDistance() {
        // Stockholm to Gothenburg ~400km
        let stockholm = CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)
        let gothenburg = CLLocationCoordinate2D(latitude: 57.7089, longitude: 11.9746)

        let distance = MapCoordinateUtils.haversineMeters(from: stockholm, to: gothenburg)

        // Should be approximately 400km
        XCTAssertGreaterThan(distance, 350_000)
        XCTAssertLessThan(distance, 450_000)
    }

    func testHaversineDistanceZero() {
        let point = CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)
        let distance = MapCoordinateUtils.haversineMeters(from: point, to: point)
        XCTAssertEqual(distance, 0, accuracy: 0.001)
    }

    // MARK: - Bounds Calculation Tests

    func testBoundsForRadius() {
        let center = CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)
        let bounds = MapCoordinateUtils.boundsForRadius(center: center, radiusMeters: 1000)

        XCTAssertGreaterThan(bounds.north, center.latitude)
        XCTAssertLessThan(bounds.south, center.latitude)
        XCTAssertGreaterThan(bounds.east, center.longitude)
        XCTAssertLessThan(bounds.west, center.longitude)
    }

    // MARK: - Unit Conversion Tests

    func testMetersToFeet() {
        let feet = MapCoordinateUtils.metersToFeet(1)
        XCTAssertEqual(feet, 3.280839895, accuracy: 0.0001)
    }

    func testFeetToMeters() {
        let meters = MapCoordinateUtils.feetToMeters(3.280839895)
        XCTAssertEqual(meters, 1.0, accuracy: 0.0001)
    }

    func testKilometersToMiles() {
        let miles = MapCoordinateUtils.kilometersToMiles(1.609344)
        XCTAssertEqual(miles, 1.0, accuracy: 0.01)
    }

    // MARK: - Distance Formatting Tests

    func testFormatDistanceMetric() {
        XCTAssertEqual(MapCoordinateUtils.formatDistance(500, units: .metric), "500 m")
        XCTAssertEqual(MapCoordinateUtils.formatDistance(1500, units: .metric), "1.50 km")
    }

    func testFormatDistanceImperial() {
        let imperial = MapCoordinateUtils.formatDistance(1609.344, units: .imperial)
        XCTAssertTrue(imperial.contains("mi"))
    }

    func testFormatAltitude() {
        XCTAssertEqual(MapCoordinateUtils.formatAltitude(100, units: .metric), "100 m")
        XCTAssertTrue(MapCoordinateUtils.formatAltitude(100, units: .imperial).contains("ft"))
    }

    func testFormatSpeed() {
        let metricSpeed = MapCoordinateUtils.formatSpeed(10, units: .metric)
        XCTAssertTrue(metricSpeed.contains("km/h"))

        let imperialSpeed = MapCoordinateUtils.formatSpeed(10, units: .imperial)
        XCTAssertTrue(imperialSpeed.contains("mph"))
    }

    // MARK: - Coordinate Mode Formatting Tests

    func testFormatCoordinateMGRS() {
        let formatted = MapCoordinateUtils.formatCoordinate(lat: 59.3293, lon: 18.0686, mode: .mgrs)
        XCTAssertFalse(formatted.isEmpty)
        // MGRS starts with zone number
        XCTAssertTrue(formatted.first?.isNumber ?? false)
    }

    func testFormatCoordinateLatLon() {
        let formatted = MapCoordinateUtils.formatCoordinate(lat: 59.3293, lon: 18.0686, mode: .latLon)
        XCTAssertTrue(formatted.contains("59.329"))
        XCTAssertTrue(formatted.contains("18.068"))
    }

    // MARK: - Profile Sanitization Tests

    func testSanitizeProfileFieldValid() {
        XCTAssertEqual(MapProfileUtils.sanitizeProfileField("John"), "John")
        XCTAssertEqual(MapProfileUtils.sanitizeProfileField("  John  "), "John")
    }

    func testSanitizeProfileFieldNull() {
        XCTAssertNil(MapProfileUtils.sanitizeProfileField(nil))
        XCTAssertNil(MapProfileUtils.sanitizeProfileField(""))
        XCTAssertNil(MapProfileUtils.sanitizeProfileField("null"))
        XCTAssertNil(MapProfileUtils.sanitizeProfileField("NULL"))
        XCTAssertNil(MapProfileUtils.sanitizeProfileField("undefined"))
        XCTAssertNil(MapProfileUtils.sanitizeProfileField("Unknown"))
    }

    func testSanitizeProfileFieldMaxLength() {
        let long = String(repeating: "a", count: 100)
        let result = MapProfileUtils.sanitizeProfileField(long, maxLength: 10)
        XCTAssertEqual(result?.count, 10)
    }

    func testSanitizeCallsign() {
        XCTAssertEqual(MapProfileUtils.sanitizeCallsign("alpha-1"), "ALPHA-1")
        XCTAssertNil(MapProfileUtils.sanitizeCallsign("null"))
    }

    func testSanitizeEmail() {
        XCTAssertEqual(MapProfileUtils.sanitizeEmail("Test@Example.com"), "test@example.com")
        XCTAssertNil(MapProfileUtils.sanitizeEmail("not-an-email"))
    }

    func testSanitizePhone() {
        XCTAssertNotNil(MapProfileUtils.sanitizePhone("+46 123 456 789"))
        XCTAssertNil(MapProfileUtils.sanitizePhone("abc"))
    }

    // MARK: - Contact Lookup Tests

    func testContactNicknameOrNull() {
        let contacts: [String: ContactProfile] = [
            "device-1": ContactProfile(deviceId: "device-1", nickname: "Alpha", callsign: "A1")
        ]

        XCTAssertEqual(MapProfileUtils.contactNicknameOrNull(contacts: contacts, deviceId: "device-1"), "Alpha")
        XCTAssertNil(MapProfileUtils.contactNicknameOrNull(contacts: contacts, deviceId: "device-2"))
    }

    func testDisplayNameFor() {
        let contacts: [String: ContactProfile] = [
            "device-1": ContactProfile(deviceId: "device-1", nickname: "Alpha", callsign: "A1")
        ]

        let name = MapProfileUtils.displayNameFor(deviceId: "device-1", contacts: contacts)
        XCTAssertTrue(name.contains("A1"))

        let unknown = MapProfileUtils.displayNameFor(deviceId: "device-unknown", contacts: contacts)
        XCTAssertEqual(unknown.count, 8) // Truncated device ID
    }

    // MARK: - Contact Merging Tests

    func testUpsertContact() {
        var contacts: [String: ContactProfile] = [:]

        let contact1 = ContactProfile(deviceId: "d1", nickname: "Alpha")
        MapProfileUtils.upsertContact(into: &contacts, incoming: contact1)

        XCTAssertEqual(contacts.count, 1)
        XCTAssertEqual(contacts["d1"]?.nickname, "Alpha")

        // Update with additional info
        let contact2 = ContactProfile(deviceId: "d1", callsign: "A1")
        MapProfileUtils.upsertContact(into: &contacts, incoming: contact2)

        XCTAssertEqual(contacts.count, 1)
        XCTAssertEqual(contacts["d1"]?.nickname, "Alpha") // Preserved
        XCTAssertEqual(contacts["d1"]?.callsign, "A1") // Added
    }

    // MARK: - Marker Label Tests

    func testMarkerLabel() {
        XCTAssertEqual(
            MapProfileUtils.markerLabel(callsign: "ALPHA-1", nickname: nil, deviceId: "abc123"),
            "ALPHA-1"
        )

        XCTAssertEqual(
            MapProfileUtils.markerLabel(callsign: nil, nickname: "John", deviceId: "abc123"),
            "John"
        )

        XCTAssertEqual(
            MapProfileUtils.markerLabel(callsign: nil, nickname: nil, deviceId: "abc12345").count,
            8
        )
    }

    // MARK: - Contact Staleness Tests

    func testContactStaleness() {
        let freshContact = ContactProfile(
            deviceId: "d1",
            lastSeenMs: Date.currentMillis
        )
        XCTAssertEqual(MapProfileUtils.staleness(for: freshContact), .active)

        let oldContact = ContactProfile(
            deviceId: "d2",
            lastSeenMs: Date.currentMillis - 3_600_000 // 1 hour ago
        )
        XCTAssertEqual(MapProfileUtils.staleness(for: oldContact), .stale)

        let veryOldContact = ContactProfile(
            deviceId: "d3",
            lastSeenMs: Date.currentMillis - 10_800_000 // 3 hours ago
        )
        XCTAssertEqual(MapProfileUtils.staleness(for: veryOldContact), .inactive)
    }

    // MARK: - CLLocationCoordinate2D Extension Tests

    func testCoordinateFormatted() {
        let coord = CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)
        let latLon = coord.formatted(mode: .latLon)
        XCTAssertTrue(latLon.contains("59.329"))
    }

    func testCoordinateHaversineDistance() {
        let a = CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)
        let b = CLLocationCoordinate2D(latitude: 59.3393, longitude: 18.0786)
        let distance = a.haversineDistance(to: b)
        XCTAssertGreaterThan(distance, 0)
    }

    func testCoordinateIsValid() {
        let valid = CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)
        XCTAssertTrue(valid.isValid)

        let invalid = CLLocationCoordinate2D(latitude: 91, longitude: 181)
        XCTAssertFalse(invalid.isValid)
    }

    // MARK: - Enum Tests

    func testCoordModeDisplayName() {
        XCTAssertEqual(CoordMode.mgrs.displayName, "MGRS")
        XCTAssertEqual(CoordMode.latLon.displayName, "Lat/Lon")
    }

    func testUnitSystemDisplayName() {
        XCTAssertEqual(UnitSystem.metric.displayName, "Metric")
        XCTAssertEqual(UnitSystem.imperial.displayName, "Imperial")
    }

    func testPositionUnitToMillis() {
        XCTAssertEqual(PositionUnit.sec.toMillis(5), 5_000)
        XCTAssertEqual(PositionUnit.min.toMillis(2), 120_000)
        XCTAssertEqual(PositionUnit.hour.toMillis(1), 3_600_000)
    }
}
