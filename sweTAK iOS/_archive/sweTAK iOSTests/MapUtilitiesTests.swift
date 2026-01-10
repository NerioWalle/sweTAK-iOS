import XCTest
import CoreLocation
@testable import sweTAK

// MARK: - Map Persistence Tests

final class MapPersistenceTests: XCTestCase {

    override func tearDown() {
        // Clean up test data
        MapPersistence.clearAll()
        super.tearDown()
    }

    func testSaveAndLoadContacts() {
        let contact1 = ContactProfile(
            deviceId: "device-1",
            callsign: "Alpha",
            firstName: "John"
        )
        let contact2 = ContactProfile(
            deviceId: "device-2",
            callsign: "Bravo",
            firstName: "Jane"
        )

        var map: [String: ContactProfile] = [:]
        map["device-1"] = contact1
        map["device-2"] = contact2

        MapPersistence.saveContactsMap(map)

        let loaded = MapPersistence.loadContactsMap()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded["device-1"]?.callsign, "Alpha")
        XCTAssertEqual(loaded["device-2"]?.callsign, "Bravo")
    }

    func testBlockedFriends() {
        let blockedIds: Set<String> = ["blocked-1", "blocked-2", "blocked-3"]

        MapPersistence.saveBlockedFriends(blockedIds)

        let loaded = MapPersistence.loadBlockedFriends()
        XCTAssertEqual(loaded, blockedIds)
    }

    func testSaveAndLoadBreadcrumbRoutes() {
        let points = [
            BreadcrumbPoint(lat: 59.3293, lon: 18.0686, timestamp: 1000),
            BreadcrumbPoint(lat: 59.3300, lon: 18.0700, timestamp: 2000),
            BreadcrumbPoint(lat: 59.3310, lon: 18.0720, timestamp: 3000)
        ]

        let route = BreadcrumbRoute(
            id: "route-1",
            startTimeMillis: 1000,
            points: points,
            totalDistanceMeters: 500,
            durationMillis: 60000
        )

        MapPersistence.saveBreadcrumbRoutes([route])

        let loaded = MapPersistence.loadBreadcrumbRoutes()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, "route-1")
        XCTAssertEqual(loaded.first?.points.count, 3)
    }

    func testSaveAndLoadPlannedRoutes() {
        let waypoints = [
            PlannedWaypoint(lat: 59.3293, lon: 18.0686, order: 0),
            PlannedWaypoint(lat: 59.3400, lon: 18.0800, order: 1)
        ]

        let route = PlannedRoute(
            id: "planned-1",
            name: "Test Route",
            waypoints: waypoints,
            totalDistanceMeters: 1200
        )

        MapPersistence.savePlannedRoutes([route])

        let loaded = MapPersistence.loadPlannedRoutes()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Test Route")
        XCTAssertEqual(loaded.first?.waypoints.count, 2)
    }

    func testPhotoValidation() {
        // Valid JPEG magic bytes
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0] + Array(repeating: UInt8(0), count: 100))

        let encoded = MapPersistence.encodePhotoAsBase64(jpegData)
        XCTAssertNotNil(encoded)

        let decoded = MapPersistence.validateAndDecodePhoto(encoded!)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.count, jpegData.count)
    }

    func testPhotoSizeLimit() {
        // Photo larger than 5MB
        let largeData = Data(repeating: 0xFF, count: 6 * 1024 * 1024)

        let encoded = MapPersistence.encodePhotoAsBase64(largeData)
        XCTAssertNil(encoded)
    }

    func testLooksLikeIdentifierHex() {
        // Should detect hex strings
        XCTAssertTrue(looksLikeIdentifierHex("d477c8558545d38b"))
        XCTAssertTrue(looksLikeIdentifierHex("ABCDEF123456"))

        // Should detect UUIDs
        XCTAssertTrue(looksLikeIdentifierHex("550e8400-e29b-41d4-a716-446655440000"))

        // Should NOT detect normal names
        XCTAssertFalse(looksLikeIdentifierHex("John"))
        XCTAssertFalse(looksLikeIdentifierHex("Alpha-1"))
        XCTAssertFalse(looksLikeIdentifierHex("Team Leader"))

        // Edge cases
        XCTAssertFalse(looksLikeIdentifierHex(nil))
        XCTAssertFalse(looksLikeIdentifierHex(""))
        XCTAssertFalse(looksLikeIdentifierHex("   "))
    }
}

// MARK: - Map String Utils Tests

final class MapStringUtilsTests: XCTestCase {

