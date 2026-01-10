import Foundation
import Combine
import CoreLocation
import MapKit
import os.log

/// Camera state for map persistence
public struct CameraState: Codable, Equatable {
    public var latitude: Double
    public var longitude: Double
    public var zoom: Double
    public var bearing: Double

    public init(latitude: Double = 0, longitude: Double = 0, zoom: Double = 14.0, bearing: Double = 0) {
        self.latitude = latitude
        self.longitude = longitude
        self.zoom = zoom
        self.bearing = bearing
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Map orientation modes
public enum MapOrientationMode: String, Codable, CaseIterable {
    case northUp = "NORTH_UP"
    case freeRotate = "FREE_ROTATE"
    case headingUp = "HEADING_UP"

    public var displayName: String {
        switch self {
        case .northUp: return "North Up"
        case .freeRotate: return "Free Rotate"
        case .headingUp: return "Heading Up"
        }
    }
}

/// ViewModel for managing map state
/// Mirrors Android MapStateViewModel functionality
public final class MapViewModel: ObservableObject {

    // MARK: - Singleton

    public static let shared = MapViewModel()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "MapViewModel")

    // MARK: - User Position State

    @Published public private(set) var myPosition: CLLocationCoordinate2D?
    @Published public private(set) var myAltitudeMeters: Double?

    // MARK: - Camera State

    @Published public private(set) var cameraPosition: CameraState?
    @Published public private(set) var zoom: Double = 14.0
    @Published public private(set) var mapBearing: Double = 0.0

    // MARK: - Follow Mode State

    @Published public private(set) var followMe: Bool = true  // Start in follow mode by default
    @Published public private(set) var hasCenteredInitially: Bool = false

    // MARK: - Device Heading

    @Published public private(set) var deviceHeading: Double = 0.0

    // MARK: - Crosshair State

    @Published public private(set) var crosshairPosition: CLLocationCoordinate2D?
    @Published public private(set) var crosshairAltitudeMeters: Double?

    // MARK: - Map Orientation

    @Published public private(set) var mapOrientation: MapOrientationMode = .freeRotate

    // MARK: - Peer Positions

    @Published public private(set) var peerPositions: [String: PeerPosition] = [:]

    // MARK: - Camera Region Binding

    /// MKCoordinateRegion for SwiftUI Map binding
    public var cameraRegion: MKCoordinateRegion {
        get {
            if let pos = cameraPosition {
                return MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: pos.latitude, longitude: pos.longitude),
                    span: MKCoordinateSpan(latitudeDelta: spanFromZoom(pos.zoom), longitudeDelta: spanFromZoom(pos.zoom))
                )
            }
            // Default to Stockholm
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
        set {
            saveCameraPosition(
                lat: newValue.center.latitude,
                lng: newValue.center.longitude,
                zoom: zoomFromSpan(newValue.span),
                bearing: mapBearing
            )
        }
    }

    private func spanFromZoom(_ zoom: Double) -> Double {
        // Approximate span from zoom level
        return 360.0 / pow(2, zoom) / 111.0
    }

    private func zoomFromSpan(_ span: MKCoordinateSpan) -> Double {
        let maxSpan = max(span.latitudeDelta, span.longitudeDelta)
        return max(1, 20 - log2(maxSpan * 111))
    }

