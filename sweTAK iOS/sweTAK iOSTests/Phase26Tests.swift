import XCTest
import CoreLocation
@testable import sweTAK

/// Tests for Phase 26: Form Coordinate Formatting, Routes ViewModel
final class Phase26Tests: XCTestCase {

    // MARK: - Form Coordinate Formatting Tests

    func testFormatPinDescriptionEmpty() {
        let result = formatPinDescriptionWithCoordMode("", coordMode: .mgrs)
        XCTAssertEqual(result, "")
    }

    func testFormatPinDescriptionNoCoordinates() {
        let description = "Target spotted near the bridge"
        let result = formatPinDescriptionWithCoordMode(description, coordMode: .mgrs)
        XCTAssertEqual(result, description)
    }

    func testFormatPinDescriptionLatLonToMGRS() {
        // Description with lat/lon coordinates
        let description = "Grid Ref: 59.329300, 18.068600\nTarget: Enemy position"

        let result = formatPinDescriptionWithCoordMode(description, coordMode: .mgrs)

        // Should contain MGRS format (starts with zone number)
        XCTAssertFalse(result.contains("59.329"))
        // The result should have MGRS-like format
        XCTAssertTrue(result.contains("Target: Enemy position"))
    }

    func testFormatFormCoordinateMGRS() {
        let result = formatFormCoordinate(lat: 59.3293, lon: 18.0686, coordMode: .mgrs)
        // MGRS should start with zone number
        XCTAssertTrue(result.first?.isNumber ?? false)
        XCTAssertFalse(result.contains(","))
    }

    func testFormatFormCoordinateLatLon() {
        let result = formatFormCoordinate(lat: 59.3293, lon: 18.0686, coordMode: .latLon)
        XCTAssertTrue(result.contains("59.329"))
        XCTAssertTrue(result.contains("18.068"))
        XCTAssertTrue(result.contains(","))
    }

    func testReformat7SFormCoordinates() {
        let description = """
            Grid Ref: 59.3293, 18.0686
            Target: Enemy artillery
            Status: Active
            """

        let result = reformat7SFormCoordinates(description, coordMode: .latLon)

        // Grid ref line should be preserved
        XCTAssertTrue(result.contains("Grid Ref:"))
        XCTAssertTrue(result.contains("Target: Enemy artillery"))
        XCTAssertTrue(result.contains("Status: Active"))
    }

    func testReformatIFSFormCoordinates() {
        let description = """
            Target: 59.3293, 18.0686
            Position: 59.3300, 18.0700
            Unit: Alpha Company
            """

        let result = reformatIFSFormCoordinates(description, coordMode: .latLon)

        XCTAssertTrue(result.contains("Target:"))
        XCTAssertTrue(result.contains("Position:"))
        XCTAssertTrue(result.contains("Unit: Alpha Company"))
    }

    func testFormatFormDescriptionForViewer7S() {
        let description = "Grid Ref: 59.3293, 18.0686"
        let result = formatFormDescriptionForViewer(
            pinType: .form7S,
            description: description,
            coordMode: .latLon
        )

        XCTAssertTrue(result.contains("Grid Ref:"))
    }

    func testFormatFormDescriptionForViewerIFS() {
        let description = "Target: 59.3293, 18.0686"
        let result = formatFormDescriptionForViewer(
            pinType: .formIFS,
            description: description,
            coordMode: .latLon
        )

        XCTAssertTrue(result.contains("Target:"))
    }

    func testFormatFormDescriptionForViewerRegularPin() {
        let description = "Enemy spotted at 59.3293, 18.0686"
        let result = formatFormDescriptionForViewer(
            pinType: .infantry,
            description: description,
            coordMode: .latLon
        )

        XCTAssertTrue(result.contains("Enemy spotted"))
    }

    // MARK: - RoutesViewModel Tests

    func testRoutesViewModelSingleton() {
        let vm1 = RoutesViewModel.shared
        let vm2 = RoutesViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    func testAddBreadcrumbRoute() {
        let vm = RoutesViewModel.shared
        let initialCount = vm.breadcrumbRoutes.count

        let route = BreadcrumbRoute(
            id: "test-\(UUID().uuidString)",
            startTime: Date(),
            points: [
                BreadcrumbPoint(
                    coordinate: CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06),
                    timestamp: Date(),
                    altitude: 10
                )
            ]
        )

        vm.addBreadcrumbRoute(route)

        XCTAssertEqual(vm.breadcrumbRoutes.count, initialCount + 1)

        // Clean up
        vm.deleteBreadcrumbRoute(id: route.id)
    }

