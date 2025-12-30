import Foundation
import CoreLocation
import Combine
import os.log

// MARK: - TAK Breadcrumb Point (Android-compatible format)

/// A single point in a breadcrumb trail (Android API compatible)
/// Uses lat/lon fields and Int64 millis timestamp
public struct TAKBreadcrumbPoint: Codable, Equatable {
    public let lat: Double
    public let lon: Double
    public let altitude: Double?
    public let timestamp: Int64

    public init(lat: Double, lon: Double, altitude: Double? = nil, timestamp: Int64 = Date.currentMillis) {
        self.lat = lat
        self.lon = lon
        self.altitude = altitude
        self.timestamp = timestamp
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - TAK Breadcrumb Route (Android-compatible format)

/// A recorded breadcrumb route (Android API compatible)
public struct TAKBreadcrumbRoute: Codable, Equatable, Identifiable {
    public let id: String
    public let startTimeMillis: Int64
    public var points: [TAKBreadcrumbPoint]
    public var totalDistanceMeters: Float
    public var durationMillis: Int64

    public init(
        id: String = UUID().uuidString,
        startTimeMillis: Int64 = Date.currentMillis,
        points: [TAKBreadcrumbPoint] = [],
        totalDistanceMeters: Float = 0,
        durationMillis: Int64 = 0
    ) {
        self.id = id
        self.startTimeMillis = startTimeMillis
        self.points = points
        self.totalDistanceMeters = totalDistanceMeters
        self.durationMillis = durationMillis
    }
}

// MARK: - TAK Planned Waypoint (Android-compatible format)

/// A waypoint in a planned route (Android API compatible)
public struct TAKPlannedWaypoint: Codable, Equatable {
    public let lat: Double
    public let lon: Double
    public let order: Int

    public init(lat: Double, lon: Double, order: Int) {
        self.lat = lat
        self.lon = lon
        self.order = order
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - TAK Planned Route (Android-compatible format)

/// A planned route with waypoints (Android API compatible)
public struct TAKPlannedRoute: Codable, Equatable, Identifiable {
    public let id: String
    public var name: String
    public let createdAtMillis: Int64
    public var waypoints: [TAKPlannedWaypoint]
    public var totalDistanceMeters: Float

    public init(
        id: String = UUID().uuidString,
        name: String = "",
        createdAtMillis: Int64 = Date.currentMillis,
        waypoints: [TAKPlannedWaypoint] = [],
        totalDistanceMeters: Float = 0
    ) {
        self.id = id
        self.name = name
        self.createdAtMillis = createdAtMillis
        self.waypoints = waypoints
        self.totalDistanceMeters = totalDistanceMeters
    }
}

// Note: These TAK* types are Android-compatible. The iOS-native versions
// with latitude/longitude fields are in LocationManager.swift

// MARK: - Location Tracking State

/// Current state of location tracking
public enum LocationTrackingState: String {
    case idle = "IDLE"
    case tracking = "TRACKING"
    case recording = "RECORDING"
}

// MARK: - Location Tracking Manager

/// Manages continuous location tracking and breadcrumb trail recording
/// Mirrors Android LocationTrackingService functionality
public final class LocationTrackingManager: NSObject, ObservableObject {

    // MARK: - Singleton

    public static let shared = LocationTrackingManager()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "LocationTracking")

    // MARK: - Constants

    private static let breadcrumbDistanceThresholdMeters: Double = 20.0
    private static let locationUpdateInterval: TimeInterval = 1.0

    // MARK: - Published State

    @Published public private(set) var state: LocationTrackingState = .idle
    @Published public private(set) var currentLocation: CLLocationCoordinate2D?
    @Published public private(set) var currentAltitude: Double?
    @Published public private(set) var currentHeading: Double?
    @Published public private(set) var currentSpeed: Double? // meters per second
    @Published public private(set) var breadcrumbPoints: [TAKBreadcrumbPoint] = []
    @Published public private(set) var runningDistanceMeters: Double = 0
    @Published public private(set) var recordingStartTime: Date?
    @Published public private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // Route storage
    @Published public private(set) var savedBreadcrumbRoutes: [TAKBreadcrumbRoute] = []
    @Published public private(set) var savedPlannedRoutes: [TAKPlannedRoute] = []
    private var currentRouteId: String?

    // MARK: - Callbacks

    /// Called when location updates are received
    public var onLocationUpdate: ((CLLocationCoordinate2D, Double?) -> Void)?

    /// Called when recording state changes
    public var onRecordingStateChange: ((Bool) -> Void)?

    // MARK: - Private Properties

    private let locationManager: CLLocationManager
    private var lastBreadcrumbLocation: CLLocationCoordinate2D?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    public var isTracking: Bool {
        state == .tracking || state == .recording
    }

    public var isRecording: Bool {
        state == .recording
    }

    public var recordingDuration: TimeInterval {
        guard let startTime = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }

    public var runningDistanceKilometers: Double {
        runningDistanceMeters / 1000.0
    }

    // MARK: - Init

    private override init() {
        locationManager = CLLocationManager()
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true

        // Get initial authorization status
        authorizationStatus = locationManager.authorizationStatus

        // Load saved routes
        loadSavedRoutes()
    }

    // MARK: - Route Persistence

    private func loadSavedRoutes() {
        savedBreadcrumbRoutes = MapPersistence.loadBreadcrumbRoutes()
        savedPlannedRoutes = MapPersistence.loadPlannedRoutes()
        logger.info("Loaded \(self.savedBreadcrumbRoutes.count) breadcrumb routes, \(self.savedPlannedRoutes.count) planned routes")
    }

    private func saveBreadcrumbRoutes() {
        MapPersistence.saveBreadcrumbRoutes(savedBreadcrumbRoutes)
    }

    private func savePlannedRoutes() {
        MapPersistence.savePlannedRoutes(savedPlannedRoutes)
    }

    // MARK: - Authorization

    /// Request location authorization
    public func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Request always authorization (for background tracking)
    public func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    /// Check if location services are available
    public var isLocationServicesEnabled: Bool {
        CLLocationManager.locationServicesEnabled()
    }

    /// Check if we have sufficient authorization for tracking
    public var hasTrackingAuthorization: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    /// Check if we have background location authorization
    public var hasBackgroundAuthorization: Bool {
        authorizationStatus == .authorizedAlways
    }

    // MARK: - Tracking Control

    /// Start location tracking without recording breadcrumbs
    public func startTracking() {
        guard hasTrackingAuthorization else {
            print("[LocationTracking] No authorization for tracking")
            requestAuthorization()
            return
        }

        guard state == .idle else {
            print("[LocationTracking] Already tracking")
            return
        }

        state = .tracking
        locationManager.startUpdatingLocation()
        print("[LocationTracking] Tracking started")
    }

    /// Stop location tracking
    public func stopTracking() {
        guard isTracking else { return }

        if isRecording {
            stopRecording()
        }

        state = .idle
        locationManager.stopUpdatingLocation()
        print("[LocationTracking] Tracking stopped")
    }

    // MARK: - Recording Control

    /// Start recording breadcrumb trail
    public func startRecording() {
        guard hasTrackingAuthorization else {
            logger.warning("No authorization for recording")
            requestAuthorization()
            return
        }

        // Start tracking if not already
        if state == .idle {
            locationManager.startUpdatingLocation()
        }

        state = .recording
        recordingStartTime = Date()
        currentRouteId = UUID().uuidString
        breadcrumbPoints = []
        runningDistanceMeters = 0
        lastBreadcrumbLocation = nil

        // Add initial point if we have a location
        if let location = currentLocation {
            addBreadcrumbPoint(location, altitude: currentAltitude)
        }

        onRecordingStateChange?(true)
        logger.info("Recording started with id \(self.currentRouteId ?? "unknown")")
    }

    /// Stop recording breadcrumb trail and save to storage
    public func stopRecording() -> TAKBreadcrumbRoute? {
        guard isRecording else { return nil }

        let startTime = recordingStartTime ?? Date()
        let durationMillis = Int64(Date().timeIntervalSince(startTime) * 1000)

        // Create route from recorded points
        let route = TAKBreadcrumbRoute(
            id: currentRouteId ?? UUID().uuidString,
            startTimeMillis: Int64(startTime.timeIntervalSince1970 * 1000),
            points: breadcrumbPoints,
            totalDistanceMeters: Float(runningDistanceMeters),
            durationMillis: durationMillis
        )

        // Save to storage
        savedBreadcrumbRoutes.insert(route, at: 0)
        saveBreadcrumbRoutes()

        state = .tracking
        lastBreadcrumbLocation = nil
        currentRouteId = nil

        onRecordingStateChange?(false)
        logger.info("Recording stopped with \(breadcrumbPoints.count) points, saved route \(route.id)")

        return route
    }

    /// Stop recording without saving
    public func cancelRecording() {
        guard isRecording else { return }

        state = .tracking
        lastBreadcrumbLocation = nil
        currentRouteId = nil
        breadcrumbPoints = []
        runningDistanceMeters = 0
        recordingStartTime = nil

        onRecordingStateChange?(false)
        logger.info("Recording cancelled")
    }

    /// Clear recorded breadcrumbs
    public func clearBreadcrumbs() {
        breadcrumbPoints = []
        runningDistanceMeters = 0
        lastBreadcrumbLocation = nil
    }

    // MARK: - Breadcrumb Management

    private func addBreadcrumbPoint(_ coordinate: CLLocationCoordinate2D, altitude: Double?) {
        let point = TAKBreadcrumbPoint(
            lat: coordinate.latitude,
            lon: coordinate.longitude,
            altitude: altitude,
            timestamp: Date.currentMillis
        )
        breadcrumbPoints.append(point)
        lastBreadcrumbLocation = coordinate
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        let coordinate = location.coordinate
        let altitude = location.altitude
        let speed = location.speed >= 0 ? location.speed : nil

        // Update current state
        currentLocation = coordinate
        currentAltitude = altitude
        currentSpeed = speed

        // Notify callback
        onLocationUpdate?(coordinate, altitude)

        // Handle breadcrumb recording
        if isRecording {
            handleBreadcrumbUpdate(coordinate, altitude: altitude)
        }
    }

    private func handleBreadcrumbUpdate(_ coordinate: CLLocationCoordinate2D, altitude: Double?) {
        guard let lastLocation = lastBreadcrumbLocation else {
            // First point
            addBreadcrumbPoint(coordinate, altitude: altitude)
            return
        }

        let distance = haversineDistance(from: lastLocation, to: coordinate)
        if distance >= Self.breadcrumbDistanceThresholdMeters {
            addBreadcrumbPoint(coordinate, altitude: altitude)
            runningDistanceMeters += distance
        }
    }

    // MARK: - Distance Calculation

    private func haversineDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let earthRadius: Double = 6371000 // meters

        let lat1Rad = from.latitude * .pi / 180
        let lat2Rad = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLon / 2) * sin(deltaLon / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadius * c
    }

    /// Get total distance of current breadcrumb trail
    public func totalBreadcrumbDistance() -> Double {
        guard breadcrumbPoints.count >= 2 else { return 0 }

        var total: Double = 0
        for i in 0..<(breadcrumbPoints.count - 1) {
            total += haversineDistance(
                from: breadcrumbPoints[i].coordinate,
                to: breadcrumbPoints[i + 1].coordinate
            )
        }
        return total
    }

    /// Calculate total distance for a set of waypoints
    private func calculatePlannedRouteDistance(_ waypoints: [TAKPlannedWaypoint]) -> Float {
        guard waypoints.count >= 2 else { return 0 }

        var total: Double = 0
        for i in 0..<(waypoints.count - 1) {
            total += haversineDistance(
                from: waypoints[i].coordinate,
                to: waypoints[i + 1].coordinate
            )
        }
        return Float(total)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationTrackingManager: CLLocationManagerDelegate {

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        handleLocationUpdate(location)
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if newHeading.headingAccuracy >= 0 {
            currentHeading = newHeading.trueHeading
        }
    }

    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        print("[LocationTracking] Authorization changed: \(status.rawValue)")
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[LocationTracking] Location error: \(error.localizedDescription)")
    }
}

// MARK: - Heading Support

extension LocationTrackingManager {

    /// Start receiving heading updates
    public func startHeadingUpdates() {
        guard CLLocationManager.headingAvailable() else {
            print("[LocationTracking] Heading not available on this device")
            return
        }
        locationManager.startUpdatingHeading()
    }

    /// Stop receiving heading updates
    public func stopHeadingUpdates() {
        locationManager.stopUpdatingHeading()
    }
}

// MARK: - Recording Info

extension LocationTrackingManager {

    /// Get formatted recording info string
    public func formattedRecordingInfo() -> String {
        guard isRecording else { return "Not recording" }

        let distance = runningDistanceKilometers
        let duration = recordingDuration
        let points = breadcrumbPoints.count

        let durationStr: String
        if duration < 60 {
            durationStr = "\(Int(duration))s"
        } else if duration < 3600 {
            durationStr = "\(Int(duration / 60))m"
        } else {
            durationStr = String(format: "%.1fh", duration / 3600)
        }

        return String(format: "%.1f km • %@ • %d pts", distance, durationStr, points)
    }
}

// MARK: - Route Management

extension LocationTrackingManager {

    /// Delete a saved breadcrumb route
    public func deleteBreadcrumbRoute(id: String) {
        savedBreadcrumbRoutes.removeAll { $0.id == id }
        saveBreadcrumbRoutes()
        logger.info("Deleted breadcrumb route \(id)")
    }

    /// Delete all saved breadcrumb routes
    public func deleteAllBreadcrumbRoutes() {
        savedBreadcrumbRoutes.removeAll()
        saveBreadcrumbRoutes()
        logger.info("Deleted all breadcrumb routes")
    }

    /// Get a specific breadcrumb route by ID
    public func getBreadcrumbRoute(id: String) -> TAKBreadcrumbRoute? {
        savedBreadcrumbRoutes.first { $0.id == id }
    }

    // MARK: - Planned Routes

    /// Save a new planned route
    public func savePlannedRoute(_ route: TAKPlannedRoute) {
        // Remove existing route with same ID
        savedPlannedRoutes.removeAll { $0.id == route.id }
        savedPlannedRoutes.insert(route, at: 0)
        savePlannedRoutes()
        logger.info("Saved planned route \(route.id): \(route.name)")
    }

    /// Create a planned route from waypoints
    public func createPlannedRoute(
        name: String,
        waypoints: [CLLocationCoordinate2D]
    ) -> TAKPlannedRoute {
        let plannedWaypoints = waypoints.enumerated().map { index, coord in
            TAKPlannedWaypoint(lat: coord.latitude, lon: coord.longitude, order: index)
        }

        let distance = calculatePlannedRouteDistance(plannedWaypoints)

        let route = TAKPlannedRoute(
            name: name,
            waypoints: plannedWaypoints,
            totalDistanceMeters: distance
        )

        savePlannedRoute(route)
        return route
    }

    /// Delete a saved planned route
    public func deletePlannedRoute(id: String) {
        savedPlannedRoutes.removeAll { $0.id == id }
        savePlannedRoutes()
        logger.info("Deleted planned route \(id)")
    }

    /// Delete all saved planned routes
    public func deleteAllPlannedRoutes() {
        savedPlannedRoutes.removeAll()
        savePlannedRoutes()
        logger.info("Deleted all planned routes")
    }

    /// Get a specific planned route by ID
    public func getPlannedRoute(id: String) -> TAKPlannedRoute? {
        savedPlannedRoutes.first { $0.id == id }
    }

    /// Convert current breadcrumb trail to a planned route
    public func convertBreadcrumbToPlannedRoute(name: String) -> TAKPlannedRoute? {
        guard breadcrumbPoints.count >= 2 else { return nil }

        let waypoints = breadcrumbPoints.enumerated().map { index, point in
            TAKPlannedWaypoint(lat: point.lat, lon: point.lon, order: index)
        }

        let route = TAKPlannedRoute(
            name: name,
            waypoints: waypoints,
            totalDistanceMeters: Float(runningDistanceMeters)
        )

        savePlannedRoute(route)
        return route
    }
}

// MARK: - Speed Info

extension LocationTrackingManager {

    /// Get current speed in km/h
    public var speedKmh: Double? {
        guard let speed = currentSpeed, speed >= 0 else { return nil }
        return speed * 3.6
    }

    /// Get formatted speed string
    public func formattedSpeed(useMetric: Bool = true) -> String? {
        guard let speed = currentSpeed, speed >= 0 else { return nil }

        if useMetric {
            return String(format: "%.1f km/h", speed * 3.6)
        } else {
            return String(format: "%.1f mph", speed * 2.23694)
        }
    }
}
