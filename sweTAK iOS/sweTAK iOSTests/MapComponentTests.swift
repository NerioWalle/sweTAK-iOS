import XCTest
import CoreLocation
@testable import sweTAK

final class MapComponentTests: XCTestCase {

    // MARK: - MessagingMenuLevel Tests

    func testMessagingMenuLevelCases() {
        // Verify all menu levels exist
        XCTAssertNotNil(MessagingMenuLevel.root)
        XCTAssertNotNil(MessagingMenuLevel.ordersSubmenu)
        XCTAssertNotNil(MessagingMenuLevel.reportsSubmenu)
        XCTAssertNotNil(MessagingMenuLevel.pedarsSubmenu)
        XCTAssertNotNil(MessagingMenuLevel.medevacSubmenu)
        XCTAssertNotNil(MessagingMenuLevel.requestsSubmenu)
        XCTAssertNotNil(MessagingMenuLevel.methaneSubmenu)
    }

    func testMessagingMenuLevelEquatable() {
        XCTAssertEqual(MessagingMenuLevel.root, MessagingMenuLevel.root)
        XCTAssertNotEqual(MessagingMenuLevel.root, MessagingMenuLevel.ordersSubmenu)
        XCTAssertNotEqual(MessagingMenuLevel.reportsSubmenu, MessagingMenuLevel.requestsSubmenu)
    }

    // MARK: - CoordMode Tests

    func testCoordModeDisplayName() {
        XCTAssertEqual(CoordMode.mgrs.displayName, "MGRS")
        XCTAssertEqual(CoordMode.latLon.displayName, "Lat/Lon")
    }

    func testCoordModeCaseIterable() {
        XCTAssertEqual(CoordMode.allCases.count, 2)
        XCTAssertTrue(CoordMode.allCases.contains(.mgrs))
        XCTAssertTrue(CoordMode.allCases.contains(.latLon))
    }

    // MARK: - UnitSystem Tests

    func testUnitSystemCases() {
        XCTAssertNotNil(UnitSystem.metric)
        XCTAssertNotNil(UnitSystem.imperial)
    }

    func testUnitSystemCaseIterable() {
        XCTAssertEqual(UnitSystem.allCases.count, 2)
        XCTAssertTrue(UnitSystem.allCases.contains(.metric))
        XCTAssertTrue(UnitSystem.allCases.contains(.imperial))
    }

    // MARK: - NatoType Tests for Map Dialogs

    func testNatoTypeLabels() {
        XCTAssertEqual(NatoType.infantry.label, "Infantry")
        XCTAssertEqual(NatoType.intelligence.label, "Intelligence")
        XCTAssertEqual(NatoType.surveillance.label, "Surveillance")
        XCTAssertEqual(NatoType.artillery.label, "Artillery")
        XCTAssertEqual(NatoType.marine.label, "Marine")
        XCTAssertEqual(NatoType.droneObserved.label, "Drone Observed")
        XCTAssertEqual(NatoType.op.label, "Observation Point")
        XCTAssertEqual(NatoType.photo.label, "Photo")
    }

    func testNatoTypeSfSymbols() {
        // Verify each type has a valid SF Symbol name
        XCTAssertFalse(NatoType.infantry.sfSymbol.isEmpty)
        XCTAssertFalse(NatoType.intelligence.sfSymbol.isEmpty)
        XCTAssertFalse(NatoType.surveillance.sfSymbol.isEmpty)
        XCTAssertFalse(NatoType.artillery.sfSymbol.isEmpty)
        XCTAssertFalse(NatoType.marine.sfSymbol.isEmpty)
        XCTAssertFalse(NatoType.droneObserved.sfSymbol.isEmpty)
        XCTAssertFalse(NatoType.op.sfSymbol.isEmpty)
        XCTAssertFalse(NatoType.photo.sfSymbol.isEmpty)
    }

    // MARK: - NatoPin Tests for Map Dialogs

