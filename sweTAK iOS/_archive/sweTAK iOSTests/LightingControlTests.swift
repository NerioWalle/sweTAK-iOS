import XCTest
import CoreLocation
@testable import sweTAK

final class LightingControlTests: XCTestCase {

    // MARK: - ThemeMode Tests

    func testThemeModeRawValues() {
        XCTAssertEqual(ThemeMode.system.rawValue, "SYSTEM")
        XCTAssertEqual(ThemeMode.light.rawValue, "LIGHT")
        XCTAssertEqual(ThemeMode.dark.rawValue, "DARK")
        XCTAssertEqual(ThemeMode.nightVision.rawValue, "NIGHT_VISION")
    }

    func testThemeModeDisplayNames() {
        XCTAssertEqual(ThemeMode.system.displayName, "System")
        XCTAssertEqual(ThemeMode.light.displayName, "Light")
        XCTAssertEqual(ThemeMode.dark.displayName, "Dark")
        XCTAssertEqual(ThemeMode.nightVision.displayName, "Night Vision")
    }

    func testThemeModeCaseIterable() {
        XCTAssertEqual(ThemeMode.allCases.count, 4)
        XCTAssertTrue(ThemeMode.allCases.contains(.system))
        XCTAssertTrue(ThemeMode.allCases.contains(.light))
        XCTAssertTrue(ThemeMode.allCases.contains(.dark))
        XCTAssertTrue(ThemeMode.allCases.contains(.nightVision))
    }

    // MARK: - NightVisionColor Tests

    func testNightVisionColorRawValues() {
        XCTAssertEqual(NightVisionColor.red.rawValue, "RED")
        XCTAssertEqual(NightVisionColor.green.rawValue, "GREEN")
        XCTAssertEqual(NightVisionColor.blue.rawValue, "BLUE")
    }

    func testNightVisionColorDisplayNames() {
        XCTAssertEqual(NightVisionColor.red.displayName, "Red")
        XCTAssertEqual(NightVisionColor.green.displayName, "Green")
        XCTAssertEqual(NightVisionColor.blue.displayName, "Blue")
    }

    func testNightVisionColorCaseIterable() {
        XCTAssertEqual(NightVisionColor.allCases.count, 3)
        XCTAssertTrue(NightVisionColor.allCases.contains(.red))
        XCTAssertTrue(NightVisionColor.allCases.contains(.green))
        XCTAssertTrue(NightVisionColor.allCases.contains(.blue))
    }

    // MARK: - LightingMenuLevel Tests

    func testLightingMenuLevelRawValues() {
        XCTAssertEqual(LightingMenuLevel.root.rawValue, "ROOT")
        XCTAssertEqual(LightingMenuLevel.nightVision.rawValue, "NIGHT_VISION")
        XCTAssertEqual(LightingMenuLevel.torch.rawValue, "TORCH")
        XCTAssertEqual(LightingMenuLevel.screen.rawValue, "SCREEN")
    }

    // MARK: - BrightnessPreset Tests

    func testBrightnessPresetLevels() {
        XCTAssertEqual(BrightnessPreset.low.level, 0.1, accuracy: 0.001)
        XCTAssertEqual(BrightnessPreset.medium.level, 0.5, accuracy: 0.001)
        XCTAssertEqual(BrightnessPreset.high.level, 1.0, accuracy: 0.001)
    }

    func testBrightnessPresetDisplayNames() {
        XCTAssertEqual(BrightnessPreset.low.displayName, "10%")
        XCTAssertEqual(BrightnessPreset.medium.displayName, "50%")
        XCTAssertEqual(BrightnessPreset.high.displayName, "100%")
    }

    func testBrightnessPresetCaseIterable() {
        XCTAssertEqual(BrightnessPreset.allCases.count, 3)
    }

    // MARK: - TorchManager Tests

    func testTorchManagerSingleton() {
        let manager1 = TorchManager.shared
        let manager2 = TorchManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    func testTorchManagerInitialState() {
        let manager = TorchManager.shared
        // On simulator, torch is not available
        // Just verify initial state is reasonable
        XCTAssertFalse(manager.isEnabled)
        XCTAssertGreaterThanOrEqual(manager.intensity, 0.0)
        XCTAssertLessThanOrEqual(manager.intensity, 1.0)
    }

    // MARK: - ScreenBrightnessManager Tests

    func testScreenBrightnessManagerSingleton() {
        let manager1 = ScreenBrightnessManager.shared
        let manager2 = ScreenBrightnessManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    func testScreenBrightnessManagerInitialState() {
        let manager = ScreenBrightnessManager.shared
        XCTAssertGreaterThanOrEqual(manager.brightness, 0.0)
        XCTAssertLessThanOrEqual(manager.brightness, 1.0)
    }

    // MARK: - RoutePlanningState Tests

    func testRoutePlanningStateInitialState() {
        let state = RoutePlanningState()
        XCTAssertFalse(state.isPlanning)
        XCTAssertTrue(state.waypoints.isEmpty)
        XCTAssertEqual(state.totalDistance, 0)
    }

    func testRoutePlanningStateStartPlanning() {
        let state = RoutePlanningState()
        state.startPlanning()
        XCTAssertTrue(state.isPlanning)
        XCTAssertTrue(state.waypoints.isEmpty)
    }

    func testRoutePlanningStateAddWaypoint() {
        let state = RoutePlanningState()
        state.startPlanning()

        let coord1 = CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06)
        let coord2 = CLLocationCoordinate2D(latitude: 59.34, longitude: 18.07)

        state.addWaypoint(coord1)
        XCTAssertEqual(state.waypoints.count, 1)

        state.addWaypoint(coord2)
        XCTAssertEqual(state.waypoints.count, 2)
    }

    func testRoutePlanningStateUndoLastWaypoint() {
        let state = RoutePlanningState()
        state.startPlanning()

        let coord1 = CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06)
        let coord2 = CLLocationCoordinate2D(latitude: 59.34, longitude: 18.07)

        state.addWaypoint(coord1)
        state.addWaypoint(coord2)
        XCTAssertEqual(state.waypoints.count, 2)

        state.undoLastWaypoint()
        XCTAssertEqual(state.waypoints.count, 1)

        state.undoLastWaypoint()
        XCTAssertEqual(state.waypoints.count, 0)

        // Undo on empty should not crash
        state.undoLastWaypoint()
        XCTAssertEqual(state.waypoints.count, 0)
    }