    func testDeleteBreadcrumbRoute() {
        let vm = RoutesViewModel.shared

        let route = BreadcrumbRoute(
            id: "test-delete-\(UUID().uuidString)",
            startTime: Date(),
            points: []
        )

        vm.addBreadcrumbRoute(route)
        let countAfterAdd = vm.breadcrumbRoutes.count

        vm.deleteBreadcrumbRoute(id: route.id)

        XCTAssertEqual(vm.breadcrumbRoutes.count, countAfterAdd - 1)
    }

    func testToggleBreadcrumbVisibility() {
        let vm = RoutesViewModel.shared

        let route = BreadcrumbRoute(
            id: "test-visibility-\(UUID().uuidString)",
            startTime: Date(),
            points: [],
            isVisible: true
        )

        vm.addBreadcrumbRoute(route)

        // Toggle off
        vm.toggleBreadcrumbVisibility(id: route.id)

        if let updatedRoute = vm.breadcrumbRoutes.first(where: { $0.id == route.id }) {
            XCTAssertFalse(updatedRoute.isVisible)
        }

        // Toggle back on
        vm.toggleBreadcrumbVisibility(id: route.id)

        if let updatedRoute = vm.breadcrumbRoutes.first(where: { $0.id == route.id }) {
            XCTAssertTrue(updatedRoute.isVisible)
        }

        // Clean up
        vm.deleteBreadcrumbRoute(id: route.id)
    }

    func testAddPlannedRoute() {
        let vm = RoutesViewModel.shared
        let initialCount = vm.plannedRoutes.count

        let route = PlannedRoute(
            id: "test-planned-\(UUID().uuidString)",
            name: "Test Route",
            waypoints: [
                RouteWaypoint(coordinate: CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06))
            ],
            createdAt: Date()
        )

        vm.addPlannedRoute(route)

        XCTAssertEqual(vm.plannedRoutes.count, initialCount + 1)

