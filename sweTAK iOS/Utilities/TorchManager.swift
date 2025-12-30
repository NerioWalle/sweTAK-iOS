import AVFoundation
import Combine

// MARK: - Torch Manager

/// Manages the device's flashlight/torch functionality
public final class TorchManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = TorchManager()

    // MARK: - Published State

    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var intensity: Float = 1.0
    @Published public private(set) var supportsTorchIntensity: Bool = false

    // MARK: - Private

    private var device: AVCaptureDevice?

    // MARK: - Init

    private init() {
        setupDevice()
    }

    // MARK: - Setup

    private func setupDevice() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            return
        }
        self.device = device

        // Check if device has torch
        guard device.hasTorch else {
            return
        }

        // Check if variable intensity is supported
        supportsTorchIntensity = device.isTorchModeSupported(.on) && device.maxAvailableTorchLevel > 0
    }

    // MARK: - Public API

    /// Returns true if the device has a torch/flashlight
    public var hasTorch: Bool {
        device?.hasTorch ?? false
    }

    /// Toggles the torch on or off
    public func toggle() {
        setEnabled(!isEnabled)
    }

    /// Sets the torch enabled state
    public func setEnabled(_ enabled: Bool) {
        guard let device = device, device.hasTorch else {
            return
        }

        do {
            try device.lockForConfiguration()

            if enabled {
                if supportsTorchIntensity {
                    try device.setTorchModeOn(level: intensity)
                } else {
                    device.torchMode = .on
                }
            } else {
                device.torchMode = .off
            }

            device.unlockForConfiguration()
            isEnabled = enabled
        } catch {
            print("TorchManager: Failed to set torch: \(error)")
        }
    }

    /// Sets the torch intensity (0.0 to 1.0)
    public func setIntensity(_ level: Float) {
        let clampedLevel = max(0.01, min(1.0, level))
        intensity = clampedLevel

        guard let device = device, device.hasTorch, isEnabled else {
            return
        }

        do {
            try device.lockForConfiguration()

            if supportsTorchIntensity {
                try device.setTorchModeOn(level: clampedLevel)
            }

            device.unlockForConfiguration()
        } catch {
            print("TorchManager: Failed to set intensity: \(error)")
        }
    }

    /// Turns off the torch
    public func turnOff() {
        setEnabled(false)
    }
}
