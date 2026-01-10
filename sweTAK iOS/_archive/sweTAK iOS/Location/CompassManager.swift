import Foundation
import CoreLocation
import CoreMotion
import Combine

// Note: MapOrientationMode is defined in MapViewModel.swift

// MARK: - Compass Manager

/// Manages device compass/heading and motion data
/// Mirrors Android sensor integration for map orientation
public final class CompassManager: NSObject, ObservableObject {

    // MARK: - Singleton

    public static let shared = CompassManager()

    // MARK: - Published State

    /// Current magnetic heading in degrees (0-360, 0 = magnetic north)
    @Published public private(set) var magneticHeading: Double = 0

    /// Current true heading in degrees (0-360, 0 = true north)
    @Published public private(set) var trueHeading: Double = 0

    /// Heading accuracy in degrees (negative if invalid)
    @Published public private(set) var headingAccuracy: Double = -1

    /// Device pitch (rotation around x-axis) in radians
    @Published public private(set) var pitch: Double = 0

    /// Device roll (rotation around y-axis) in radians
    @Published public private(set) var roll: Double = 0

    /// Device yaw (rotation around z-axis) in radians
    @Published public private(set) var yaw: Double = 0

    /// Current orientation mode
    @Published public var orientationMode: MapOrientationMode = .northUp

    /// Whether heading updates are active
    @Published public private(set) var isHeadingActive: Bool = false

    /// Whether motion updates are active
    @Published public private(set) var isMotionActive: Bool = false

    // MARK: - Callbacks

    /// Called when heading updates are received
    public var onHeadingUpdate: ((Double) -> Void)?

    /// Called when device motion updates are received
    public var onMotionUpdate: ((Double, Double, Double) -> Void)?

    // MARK: - Private Properties

    private let locationManager: CLLocationManager
    private let motionManager: CMMotionManager
    private let operationQueue: OperationQueue

    // MARK: - Computed Properties

    /// Check if heading is available on this device
    public var isHeadingAvailable: Bool {
        CLLocationManager.headingAvailable()
    }

    /// Check if device motion is available
    public var isMotionAvailable: Bool {
        motionManager.isDeviceMotionAvailable
    }

    /// Get the heading to use for map rotation based on orientation mode
    public var mapRotation: Double {
        switch orientationMode {
        case .northUp:
            return 0
        case .freeRotate:
            return 0 // User controls rotation
        case .headingUp:
            return -trueHeading // Rotate map opposite to heading
        }
    }

    /// Cardinal direction string for current heading
    public var cardinalDirection: String {
        bearingToCardinal(trueHeading)
    }

    // MARK: - Init

    private override init() {
        locationManager = CLLocationManager()
        motionManager = CMMotionManager()
        operationQueue = OperationQueue()
        operationQueue.name = "CompassManager"
        operationQueue.maxConcurrentOperationCount = 1

        super.init()

        locationManager.delegate = self
        locationManager.headingFilter = 1 // Update for every 1 degree change

        // Configure motion manager
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0 // 30 Hz
    }

    // MARK: - Heading Control

    /// Start receiving heading updates
    public func startHeadingUpdates() {
        guard isHeadingAvailable else {
            print("[Compass] Heading not available on this device")
            return
        }

        guard !isHeadingActive else { return }

        locationManager.startUpdatingHeading()
        isHeadingActive = true
        print("[Compass] Heading updates started")
    }

    /// Stop receiving heading updates
    public func stopHeadingUpdates() {
        guard isHeadingActive else { return }

        locationManager.stopUpdatingHeading()
        isHeadingActive = false
        print("[Compass] Heading updates stopped")
    }

    // MARK: - Motion Control

    /// Start receiving device motion updates
    public func startMotionUpdates() {
        guard isMotionAvailable else {
            print("[Compass] Device motion not available")
            return
        }

        guard !isMotionActive else { return }

        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: operationQueue
        ) { [weak self] motion, error in
            guard let self = self, let motion = motion else {
                if let error = error {
                    print("[Compass] Motion error: \(error.localizedDescription)")
                }
                return
            }

            DispatchQueue.main.async {
                self.pitch = motion.attitude.pitch
                self.roll = motion.attitude.roll
                self.yaw = motion.attitude.yaw

                self.onMotionUpdate?(self.pitch, self.roll, self.yaw)
            }
        }