    func testMilitaryDDHHMM() {
        // Create a known date: Nov 15, 2024 at 14:30
        var components = DateComponents()
        components.year = 2024
        components.month = 11
        components.day = 15
        components.hour = 14
        components.minute = 30

        let date = Calendar.current.date(from: components)!

        let formatted = formatMilitaryDDHHMM(date)
        XCTAssertEqual(formatted, "151430")
    }

    func testMilitaryDTG() {
        // Test that DTG ends with 'Z' (UTC)
        let dtg = formatMilitaryDTG()
        XCTAssertTrue(dtg.hasSuffix("Z"))
        XCTAssertEqual(dtg.count, 7) // DDHHMM + Z
    }

    func testHaversineDistance() {
        // Stockholm to Uppsala (~70km)
        let stockholm = CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)
        let uppsala = CLLocationCoordinate2D(latitude: 59.8586, longitude: 17.6389)

        let distance = haversineDistance(from: stockholm, to: uppsala)

        // Should be approximately 64km
        XCTAssertEqual(distance, 64000, accuracy: 5000)
    }

    func testRelativeTimeFormatting() {
        let now = Date.currentMillis

        // Just now
        XCTAssertEqual(formatRelativeTime(now - 30_000), "just now")

        // Minutes ago
        XCTAssertEqual(formatRelativeTime(now - 5 * 60_000), "5 min ago")

        // Hours ago
        XCTAssertEqual(formatRelativeTime(now - 3 * 60 * 60_000), "3 h ago")

        // Older than 24h should show date
        let oldTime = now - 48 * 60 * 60_000
        let formatted = formatRelativeTime(oldTime)
        XCTAssertTrue(formatted.contains("-"))
    }

    func testNullIfLiteral() {
        XCTAssertNil(nullIfLiteral(nil))
        XCTAssertNil(nullIfLiteral(""))
        XCTAssertNil(nullIfLiteral("   "))
        XCTAssertNil(nullIfLiteral("null"))
        XCTAssertNil(nullIfLiteral("NULL"))
        XCTAssertNil(nullIfLiteral("undefined"))

        XCTAssertEqual(nullIfLiteral("valid"), "valid")
        XCTAssertEqual(nullIfLiteral("  trimmed  "), "trimmed")
    }

    func testDisplayNickname() {
        XCTAssertEqual(displayNickname("Johnny"), "Johnny")
        XCTAssertEqual(displayNickname(nil), "No nickname")
        XCTAssertEqual(displayNickname(""), "No nickname")
        XCTAssertEqual(displayNickname("null"), "No nickname")

        // Identifier-like strings should show "No nickname"
        XCTAssertEqual(displayNickname("d477c8558545d38b"), "No nickname")
    }

    func testDurationFormatting() {
        XCTAssertEqual(formatDuration(45_000), "0:45")
        XCTAssertEqual(formatDuration(125_000), "2:05")
        XCTAssertEqual(formatDuration(3665_000), "1:01:05")
    }

    func testDistanceFormatting() {
        // Metric
        XCTAssertEqual(formatDistance(500, useMetric: true), "500 m")
        XCTAssertEqual(formatDistance(1500, useMetric: true), "1.5 km")

        // Imperial
        XCTAssertEqual(formatDistance(500, useMetric: false), "1640 ft")
        XCTAssertTrue(formatDistance(2000, useMetric: false).contains("mi"))
    }

    func testBearingFormatting() {
        XCTAssertEqual(formatBearing(0), "N")
        XCTAssertEqual(formatBearing(45), "NE")
        XCTAssertEqual(formatBearing(90), "E")
        XCTAssertEqual(formatBearing(180), "S")
        XCTAssertEqual(formatBearing(270), "W")
        XCTAssertEqual(formatBearing(360), "N")
    }

    func testPlannedRouteDistance() {
        let waypoints = [
            PlannedWaypoint(lat: 59.3293, lon: 18.0686, order: 0),
            PlannedWaypoint(lat: 59.3300, lon: 18.0686, order: 1), // ~77m north
            PlannedWaypoint(lat: 59.3300, lon: 18.0700, order: 2)  // ~80m east
        ]

        let distance = calculatePlannedRouteDistance(waypoints)

        // Total should be ~157m
        XCTAssertEqual(distance, 157, accuracy: 50)
    }
}

// MARK: - Map Network Utils Tests

final class MapNetworkUtilsTests: XCTestCase {

    func testGetLocalIPAddress() {
        // May return nil in test environment, but shouldn't crash
        let ip = MapNetworkUtils.getLocalIPAddress()
        if let ip = ip {
            XCTAssertTrue(ip.contains("."))
            XCTAssertFalse(ip.contains(":"))
        }
    }