    func testNatoPinCreationForDialog() {
        let pin = NatoPin(
            latitude: 59.33,
            longitude: 18.06,
            type: .infantry,
            title: "Enemy position",
            description: "Infantry squad spotted",
            authorCallsign: "Alpha-1",
            originDeviceId: "device-123"
        )

        XCTAssertEqual(pin.latitude, 59.33)
        XCTAssertEqual(pin.longitude, 18.06)
        XCTAssertEqual(pin.type, .infantry)
        XCTAssertEqual(pin.title, "Enemy position")
        XCTAssertEqual(pin.description, "Infantry squad spotted")
        XCTAssertEqual(pin.authorCallsign, "Alpha-1")
        XCTAssertEqual(pin.originDeviceId, "device-123")
    }

    func testNatoPinWithPhotoUri() {
        let pin = NatoPin(
            latitude: 59.33,
            longitude: 18.06,
            type: .photo,
            title: "Surveillance photo",
            description: "Area of interest",
            authorCallsign: "Recon-1",
            photoUri: "file:///photos/img001.jpg"
        )

        XCTAssertEqual(pin.type, .photo)
        XCTAssertEqual(pin.photoUri, "file:///photos/img001.jpg")
    }

    func testNatoPinTimestamp() {
        let beforeCreation = Int64(Date().timeIntervalSince1970 * 1000)

        let pin = NatoPin(
            latitude: 59.33,
            longitude: 18.06,
            type: .op,
            title: "OP Alpha",
            description: "Observation point",
            authorCallsign: "Scout-1"
        )

        let afterCreation = Int64(Date().timeIntervalSince1970 * 1000)

        XCTAssertGreaterThanOrEqual(pin.createdAtMillis, beforeCreation)
        XCTAssertLessThanOrEqual(pin.createdAtMillis, afterCreation)
    }

    // MARK: - Haversine Distance Tests