        isMotionActive = true
        print("[Compass] Motion updates started")
    }

    /// Stop receiving device motion updates
    public func stopMotionUpdates() {
        guard isMotionActive else { return }

        motionManager.stopDeviceMotionUpdates()
        isMotionActive = false
        print("[Compass] Motion updates stopped")
    }

    /// Start all sensor updates
    public func startAllUpdates() {
        startHeadingUpdates()
        startMotionUpdates()
    }

    /// Stop all sensor updates
    public func stopAllUpdates() {
        stopHeadingUpdates()
        stopMotionUpdates()
    }

    // MARK: - Calibration

    /// Dismiss heading calibration display
    public func dismissCalibration() {
        // iOS will show calibration UI automatically when needed
        // This is here for API compatibility
    }

    // MARK: - Bearing Utilities

    /// Convert bearing in degrees to cardinal direction
    public func bearingToCardinal(_ bearing: Double) -> String {
        let normalized = ((bearing.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)

        switch normalized {
        case 0..<22.5, 337.5..<360:
            return "N"
        case 22.5..<67.5:
            return "NE"
        case 67.5..<112.5:
            return "E"
        case 112.5..<157.5:
            return "SE"
        case 157.5..<202.5:
            return "S"
        case 202.5..<247.5:
            return "SW"
        case 247.5..<292.5:
            return "W"
        case 292.5..<337.5:
            return "NW"
        default:
            return "N"
        }
    }

    /// Format heading as degrees with cardinal direction
    public func formatHeading(_ heading: Double) -> String {
        let rounded = Int(heading.rounded())
        let cardinal = bearingToCardinal(heading)
        return "\(rounded)° \(cardinal)"
    }

    /// Calculate bearing from current location to a target
    public func bearingTo(_ target: CLLocationCoordinate2D, from current: CLLocationCoordinate2D) -> Double {
        let lat1Rad = current.latitude * .pi / 180
        let lat2Rad = target.latitude * .pi / 180
        let deltaLon = (target.longitude - current.longitude) * .pi / 180

        let y = sin(deltaLon) * cos(lat2Rad)
        let x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(deltaLon)

        let bearingRad = atan2(y, x)
        let bearingDeg = bearingRad * 180 / .pi

        return (bearingDeg + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Get relative bearing (how much to turn from current heading to face target)
    public func relativeBearingTo(_ target: CLLocationCoordinate2D, from current: CLLocationCoordinate2D) -> Double {
        let absoluteBearing = bearingTo(target, from: current)
        var relative = absoluteBearing - trueHeading

        // Normalize to -180 to 180
        while relative > 180 { relative -= 360 }
        while relative < -180 { relative += 360 }

        return relative
    }
}

// MARK: - CLLocationManagerDelegate

extension CompassManager: CLLocationManagerDelegate {

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        magneticHeading = newHeading.magneticHeading
        headingAccuracy = newHeading.headingAccuracy

        if newHeading.headingAccuracy >= 0 {
            trueHeading = newHeading.trueHeading
        } else {
            // True heading not available, use magnetic
            trueHeading = newHeading.magneticHeading
        }

        onHeadingUpdate?(trueHeading)
    }

    public func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        // Return true to show iOS calibration UI when accuracy is low
        return headingAccuracy < 0 || headingAccuracy > 25
    }
}

// MARK: - Compass Rose View Data

extension CompassManager {

    /// Get compass rose tick marks for UI rendering
    public func compassTicks(count: Int = 36) -> [(angle: Double, isCardinal: Bool, label: String?)] {
        let step = 360.0 / Double(count)
        var ticks: [(angle: Double, isCardinal: Bool, label: String?)] = []

        for i in 0..<count {
            let angle = Double(i) * step
            let isCardinal = i % (count / 4) == 0
            let isIntercardinal = i % (count / 8) == 0 && !isCardinal

            var label: String? = nil
            if isCardinal {
                switch i {
                case 0: label = "N"
                case count / 4: label = "E"
                case count / 2: label = "S"
                case 3 * count / 4: label = "W"
                default: break
                }
            } else if isIntercardinal {
                switch i {
                case count / 8: label = "NE"
                case 3 * count / 8: label = "SE"
                case 5 * count / 8: label = "SW"
                case 7 * count / 8: label = "NW"
                default: break
                }
            }

            ticks.append((angle: angle, isCardinal: isCardinal || isIntercardinal, label: label))
        }

        return ticks
    }
}