    /// Reset bearing to north-up
    public func resetBearing() {
        mapBearing = 0
        if let pos = cameraPosition {
            saveCameraPosition(lat: pos.latitude, lng: pos.longitude, zoom: pos.zoom, bearing: 0)
        }
    }

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let cameraLat = "map_camera_lat"
        static let cameraLng = "map_camera_lng"
        static let cameraZoom = "map_camera_zoom"
        static let cameraBearing = "map_camera_bearing"
        static let mapOrientation = "map_orientation"
    }

    // MARK: - Initialization

    private init() {
        loadSavedCameraPosition()
        loadSavedOrientation()
        setupListeners()
    }

    // MARK: - Listeners

    private func setupListeners() {
        // Register as position listener
        TransportCoordinator.shared.positionListener = self
    }

    // MARK: - Position Updates

    /// Update the user's current position
    public func updateMyPosition(_ coordinate: CLLocationCoordinate2D?, altitude: Double? = nil) {
        myPosition = coordinate
        if let alt = altitude {
            myAltitudeMeters = alt
        }
        logger.debug("Updated position: \(String(describing: coordinate)), altitude: \(String(describing: altitude))")
    }

    /// Update the user's altitude separately
    public func updateMyAltitude(_ altitude: Double?) {
        myAltitudeMeters = altitude
    }

    // MARK: - Camera Updates

    /// Save the current camera position for restoration
    public func saveCameraPosition(lat: Double, lng: Double, zoom: Double, bearing: Double = 0.0) {
        cameraPosition = CameraState(latitude: lat, longitude: lng, zoom: zoom, bearing: bearing)
        self.zoom = zoom
        self.mapBearing = bearing

        // Persist to UserDefaults
        UserDefaults.standard.set(lat, forKey: Keys.cameraLat)
        UserDefaults.standard.set(lng, forKey: Keys.cameraLng)
        UserDefaults.standard.set(zoom, forKey: Keys.cameraZoom)
        UserDefaults.standard.set(bearing, forKey: Keys.cameraBearing)

        logger.debug("Saved camera: lat=\(lat), lng=\(lng), zoom=\(zoom), bearing=\(bearing)")
    }

    /// Update just the zoom level
    public func updateZoom(_ zoom: Double) {
        self.zoom = zoom
    }

    /// Zoom in by one level
    public func zoomIn() {
        let newZoom = min(zoom + 1, 20.0)
        let region = cameraRegion
        saveCameraPosition(lat: region.center.latitude, lng: region.center.longitude, zoom: newZoom, bearing: mapBearing)
    }

    /// Zoom out by one level
    public func zoomOut() {
        let newZoom = max(zoom - 1, 1.0)
        let region = cameraRegion
        saveCameraPosition(lat: region.center.latitude, lng: region.center.longitude, zoom: newZoom, bearing: mapBearing)
    }

    /// Update the map bearing/rotation
    public func updateMapBearing(_ bearing: Double) {
        self.mapBearing = bearing
    }

    /// Get the saved camera position
    public func getSavedCameraPosition() -> CameraState? {
        cameraPosition
    }

    /// Clear saved camera position
    public func clearSavedCameraPosition() {
        cameraPosition = nil
        UserDefaults.standard.removeObject(forKey: Keys.cameraLat)
        UserDefaults.standard.removeObject(forKey: Keys.cameraLng)
        UserDefaults.standard.removeObject(forKey: Keys.cameraZoom)
        UserDefaults.standard.removeObject(forKey: Keys.cameraBearing)
    }

    private func loadSavedCameraPosition() {
        let lat = UserDefaults.standard.double(forKey: Keys.cameraLat)
        let lng = UserDefaults.standard.double(forKey: Keys.cameraLng)
        let zoom = UserDefaults.standard.double(forKey: Keys.cameraZoom)
        let bearing = UserDefaults.standard.double(forKey: Keys.cameraBearing)

        // Check if valid values exist
        if lat != 0 || lng != 0 {
            cameraPosition = CameraState(latitude: lat, longitude: lng, zoom: zoom > 0 ? zoom : 14.0, bearing: bearing)
            self.zoom = zoom > 0 ? zoom : 14.0
            self.mapBearing = bearing
            logger.debug("Loaded saved camera: lat=\(lat), lng=\(lng), zoom=\(zoom)")
        }
    }

    // MARK: - Follow Mode

    /// Toggle follow mode on/off
    public func toggleFollowMe() {
        followMe.toggle()
        logger.debug("Follow mode toggled: \(self.followMe)")
    }

    /// Set follow mode directly
    public func setFollowMe(_ enabled: Bool) {
        followMe = enabled
    }

    /// Mark that we've done the initial centering
    public func markInitiallyCentered() {
        hasCenteredInitially = true
    }

    /// Reset the initial centering flag
    public func resetInitialCentering() {
        hasCenteredInitially = false
    }

    /// Center map on a location with specified span
    public func centerOnLocation(_ coordinate: CLLocationCoordinate2D, spanDegrees: Double) {
        let zoom = zoomFromSpan(MKCoordinateSpan(latitudeDelta: spanDegrees, longitudeDelta: spanDegrees))
        saveCameraPosition(lat: coordinate.latitude, lng: coordinate.longitude, zoom: zoom, bearing: mapBearing)
        hasCenteredInitially = true
        logger.info("Centered on location: \(coordinate.latitude), \(coordinate.longitude) with span \(spanDegrees)°")
    }

    // MARK: - Device Heading

    /// Update the device compass heading
    public func updateDeviceHeading(_ heading: Double) {
        deviceHeading = heading
    }

    // MARK: - Crosshair

    /// Update the crosshair position
    public func updateCrosshairPosition(_ coordinate: CLLocationCoordinate2D?) {
        crosshairPosition = coordinate
    }

    /// Update the crosshair altitude
    public func updateCrosshairAltitude(_ altitude: Double?) {
        crosshairAltitudeMeters = altitude
    }

    // MARK: - Map Orientation

    /// Set map orientation mode
    public func setMapOrientation(_ mode: MapOrientationMode) {
        mapOrientation = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Keys.mapOrientation)
    }

    private func loadSavedOrientation() {
        if let savedMode = UserDefaults.standard.string(forKey: Keys.mapOrientation),
           let mode = MapOrientationMode(rawValue: savedMode) {
            mapOrientation = mode
        }
    }

    // MARK: - Peer Positions

    /// Update a peer's position
    public func updatePeerPosition(deviceId: String, callsign: String, latitude: Double, longitude: Double) {
        let position = PeerPosition(
            deviceId: deviceId,
            callsign: callsign,
            latitude: latitude,
            longitude: longitude,
            lastUpdated: Date()
        )
        peerPositions[deviceId] = position
    }

    /// Remove a peer's position
    public func removePeerPosition(deviceId: String) {
        peerPositions.removeValue(forKey: deviceId)
    }

    /// Remove stale peer positions (older than specified interval)
    public func removeStalePositions(olderThan interval: TimeInterval = 300) {
        let cutoff = Date().addingTimeInterval(-interval)
        peerPositions = peerPositions.filter { $0.value.lastUpdated > cutoff }
    }
}

// MARK: - Peer Position Model

public struct PeerPosition: Identifiable, Equatable {
    public let id: String
    public let deviceId: String
    public let callsign: String
    public let latitude: Double
    public let longitude: Double
    public let lastUpdated: Date

    public init(deviceId: String, callsign: String, latitude: Double, longitude: Double, lastUpdated: Date = Date()) {
        self.id = deviceId
        self.deviceId = deviceId
        self.callsign = callsign
        self.latitude = latitude
        self.longitude = longitude
        self.lastUpdated = lastUpdated
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - PositionListener

extension MapViewModel: PositionListener {
    public func onPositionReceived(deviceId: String, callsign: String, latitude: Double, longitude: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.updatePeerPosition(deviceId: deviceId, callsign: callsign, latitude: latitude, longitude: longitude)
        }
    }
}