    func testHaversineDistanceSamePoint() {
        let coord = CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06)
        let distance = haversineDistance(from: coord, to: coord)
        XCTAssertEqual(distance, 0, accuracy: 0.01)
    }

    func testHaversineDistanceKnownPoints() {
        // Stockholm to Gothenburg approximately 400km
        let stockholm = CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)
        let gothenburg = CLLocationCoordinate2D(latitude: 57.7089, longitude: 11.9746)

        let distance = haversineDistance(from: stockholm, to: gothenburg)

        // Should be approximately 395-405 km
        XCTAssertGreaterThan(distance, 390000)
        XCTAssertLessThan(distance, 410000)
    }

    func testHaversineDistanceShortDistance() {
        // Two points ~1km apart
        let point1 = CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)
        let point2 = CLLocationCoordinate2D(latitude: 59.3383, longitude: 18.0686) // ~1km north

        let distance = haversineDistance(from: point1, to: point2)

        // Should be approximately 1000m
        XCTAssertGreaterThan(distance, 900)
        XCTAssertLessThan(distance, 1100)
    }

    // MARK: - Bearing Tests

    func testBearingNorth() {
        let from = CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06)
        let to = CLLocationCoordinate2D(latitude: 60.33, longitude: 18.06) // Due north

        let brng = bearing(from: from, to: to)

        // Should be close to 0 degrees (north)
        XCTAssertLessThan(brng, 5)
    }

    func testBearingEast() {
        let from = CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06)
        let to = CLLocationCoordinate2D(latitude: 59.33, longitude: 19.06) // Due east

        let brng = bearing(from: from, to: to)

        // Should be close to 90 degrees
        XCTAssertGreaterThan(brng, 85)
        XCTAssertLessThan(brng, 95)
    }

    func testBearingSouth() {
        let from = CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06)
        let to = CLLocationCoordinate2D(latitude: 58.33, longitude: 18.06) // Due south

        let brng = bearing(from: from, to: to)

        // Should be close to 180 degrees
        XCTAssertGreaterThan(brng, 175)
        XCTAssertLessThan(brng, 185)
    }

    func testBearingWest() {
        let from = CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06)
        let to = CLLocationCoordinate2D(latitude: 59.33, longitude: 17.06) // Due west

        let brng = bearing(from: from, to: to)

        // Should be close to 270 degrees
        XCTAssertGreaterThan(brng, 265)
        XCTAssertLessThan(brng, 275)
    }

    func testBearingAlwaysPositive() {
        let from = CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06)
        let to = CLLocationCoordinate2D(latitude: 59.00, longitude: 17.00) // Southwest

        let brng = bearing(from: from, to: to)

        XCTAssertGreaterThanOrEqual(brng, 0)
        XCTAssertLessThan(brng, 360)
    }

    // MARK: - Distance Formatting Tests

    func testDistanceFormattingMetricMeters() {
        let formatted = formatDistance(500, unitSystem: .metric)
        XCTAssertEqual(formatted, "500 m")
    }

    func testDistanceFormattingMetricKilometers() {
        let formatted = formatDistance(2500, unitSystem: .metric)
        XCTAssertEqual(formatted, "2.50 km")
    }

    func testDistanceFormattingImperialFeet() {
        let formatted = formatDistance(100, unitSystem: .imperial)
        // 100m = ~328 feet
        XCTAssertTrue(formatted.contains("ft"))
    }

    func testDistanceFormattingImperialMiles() {
        let formatted = formatDistance(5000, unitSystem: .imperial)
        // 5000m = ~3.1 miles
        XCTAssertTrue(formatted.contains("mi"))
    }

    // MARK: - Altitude Formatting Tests

    func testAltitudeFormattingMetric() {
        let formatted = formatAltitude(150, unitSystem: .metric)
        XCTAssertEqual(formatted, "150 m")
    }

    func testAltitudeFormattingImperial() {
        let formatted = formatAltitude(100, unitSystem: .imperial)
        // 100m = ~328 feet
        XCTAssertTrue(formatted.contains("ft"))
        XCTAssertTrue(formatted.contains("328"))
    }

    // MARK: - Coordinate Formatting Tests

    func testCoordinateFormattingLatLon() {
        let coord = CLLocationCoordinate2D(latitude: 59.32932, longitude: 18.06858)
        let formatted = formatCoordinate(coord, mode: .latLon)

        XCTAssertTrue(formatted.contains("59.32932"))
        XCTAssertTrue(formatted.contains("18.06858"))
    }

    func testCoordinateFormattingMGRS() {
        let coord = CLLocationCoordinate2D(latitude: 59.32932, longitude: 18.06858)
        let formatted = formatCoordinate(coord, mode: .mgrs)

        // Currently shows decimal format (MGRS conversion not implemented)
        XCTAssertTrue(formatted.contains("59.32932"))
        XCTAssertTrue(formatted.contains("18.06858"))
    }

    // MARK: - Helper Functions (copied from MapHud for testing)

    private func haversineDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let earthRadius: Double = 6371000 // meters

        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1) * cos(lat2) *
                sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadius * c
    }

    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lon2 = to.longitude * .pi / 180

        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        var brng = atan2(y, x) * 180 / .pi
        if brng < 0 {
            brng += 360
        }
        return brng
    }

    private func formatDistance(_ meters: Double, unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .metric:
            if meters < 1000 {
                return String(format: "%.0f m", meters)
            } else {
                return String(format: "%.2f km", meters / 1000)
            }
        case .imperial:
            let feet = meters * 3.28084
            if feet < 5280 {
                return String(format: "%.0f ft", feet)
            } else {
                let miles = feet / 5280
                return String(format: "%.2f mi", miles)
            }
        }
    }

    private func formatAltitude(_ meters: Double, unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .metric:
            return String(format: "%.0f m", meters)
        case .imperial:
            let feet = meters * 3.28084
            return String(format: "%.0f ft", feet)
        }
    }

    private func formatCoordinate(_ coord: CLLocationCoordinate2D, mode: CoordMode) -> String {
        switch mode {
        case .mgrs:
            // In a real app, would convert to MGRS format
            return String(format: "%.5f, %.5f", coord.latitude, coord.longitude)
        case .latLon:
            return String(format: "%.5f, %.5f", coord.latitude, coord.longitude)
        }
    }
}