    func testNetworkPeerEquality() {
        let peer1 = MapNetworkUtils.NetworkPeer(
            deviceId: "device-1",
            host: "192.168.1.100",
            port: 4242
        )
        let peer2 = MapNetworkUtils.NetworkPeer(
            deviceId: "device-1",
            host: "192.168.1.200", // Different host
            port: 8080 // Different port
        )

        // Should be equal based on deviceId only
        XCTAssertEqual(peer1, peer2)
    }

    func testRebuildUDPPeers() {
        var friends: [String: MapNetworkUtils.NetworkPeer] = [:]
        friends["device-1"] = MapNetworkUtils.NetworkPeer(deviceId: "device-1", host: "192.168.1.100")
        friends["device-2"] = MapNetworkUtils.NetworkPeer(deviceId: "device-2", host: "192.168.1.101")
        friends["device-3"] = MapNetworkUtils.NetworkPeer(deviceId: "device-3", host: "192.168.1.102")

        let blocked: Set<String> = ["device-2"]

        let peers = MapNetworkUtils.rebuildUDPPeers(friends: friends, blockedIds: blocked)

        // Should have 2 peers (device-2 is blocked)
        XCTAssertEqual(peers.count, 2)
        XCTAssertFalse(peers.contains { $0.deviceId == "device-2" })
    }

    func testBuildChatRecipients() {
        var friends: [String: MapNetworkUtils.NetworkPeer] = [:]
        friends["device-1"] = MapNetworkUtils.NetworkPeer(
            deviceId: "device-1",
            host: "192.168.1.100",
            callsign: "Alpha"
        )
        friends["device-2"] = MapNetworkUtils.NetworkPeer(
            deviceId: "device-2",
            host: "192.168.1.101",
            callsign: "Bravo"
        )

        let contacts: [String: ContactProfile] = [:]
        let blocked: Set<String> = []

        let recipients = MapNetworkUtils.buildChatRecipients(
            friends: friends,
            blockedIds: blocked,
            myDeviceId: "my-device",
            contacts: contacts
        )

        XCTAssertEqual(recipients.count, 2)
        XCTAssertTrue(recipients.contains { $0.callsign == "Alpha" })
        XCTAssertTrue(recipients.contains { $0.callsign == "Bravo" })
    }

    func testConnectionQuality() {
        XCTAssertEqual(MapNetworkUtils.estimateConnectionQuality(30), .excellent)
        XCTAssertEqual(MapNetworkUtils.estimateConnectionQuality(100), .good)
        XCTAssertEqual(MapNetworkUtils.estimateConnectionQuality(200), .fair)
        XCTAssertEqual(MapNetworkUtils.estimateConnectionQuality(500), .poor)
    }

    func testChatRecipientDisplayName() {
        let withNickname = ChatRecipient(deviceId: "d1", callsign: "Alpha", nickname: "Al")
        XCTAssertEqual(withNickname.displayName, "Alpha (Al)")

        let withoutNickname = ChatRecipient(deviceId: "d2", callsign: "Bravo", nickname: nil)
        XCTAssertEqual(withoutNickname.displayName, "Bravo")
    }
}

// MARK: - Breadcrumb Route Tests

final class BreadcrumbRouteTests: XCTestCase {

    func testBreadcrumbPointInit() {
        let point = BreadcrumbPoint(lat: 59.3293, lon: 18.0686, altitude: 50.0)

        XCTAssertEqual(point.lat, 59.3293)
        XCTAssertEqual(point.lon, 18.0686)
        XCTAssertEqual(point.altitude, 50.0)
        XCTAssertTrue(point.timestamp > 0)
    }

    func testBreadcrumbPointCoordinate() {
        let point = BreadcrumbPoint(lat: 59.3293, lon: 18.0686)
        let coord = point.coordinate

        XCTAssertEqual(coord.latitude, 59.3293)
        XCTAssertEqual(coord.longitude, 18.0686)
    }

    func testBreadcrumbRouteInit() {
        let route = BreadcrumbRoute(
            startTimeMillis: 1000,
            totalDistanceMeters: 5000,
            durationMillis: 3600000
        )

        XCTAssertFalse(route.id.isEmpty)
        XCTAssertEqual(route.startTimeMillis, 1000)
        XCTAssertEqual(route.totalDistanceMeters, 5000)
        XCTAssertEqual(route.durationMillis, 3600000)
    }

