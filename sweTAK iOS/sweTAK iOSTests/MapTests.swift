import XCTest
import CoreLocation
import MapKit
@testable import sweTAK

final class MapTests: XCTestCase {

    // MARK: - MapViewModel Tests

    func testMapViewModelSingleton() {
        let vm1 = MapViewModel.shared
        let vm2 = MapViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    func testMapViewModelDefaultState() {
        let vm = MapViewModel.shared
        XCTAssertEqual(vm.zoom, 14.0)
        XCTAssertEqual(vm.mapBearing, 0.0)
        XCTAssertFalse(vm.followMe)
        XCTAssertEqual(vm.mapOrientation, .freeRotate)
    }

    func testMapViewModelFollowModeToggle() {
        let vm = MapViewModel.shared
        let initialState = vm.followMe

        vm.toggleFollowMe()
        XCTAssertNotEqual(vm.followMe, initialState)

        vm.toggleFollowMe()
        XCTAssertEqual(vm.followMe, initialState)
    }

    func testMapViewModelPositionUpdate() {
        let vm = MapViewModel.shared
        let testCoord = CLLocationCoordinate2D(latitude: 59.329, longitude: 18.068)

        vm.updateMyPosition(testCoord, altitude: 50.0)

        XCTAssertNotNil(vm.myPosition)
        XCTAssertEqual(vm.myPosition?.latitude, 59.329, accuracy: 0.001)
        XCTAssertEqual(vm.myPosition?.longitude, 18.068, accuracy: 0.001)
        XCTAssertEqual(vm.myAltitudeMeters, 50.0)
    }

    func testMapViewModelCameraPosition() {
        let vm = MapViewModel.shared

        vm.saveCameraPosition(lat: 59.3, lng: 18.0, zoom: 15.0, bearing: 45.0)

        XCTAssertNotNil(vm.cameraPosition)
        XCTAssertEqual(vm.cameraPosition?.latitude, 59.3)
        XCTAssertEqual(vm.cameraPosition?.longitude, 18.0)
        XCTAssertEqual(vm.cameraPosition?.zoom, 15.0)
        XCTAssertEqual(vm.cameraPosition?.bearing, 45.0)
    }

    func testMapViewModelResetBearing() {
        let vm = MapViewModel.shared
        vm.updateMapBearing(90.0)
        XCTAssertEqual(vm.mapBearing, 90.0)

        vm.resetBearing()
        XCTAssertEqual(vm.mapBearing, 0.0)
    }

    func testMapViewModelPeerPositions() {
        let vm = MapViewModel.shared

        vm.updatePeerPosition(
            deviceId: "test-device",
            callsign: "Alpha-1",
            latitude: 59.33,
            longitude: 18.07
        )

        XCTAssertEqual(vm.peerPositions.count, 1)
        XCTAssertNotNil(vm.peerPositions["test-device"])
        XCTAssertEqual(vm.peerPositions["test-device"]?.callsign, "Alpha-1")

        vm.removePeerPosition(deviceId: "test-device")
        XCTAssertNil(vm.peerPositions["test-device"])
    }

    func testMapViewModelOrientation() {
        let vm = MapViewModel.shared

        vm.setMapOrientation(.northUp)
        XCTAssertEqual(vm.mapOrientation, .northUp)

        vm.setMapOrientation(.headingUp)
        XCTAssertEqual(vm.mapOrientation, .headingUp)

        vm.setMapOrientation(.freeRotate)
        XCTAssertEqual(vm.mapOrientation, .freeRotate)
    }

    // MARK: - CameraState Tests

    func testCameraStateCreation() {
        let camera = CameraState(latitude: 59.0, longitude: 18.0, zoom: 12.0, bearing: 30.0)

        XCTAssertEqual(camera.latitude, 59.0)
        XCTAssertEqual(camera.longitude, 18.0)
        XCTAssertEqual(camera.zoom, 12.0)
        XCTAssertEqual(camera.bearing, 30.0)
    }

    func testCameraStateCoordinate() {
        let camera = CameraState(latitude: 59.0, longitude: 18.0, zoom: 12.0, bearing: 0.0)
        let coord = camera.coordinate

        XCTAssertEqual(coord.latitude, 59.0)
        XCTAssertEqual(coord.longitude, 18.0)
    }

    func testCameraStateDefaults() {
        let camera = CameraState()

        XCTAssertEqual(camera.latitude, 0)
        XCTAssertEqual(camera.longitude, 0)
        XCTAssertEqual(camera.zoom, 14.0)
        XCTAssertEqual(camera.bearing, 0)
    }

    // MARK: - PeerPosition Tests

    func testPeerPositionCreation() {
        let peer = PeerPosition(
            deviceId: "device-123",
            callsign: "Bravo-2",
            latitude: 59.35,
            longitude: 18.05
        )

        XCTAssertEqual(peer.id, "device-123")
        XCTAssertEqual(peer.deviceId, "device-123")
        XCTAssertEqual(peer.callsign, "Bravo-2")
        XCTAssertEqual(peer.latitude, 59.35)
        XCTAssertEqual(peer.longitude, 18.05)
    }

    func testPeerPositionCoordinate() {
        let peer = PeerPosition(
            deviceId: "device-123",
            callsign: "Bravo-2",
            latitude: 59.35,
            longitude: 18.05
        )

        XCTAssertEqual(peer.coordinate.latitude, 59.35)
        XCTAssertEqual(peer.coordinate.longitude, 18.05)
    }

    // MARK: - MapOrientationMode Tests

    func testMapOrientationModeRawValues() {
        XCTAssertEqual(MapOrientationMode.northUp.rawValue, "NORTH_UP")
        XCTAssertEqual(MapOrientationMode.freeRotate.rawValue, "FREE_ROTATE")
        XCTAssertEqual(MapOrientationMode.headingUp.rawValue, "HEADING_UP")
    }

    func testMapOrientationModeDisplayNames() {
        XCTAssertEqual(MapOrientationMode.northUp.displayName, "North Up")
        XCTAssertEqual(MapOrientationMode.freeRotate.displayName, "Free Rotate")
        XCTAssertEqual(MapOrientationMode.headingUp.displayName, "Heading Up")
    }

    // MARK: - BreadcrumbPoint Tests

    func testBreadcrumbPointCreation() {
        let point = BreadcrumbPoint(
            latitude: 59.33,
            longitude: 18.06,
            altitude: 25.0,
            timestamp: Date()
        )

        XCTAssertEqual(point.latitude, 59.33)
        XCTAssertEqual(point.longitude, 18.06)
        XCTAssertEqual(point.altitude, 25.0)
    }

    func testBreadcrumbPointCoordinate() {
        let point = BreadcrumbPoint(
            latitude: 59.33,
            longitude: 18.06,
            altitude: 25.0,
            timestamp: Date()
        )

        XCTAssertEqual(point.coordinate.latitude, 59.33)
        XCTAssertEqual(point.coordinate.longitude, 18.06)
    }

    // MARK: - BreadcrumbRoute Tests

    func testBreadcrumbRouteCreation() {
        let points = [
            BreadcrumbPoint(latitude: 59.33, longitude: 18.06, altitude: 25.0, timestamp: Date()),
            BreadcrumbPoint(latitude: 59.34, longitude: 18.07, altitude: 30.0, timestamp: Date())
        ]

        let route = BreadcrumbRoute(
            id: "route-1",
            points: points,
            totalDistanceMeters: 1500.0,
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            name: "Morning Patrol"
        )

        XCTAssertEqual(route.id, "route-1")
        XCTAssertEqual(route.points.count, 2)
        XCTAssertEqual(route.totalDistanceMeters, 1500.0)
        XCTAssertEqual(route.name, "Morning Patrol")
    }

    func testBreadcrumbRouteDuration() {
        let startTime = Date().addingTimeInterval(-3600) // 1 hour ago
        let endTime = Date()

        let route = BreadcrumbRoute(
            id: "route-1",
            points: [],
            totalDistanceMeters: 0,
            startTime: startTime,
            endTime: endTime
        )

        XCTAssertEqual(route.duration, 3600, accuracy: 1)
    }

    func testBreadcrumbRouteDistanceString() {
        let routeMeters = BreadcrumbRoute(
            id: "route-1",
            points: [],
            totalDistanceMeters: 500.0,
            startTime: Date(),
            endTime: Date()
        )
        XCTAssertEqual(routeMeters.distanceString, "500 m")

        let routeKm = BreadcrumbRoute(
            id: "route-2",
            points: [],
            totalDistanceMeters: 2500.0,
            startTime: Date(),
            endTime: Date()
        )
        XCTAssertEqual(routeKm.distanceString, "2.50 km")
    }

    // MARK: - PlannedWaypoint Tests

    func testPlannedWaypointCreation() {
        let waypoint = PlannedWaypoint(
            latitude: 59.40,
            longitude: 18.10,
            label: "Checkpoint Alpha"
        )

        XCTAssertEqual(waypoint.latitude, 59.40)
        XCTAssertEqual(waypoint.longitude, 18.10)
        XCTAssertEqual(waypoint.label, "Checkpoint Alpha")
    }

    // MARK: - PlannedRoute Tests

    func testPlannedRouteCreation() {
        let waypoints = [
            PlannedWaypoint(latitude: 59.33, longitude: 18.06, label: "Start"),
            PlannedWaypoint(latitude: 59.34, longitude: 18.07, label: "Waypoint 1"),
            PlannedWaypoint(latitude: 59.35, longitude: 18.08, label: "End")
        ]

        let route = PlannedRoute(
            id: "planned-1",
            name: "Patrol Route A",
            waypoints: waypoints,
            createdAt: Date()
        )

        XCTAssertEqual(route.id, "planned-1")
        XCTAssertEqual(route.name, "Patrol Route A")
        XCTAssertEqual(route.waypoints.count, 3)
    }

    func testPlannedRouteTotalDistance() {
        let waypoints = [
            PlannedWaypoint(latitude: 59.33, longitude: 18.06),
            PlannedWaypoint(latitude: 59.34, longitude: 18.06) // ~1.1km north
        ]

        let route = PlannedRoute(
            id: "planned-1",
            name: "Test Route",
            waypoints: waypoints,
            createdAt: Date()
        )

        // Distance should be approximately 1.1km (1 degree lat ≈ 111km)
        XCTAssertGreaterThan(route.totalDistanceMeters, 1000)
        XCTAssertLessThan(route.totalDistanceMeters, 1200)
    }

    // MARK: - NatoPin Tests

    func testNatoPinCreation() {
        let pin = NatoPin(
            latitude: 59.33,
            longitude: 18.06,
            type: .infantry,
            title: "Enemy Position",
            description: "Observed 3 soldiers"
        )

        XCTAssertEqual(pin.latitude, 59.33)
        XCTAssertEqual(pin.longitude, 18.06)
        XCTAssertEqual(pin.type, .infantry)
        XCTAssertEqual(pin.title, "Enemy Position")
        XCTAssertEqual(pin.description, "Observed 3 soldiers")
    }

    func testNatoPinCoordinate() {
        let pin = NatoPin(
            latitude: 59.33,
            longitude: 18.06,
            type: .op,
            title: "OP Alpha"
        )

        XCTAssertEqual(pin.coordinate.latitude, 59.33)
        XCTAssertEqual(pin.coordinate.longitude, 18.06)
    }

    func testNatoTypeLabel() {
        XCTAssertEqual(NatoType.infantry.label, "Infantry")
        XCTAssertEqual(NatoType.op.label, "Observation Post")
        XCTAssertEqual(NatoType.droneObserved.label, "Drone observed")
        XCTAssertEqual(NatoType.photo.label, "Photo")
    }

    func testNatoTypeSFSymbol() {
        XCTAssertEqual(NatoType.infantry.sfSymbol, "flag.fill")
        XCTAssertEqual(NatoType.op.sfSymbol, "tent.fill")
        XCTAssertEqual(NatoType.photo.sfSymbol, "camera.fill")
        XCTAssertEqual(NatoType.artillery.sfSymbol, "shield.lefthalf.filled")
    }

    func testNatoTypeParsing() {
        XCTAssertEqual(NatoType.parse("INFANTRY"), .infantry)
        XCTAssertEqual(NatoType.parse("OP"), .op)
        XCTAssertEqual(NatoType.parse("DRONE_OBSERVED"), .droneObserved)
        XCTAssertEqual(NatoType.parse("UAV"), .droneObserved)
        XCTAssertEqual(NatoType.parse("OBSERVATION_POST"), .op)
        XCTAssertEqual(NatoType.parse(nil), .infantry) // Default
        XCTAssertEqual(NatoType.parse("UNKNOWN"), .infantry) // Default
    }

    // MARK: - LocationManager Tests

    func testLocationManagerSingleton() {
        let lm1 = LocationManager.shared
        let lm2 = LocationManager.shared
        XCTAssertTrue(lm1 === lm2)
    }

    func testLocationManagerDefaultState() {
        let lm = LocationManager.shared
        XCTAssertFalse(lm.isRecordingBreadcrumbs)
        XCTAssertTrue(lm.breadcrumbPoints.isEmpty)
        XCTAssertEqual(lm.runningDistanceMeters, 0)
    }

    // MARK: - PinsViewModel Tests

    func testPinsViewModelSingleton() {
        let vm1 = PinsViewModel.shared
        let vm2 = PinsViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    func testPinsViewModelGeneratePinId() {
        let vm = PinsViewModel.shared
        let id1 = vm.generatePinId()
        let id2 = vm.generatePinId()

        XCTAssertGreaterThan(id1, 0)
        XCTAssertGreaterThan(id2, 0)
    }

    func testPinsViewModelGenerateFormId() {
        let vm = PinsViewModel.shared
        let id1 = vm.generateFormId()
        let id2 = vm.generateFormId()

        XCTAssertGreaterThan(id1, 0)
        XCTAssertGreaterThan(id2, 0)
    }
}