    func testRoutePlanningStateCancelPlanning() {
        let state = RoutePlanningState()
        state.startPlanning()

        let coord = CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06)
        state.addWaypoint(coord)

        state.cancelPlanning()
        XCTAssertFalse(state.isPlanning)
        XCTAssertTrue(state.waypoints.isEmpty)
    }

    func testRoutePlanningStateCompleteRouteSuccess() {
        let state = RoutePlanningState()
        state.startPlanning()

        let coord1 = CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06)
        let coord2 = CLLocationCoordinate2D(latitude: 59.34, longitude: 18.07)

        state.addWaypoint(coord1)
        state.addWaypoint(coord2)

        let route = state.completeRoute(name: "Test Route")

        XCTAssertNotNil(route)
        XCTAssertEqual(route?.name, "Test Route")
        XCTAssertEqual(route?.waypoints.count, 2)
        XCTAssertFalse(state.isPlanning)
        XCTAssertTrue(state.waypoints.isEmpty)
    }

    func testRoutePlanningStateCompleteRouteFailsWithLessThanTwoPoints() {
        let state = RoutePlanningState()
        state.startPlanning()

        let coord = CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06)
        state.addWaypoint(coord)

        let route = state.completeRoute(name: "Test Route")
        XCTAssertNil(route)
    }

    func testRoutePlanningStateTotalDistance() {
        let state = RoutePlanningState()
        state.startPlanning()

        // Two points approximately 1km apart
        let coord1 = CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)
        let coord2 = CLLocationCoordinate2D(latitude: 59.3383, longitude: 18.0686)

        state.addWaypoint(coord1)
        state.addWaypoint(coord2)

        // Should be approximately 1000m
        XCTAssertGreaterThan(state.totalDistance, 900)
        XCTAssertLessThan(state.totalDistance, 1100)
    }

    func testRoutePlanningStateTotalDistanceMultiplePoints() {
        let state = RoutePlanningState()
        state.startPlanning()

        // Three points forming a path
        let coord1 = CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06)
        let coord2 = CLLocationCoordinate2D(latitude: 59.34, longitude: 18.06)
        let coord3 = CLLocationCoordinate2D(latitude: 59.34, longitude: 18.08)

        state.addWaypoint(coord1)
        state.addWaypoint(coord2)
        state.addWaypoint(coord3)

        // Total should be sum of both segments
        XCTAssertGreaterThan(state.totalDistance, 0)
    }

    func testRoutePlanningStateTotalDistanceEmptyRoute() {
        let state = RoutePlanningState()
        XCTAssertEqual(state.totalDistance, 0)
    }

    func testRoutePlanningStateTotalDistanceSinglePoint() {
        let state = RoutePlanningState()
        state.startPlanning()
        state.addWaypoint(CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06))
        XCTAssertEqual(state.totalDistance, 0)
    }

    // MARK: - PlannedRoute Tests

    func testPlannedRouteCreation() {
        let waypoints = [
            RouteWaypoint(coordinate: CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06)),
            RouteWaypoint(coordinate: CLLocationCoordinate2D(latitude: 59.34, longitude: 18.07))
        ]

        let route = PlannedRoute(
            name: "Test Route",
            waypoints: waypoints,
            createdAt: Date()
        )

        XCTAssertEqual(route.name, "Test Route")
        XCTAssertEqual(route.waypoints.count, 2)
        XCTAssertFalse(route.id.isEmpty)
    }

    func testPlannedRouteDistanceString() {
        let waypoints = [
            RouteWaypoint(coordinate: CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06)),
            RouteWaypoint(coordinate: CLLocationCoordinate2D(latitude: 59.34, longitude: 18.07))
        ]

        let route = PlannedRoute(
            name: "Test Route",
            waypoints: waypoints,
            createdAt: Date()
        )

        // Should have a distance string (either m or km)
        XCTAssertFalse(route.distanceString.isEmpty)
        XCTAssertTrue(route.distanceString.contains("m") || route.distanceString.contains("km"))
    }

    // MARK: - RouteWaypoint Tests

    func testRouteWaypointCreation() {
        let coord = CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06)
        let waypoint = RouteWaypoint(coordinate: coord)

        XCTAssertEqual(waypoint.latitude, 59.33)
        XCTAssertEqual(waypoint.longitude, 18.06)
        XCTAssertFalse(waypoint.id.isEmpty)
    }

    func testRouteWaypointCoordinateProperty() {
        let waypoint = RouteWaypoint(coordinate: CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06))

        XCTAssertEqual(waypoint.coordinate.latitude, 59.33, accuracy: 0.0001)
        XCTAssertEqual(waypoint.coordinate.longitude, 18.06, accuracy: 0.0001)
    }
}
