#if canImport(UIKit)
import UIKit
#endif
import Combine

// MARK: - Screen Brightness Manager

/// Manages screen brightness control
public final class ScreenBrightnessManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = ScreenBrightnessManager()

    // MARK: - Published State

    @Published public private(set) var brightness: Float = 1.0
    @Published public private(set) var originalBrightness: Float = 1.0

    // MARK: - Private

    private var hasStoredOriginal = false

    // MARK: - Init

    private init() {
        // Get current brightness
        #if canImport(UIKit) && os(iOS)
        brightness = Float(UIScreen.main.brightness)
        originalBrightness = brightness
        #endif
    }

    // MARK: - Public API

    /// Sets the screen brightness (0.0 to 1.0)
    public func setBrightness(_ level: Float) {
        let clampedLevel = max(0.01, min(1.0, level))

        #if canImport(UIKit) && os(iOS)
        // Store original brightness if not already stored
        if !hasStoredOriginal {
            originalBrightness = Float(UIScreen.main.brightness)
            hasStoredOriginal = true
        }

        UIScreen.main.brightness = CGFloat(clampedLevel)
        #endif
        brightness = clampedLevel
    }

    /// Restores the original brightness
    public func restoreOriginalBrightness() {
        #if canImport(UIKit) && os(iOS)
        if hasStoredOriginal {
            UIScreen.main.brightness = CGFloat(originalBrightness)
            brightness = originalBrightness
            hasStoredOriginal = false
        }
        #else
        brightness = originalBrightness
        hasStoredOriginal = false
        #endif
    }

    /// Quick brightness presets
    public func setPreset(_ preset: BrightnessPreset) {
        setBrightness(preset.level)
    }
}

// MARK: - Brightness Preset

public enum BrightnessPreset: String, CaseIterable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"

    public var level: Float {
        switch self {
        case .low: return 0.1
        case .medium: return 0.5
        case .high: return 1.0
        }
    }

    public var displayName: String {
        switch self {
        case .low: return "10%"
        case .medium: return "50%"
        case .high: return "100%"
        }
    }
}