        // Clean up
        vm.deletePlannedRoute(id: route.id)
    }

    func testVisibleBreadcrumbRoutes() {
        let vm = RoutesViewModel.shared

        let visibleRoute = BreadcrumbRoute(
            id: "visible-\(UUID().uuidString)",
            startTime: Date(),
            points: [],
            isVisible: true
        )

        let hiddenRoute = BreadcrumbRoute(
            id: "hidden-\(UUID().uuidString)",
            startTime: Date(),
            points: [],
            isVisible: false
        )

        vm.addBreadcrumbRoute(visibleRoute)
        vm.addBreadcrumbRoute(hiddenRoute)

        let visible = vm.visibleBreadcrumbRoutes

        XCTAssertTrue(visible.contains { $0.id == visibleRoute.id })
        XCTAssertFalse(visible.contains { $0.id == hiddenRoute.id })

        // Clean up
        vm.deleteBreadcrumbRoute(id: visibleRoute.id)
        vm.deleteBreadcrumbRoute(id: hiddenRoute.id)
    }

    func testTotalRouteCount() {
        let vm = RoutesViewModel.shared
        let initialCount = vm.totalRouteCount

        let breadcrumb = BreadcrumbRoute(
            id: "count-breadcrumb-\(UUID().uuidString)",
            startTime: Date(),
            points: []
        )

        let planned = PlannedRoute(
            id: "count-planned-\(UUID().uuidString)",
            name: "Count Test",
            waypoints: [],
            createdAt: Date()
        )

        vm.addBreadcrumbRoute(breadcrumb)
        vm.addPlannedRoute(planned)

        XCTAssertEqual(vm.totalRouteCount, initialCount + 2)

        // Clean up
        vm.deleteBreadcrumbRoute(id: breadcrumb.id)
        vm.deletePlannedRoute(id: planned.id)
    }

    // MARK: - PlannedRoute Distance Calculation Tests

    func testPlannedRouteTotalDistance() {
        let route = PlannedRoute(
            name: "Distance Test",
            waypoints: [
                RouteWaypoint(coordinate: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)),
                RouteWaypoint(coordinate: CLLocationCoordinate2D(latitude: 59.3393, longitude: 18.0786))
            ],
            createdAt: Date()
        )

        let distance = route.totalDistanceMeters

        // Should be greater than 0 for different coordinates
        XCTAssertGreaterThan(distance, 0)

        // Should be roughly 1-2km for these coordinates
        XCTAssertGreaterThan(distance, 500)
        XCTAssertLessThan(distance, 5000)
    }

    func testPlannedRouteNoDistance() {
        let route = PlannedRoute(
            name: "No Distance Test",
            waypoints: [
                RouteWaypoint(coordinate: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686))
            ],
            createdAt: Date()
        )

        let distance = route.totalDistanceMeters

        // Single point should have 0 distance
        XCTAssertEqual(distance, 0)
    }

    // MARK: - Route Export/Import Tests

    func testRouteExport() {
        let vm = RoutesViewModel.shared

        let data = vm.exportRoutes()
        XCTAssertNotNil(data)

        // Should be valid JSON
        if let data = data {
            let json = try? JSONSerialization.jsonObject(with: data)
            XCTAssertNotNil(json)
        }
    }

    // MARK: - Military Time Formatting Tests

    func testFormatMilitaryDDHHMM() {
        let date = Date()
        let result = formatMilitaryDDHHMM(date)

        // Should be 6 characters: DDHHMM
        XCTAssertEqual(result.count, 6)

        // Should be all digits
        XCTAssertTrue(result.allSatisfy { $0.isNumber })
    }

    func testFormatMilitaryDTG() {
        let date = Date()
        let result = formatMilitaryDTG(date)

        // Should end with Z (UTC indicator)
        XCTAssertTrue(result.hasSuffix("Z"))

        // Should be 7 characters: DDHHMM + Z
        XCTAssertEqual(result.count, 7)
    }

    func testFormatRouteInfo() {
        let result = formatRouteInfo(
            startTimeMillis: Int64(Date().timeIntervalSince1970 * 1000),
            totalDistanceMeters: 5500,
            durationMillis: 3600000
        )

        // Should contain distance in km
        XCTAssertTrue(result.contains("km"))

        // Should contain duration in minutes
        XCTAssertTrue(result.contains("min"))
    }

    // MARK: - Relative Time Formatting Tests

    func testFormatRelativeTimeJustNow() {
        let now = Date.currentMillis
        let result = formatRelativeTime(now)

        XCTAssertEqual(result, "just now")
    }

    func testFormatRelativeTimeMinutesAgo() {
        let fiveMinutesAgo = Date.currentMillis - 5 * 60_000
        let result = formatRelativeTime(fiveMinutesAgo)

        XCTAssertTrue(result.contains("min ago"))
    }

    func testFormatRelativeTimeHoursAgo() {
        let threeHoursAgo = Date.currentMillis - 3 * 60 * 60_000
        let result = formatRelativeTime(threeHoursAgo)

        XCTAssertTrue(result.contains("h ago"))
    }

    // MARK: - Distance Formatting Tests

    func testFormatDistanceMetric() {
        let meters = formatDistance(500, useMetric: true)
        XCTAssertTrue(meters.contains("m"))

        let kilometers = formatDistance(5000, useMetric: true)
        XCTAssertTrue(kilometers.contains("km"))
    }

    func testFormatDistanceImperial() {
        let feet = formatDistance(100, useMetric: false)
        XCTAssertTrue(feet.contains("ft"))

        let miles = formatDistance(5000, useMetric: false)
        XCTAssertTrue(miles.contains("mi"))
    }

    func testFormatDistanceCompact() {
        let short = formatDistanceCompact(500)
        XCTAssertTrue(short.contains("m"))
        XCTAssertFalse(short.contains(" "))

        let long = formatDistanceCompact(5000)
        XCTAssertTrue(long.contains("km"))
    }

    // MARK: - Bearing Formatting Tests

    func testFormatBearingCardinal() {
        XCTAssertEqual(formatBearing(0), "N")
        XCTAssertEqual(formatBearing(90), "E")
        XCTAssertEqual(formatBearing(180), "S")
        XCTAssertEqual(formatBearing(270), "W")
    }

    func testFormatBearingFull() {
        let result = formatBearingFull(45)
        XCTAssertTrue(result.contains("45"))
        XCTAssertTrue(result.contains("NE"))
    }

    // MARK: - String Normalization Tests

    func testNullIfLiteral() {
        XCTAssertNil(nullIfLiteral(nil))
        XCTAssertNil(nullIfLiteral(""))
        XCTAssertNil(nullIfLiteral("null"))
        XCTAssertNil(nullIfLiteral("NULL"))
        XCTAssertNil(nullIfLiteral("undefined"))
        XCTAssertEqual(nullIfLiteral("valid"), "valid")
    }

    func testSafeLower() {
        XCTAssertEqual(safeLower(nil), "")
        XCTAssertEqual(safeLower("HELLO"), "hello")
        XCTAssertEqual(safeLower("Mixed"), "mixed")
    }
}