    func testBreadcrumbRouteComputedProperties() {
        let route = BreadcrumbRoute(
            totalDistanceMeters: 5000,
            durationMillis: 3600000 // 1 hour
        )

        XCTAssertEqual(route.distanceKilometers, 5.0)
        XCTAssertEqual(route.durationMinutes, 60)
    }

    func testPlannedWaypointCoordinate() {
        let waypoint = PlannedWaypoint(lat: 59.3293, lon: 18.0686, order: 0)
        let coord = waypoint.coordinate

        XCTAssertEqual(coord.latitude, 59.3293)
        XCTAssertEqual(coord.longitude, 18.0686)
    }

    func testPlannedRouteInit() {
        let route = PlannedRoute(
            name: "Test Route",
            totalDistanceMeters: 10000
        )

        XCTAssertFalse(route.id.isEmpty)
        XCTAssertEqual(route.name, "Test Route")
        XCTAssertEqual(route.totalDistanceMeters, 10000)
        XCTAssertEqual(route.distanceKilometers, 10.0)
    }
}

// MARK: - Recipient Status Tests

final class RecipientStatusTests: XCTestCase {

    func testOrderRecipientStatus() {
        let status = OrderRecipientStatus(
            orderId: "order-1",
            recipientDeviceId: "device-1",
            recipientCallsign: "Alpha"
        )

        XCTAssertEqual(status.orderId, "order-1")
        XCTAssertEqual(status.recipientDeviceId, "device-1")
        XCTAssertEqual(status.recipientCallsign, "Alpha")
        XCTAssertNil(status.deliveredAtMillis)
        XCTAssertNil(status.readAtMillis)
    }

    func testReportRecipientStatus() {
        let status = ReportRecipientStatus(
            reportId: "report-1",
            recipientDeviceId: "device-1"
        )

        XCTAssertEqual(status.reportId, "report-1")
        XCTAssertEqual(status.recipientDeviceId, "device-1")
    }

    func testMethaneRecipientStatus() {
        let status = MethaneRecipientStatus(
            requestId: "methane-1",
            recipientDeviceId: "device-1"
        )

        XCTAssertEqual(status.requestId, "methane-1")
    }

    func testMedevacRecipientStatus() {
        let status = MedevacRecipientStatus(
            reportId: "medevac-1",
            recipientDeviceId: "device-1"
        )

        XCTAssertEqual(status.reportId, "medevac-1")
    }
}

// MARK: - Location Tracking Manager Tests

final class LocationTrackingManagerRouteTests: XCTestCase {

    override func tearDown() {
        // Clean up routes
        LocationTrackingManager.shared.deleteAllBreadcrumbRoutes()
        LocationTrackingManager.shared.deleteAllPlannedRoutes()
        super.tearDown()
    }

    func testSingleton() {
        let manager1 = LocationTrackingManager.shared
        let manager2 = LocationTrackingManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    func testInitialState() {
        let manager = LocationTrackingManager.shared
        XCTAssertEqual(manager.state, .idle)
        XCTAssertFalse(manager.isTracking)
        XCTAssertFalse(manager.isRecording)
    }

    func testCreatePlannedRoute() {
        let manager = LocationTrackingManager.shared

        let waypoints = [
            CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
            CLLocationCoordinate2D(latitude: 59.3400, longitude: 18.0800)
        ]

        let route = manager.createPlannedRoute(name: "Test Route", waypoints: waypoints)

        XCTAssertEqual(route.name, "Test Route")
        XCTAssertEqual(route.waypoints.count, 2)
        XCTAssertTrue(route.totalDistanceMeters > 0)

        // Should be saved
        XCTAssertTrue(manager.savedPlannedRoutes.contains { $0.id == route.id })
    }

    func testDeletePlannedRoute() {
        let manager = LocationTrackingManager.shared

        let route = manager.createPlannedRoute(
            name: "To Delete",
            waypoints: [CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)]
        )

        XCTAssertTrue(manager.savedPlannedRoutes.contains { $0.id == route.id })

        manager.deletePlannedRoute(id: route.id)

        XCTAssertFalse(manager.savedPlannedRoutes.contains { $0.id == route.id })
    }

    func testGetPlannedRoute() {
        let manager = LocationTrackingManager.shared

        let route = manager.createPlannedRoute(
            name: "Find Me",
            waypoints: [CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)]
        )

        let found = manager.getPlannedRoute(id: route.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Find Me")

        let notFound = manager.getPlannedRoute(id: "nonexistent")
        XCTAssertNil(notFound)
    }
}
