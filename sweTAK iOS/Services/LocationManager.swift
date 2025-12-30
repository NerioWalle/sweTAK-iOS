import Foundation
import CoreLocation
import Combine
import os.log

/// Location manager service for GPS tracking and position broadcasting
/// Mirrors Android LocationTrackingService functionality
public final class LocationManager: NSObject, ObservableObject {

    // MARK: - Singleton

    public static let shared = LocationManager()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "LocationManager")

    // MARK: - Location Manager

    private let locationManager = CLLocationManager()

    // MARK: - Published State

    @Published public private(set) var currentLocation: CLLocation?
    @Published public private(set) var currentHeading: CLHeading?
    @Published public private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public private(set) var isTracking = false

    // MARK: - Breadcrumb Recording

    @Published public private(set) var isRecordingBreadcrumbs = false
    @Published public private(set) var breadcrumbPoints: [BreadcrumbPoint] = []
    @Published public private(set) var runningDistanceMeters: Double = 0
    @Published public private(set) var recordingStartTime: Date?

    // MARK: - Configuration

    private var broadcastInterval: TimeInterval = 5.0
    private var lastBroadcastTime: Date?
    private var broadcastTimer: Timer?

    // MARK: - Publishers

    private let locationSubject = PassthroughSubject<CLLocation, Never>()
    public var locationPublisher: AnyPublisher<CLLocation, Never> {
        locationSubject.eraseToAnyPublisher()
    }

    private let headingSubject = PassthroughSubject<CLHeading, Never>()
    public var headingPublisher: AnyPublisher<CLHeading, Never> {
        headingSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    private override init() {
        super.init()
        setupLocationManager()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5.0 // Update every 5 meters

        #if os(iOS)
        locationManager.activityType = .fitness
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
        #endif

        // Get initial status
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Authorization

    /// Request location permission
    public func requestPermission() {
        logger.info("Requesting location permission")
        locationManager.requestAlwaysAuthorization()
    }

    /// Check if we have location permission
    public var hasPermission: Bool {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    // MARK: - Tracking Control

    /// Start tracking location
    public func startTracking() {
        guard hasPermission else {
            logger.warning("Cannot start tracking: no permission")
            requestPermission()
            return
        }

        guard !isTracking else { return }

        logger.info("Starting location tracking")
        locationManager.startUpdatingLocation()
        #if os(iOS)
        locationManager.startUpdatingHeading()
        #endif
        isTracking = true

        // Start broadcast timer
        startBroadcastTimer()
    }

    /// Stop tracking location
    public func stopTracking() {
        guard isTracking else { return }

        logger.info("Stopping location tracking")
        locationManager.stopUpdatingLocation()
        #if os(iOS)
        locationManager.stopUpdatingHeading()
        #endif
        isTracking = false

        // Stop broadcast timer
        stopBroadcastTimer()
    }

    /// Set broadcast interval in seconds
    public func setBroadcastInterval(_ seconds: Int) {
        broadcastInterval = TimeInterval(seconds)
        logger.info("Broadcast interval set to \(seconds) seconds")

        // Restart timer if tracking
        if isTracking {
            startBroadcastTimer()
        }
    }

    // MARK: - Breadcrumb Recording

    /// Start recording breadcrumbs
    public func startRecordingBreadcrumbs() {
        guard !isRecordingBreadcrumbs else { return }

        logger.info("Starting breadcrumb recording")
        isRecordingBreadcrumbs = true
        breadcrumbPoints = []
        runningDistanceMeters = 0
        recordingStartTime = Date()

        // Ensure we're tracking
        if !isTracking {
            startTracking()
        }
    }

    /// Stop recording breadcrumbs
    public func stopRecordingBreadcrumbs() -> BreadcrumbRoute? {
        guard isRecordingBreadcrumbs else { return nil }

        logger.info("Stopping breadcrumb recording with \(self.breadcrumbPoints.count) points")
        isRecordingBreadcrumbs = false

        guard breadcrumbPoints.count >= 2 else {
            logger.warning("Not enough points for breadcrumb route")
            return nil
        }

        let route = BreadcrumbRoute(
            id: UUID().uuidString,
            points: breadcrumbPoints,
            totalDistanceMeters: runningDistanceMeters,
            startTime: recordingStartTime ?? Date(),
            endTime: Date(),
            name: nil
        )

        // Clear recording state
        breadcrumbPoints = []
        runningDistanceMeters = 0
        recordingStartTime = nil

        return route
    }

    /// Add a point to the breadcrumb trail
    private func addBreadcrumbPoint(_ location: CLLocation) {
        let point = BreadcrumbPoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            timestamp: location.timestamp
        )

        // Calculate distance from last point
        if let lastPoint = breadcrumbPoints.last {
            let lastLocation = CLLocation(latitude: lastPoint.latitude, longitude: lastPoint.longitude)
            let distance = location.distance(from: lastLocation)
            runningDistanceMeters += distance
        }

        breadcrumbPoints.append(point)
    }

    // MARK: - Broadcast Timer

    private func startBroadcastTimer() {
        stopBroadcastTimer()

        broadcastTimer = Timer.scheduledTimer(withTimeInterval: broadcastInterval, repeats: true) { [weak self] _ in
            self?.broadcastPosition()
        }
    }

    private func stopBroadcastTimer() {
        broadcastTimer?.invalidate()
        broadcastTimer = nil
    }

    private func broadcastPosition() {
        guard let location = currentLocation else { return }

        // Get callsign from contacts
        let callsign = ContactsViewModel.shared.myProfile?.callsign ?? "Unknown"

        // Broadcast via transport coordinator
        TransportCoordinator.shared.publishPosition(
            callsign: callsign,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )

        lastBroadcastTime = Date()
        logger.debug("Broadcasted position: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }

    // MARK: - Computed Properties

    /// Current coordinate
    public var currentCoordinate: CLLocationCoordinate2D? {
        currentLocation?.coordinate
    }

    /// Current altitude in meters
    public var currentAltitude: Double? {
        currentLocation?.altitude
    }

    /// Current heading in degrees
    public var currentHeadingDegrees: Double? {
        currentHeading?.trueHeading
    }

    /// Current speed in m/s
    public var currentSpeed: Double? {
        guard let speed = currentLocation?.speed, speed >= 0 else { return nil }
        return speed
    }

    /// Horizontal accuracy in meters
    public var horizontalAccuracy: Double? {
        currentLocation?.horizontalAccuracy
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        logger.info("Authorization status changed: \(self.authorizationStatus.rawValue)")

        // Auto-start tracking if we just got permission
        if hasPermission && !isTracking {
            startTracking()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Filter out invalid locations
        guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 100 else {
            return
        }

        currentLocation = location
        locationSubject.send(location)

        // Update map view model
        MapViewModel.shared.updateMyPosition(location.coordinate, altitude: location.altitude)

        // Add to breadcrumbs if recording
        if isRecordingBreadcrumbs {
            addBreadcrumbPoint(location)
        }

        logger.debug("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }

        currentHeading = newHeading
        headingSubject.send(newHeading)

        // Update map view model
        MapViewModel.shared.updateDeviceHeading(newHeading.trueHeading)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Location error: \(error.localizedDescription)")
    }
}

// MARK: - Breadcrumb Models

/// A single point in a breadcrumb trail
public struct BreadcrumbPoint: Codable, Equatable {
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double
    public let timestamp: Date

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// A recorded breadcrumb route
public struct BreadcrumbRoute: Codable, Identifiable, Equatable {
    public let id: String
    public let points: [BreadcrumbPoint]
    public let totalDistanceMeters: Double
    public let startTime: Date
    public let endTime: Date
    public var name: String?
    public var isVisible: Bool = true

    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    public var durationString: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }

    public var distanceString: String {
        if totalDistanceMeters >= 1000 {
            return String(format: "%.2f km", totalDistanceMeters / 1000)
        }
        return String(format: "%.0f m", totalDistanceMeters)
    }
}

/// A planned route waypoint
public struct PlannedWaypoint: Codable, Identifiable, Equatable {
    public let id: String
    public let latitude: Double
    public let longitude: Double
    public var label: String?

    public init(id: String = UUID().uuidString, latitude: Double, longitude: Double, label: String? = nil) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.label = label
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// A planned route
public struct PlannedRoute: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public let waypoints: [PlannedWaypoint]
    public let createdAt: Date
    public var isVisible: Bool = true

    public var totalDistanceMeters: Double {
        var total = 0.0
        for i in 1..<waypoints.count {
            let from = CLLocation(latitude: waypoints[i-1].latitude, longitude: waypoints[i-1].longitude)
            let to = CLLocation(latitude: waypoints[i].latitude, longitude: waypoints[i].longitude)
            total += to.distance(from: from)
        }
        return total
    }

    public var distanceString: String {
        let meters = totalDistanceMeters
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }
}
