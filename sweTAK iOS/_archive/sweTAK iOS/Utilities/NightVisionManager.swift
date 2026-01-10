import SwiftUI
import Combine

// MARK: - Night Vision Manager

/// Manages night vision mode with color overlay
/// Mirrors Android night vision functionality
public final class NightVisionManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = NightVisionManager()

    // MARK: - Published State

    /// Whether night vision mode is enabled
    @Published public var isEnabled: Bool = false

    /// Current night vision color
    @Published public var color: NightVisionColor = .green

    /// Overlay opacity (0.0 to 1.0)
    @Published public var opacity: Double = 0.7

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    private init() {
        // Load saved preferences
        loadPreferences()

        // Auto-save when values change
        $isEnabled
            .dropFirst()
            .sink { [weak self] _ in self?.savePreferences() }
            .store(in: &cancellables)

        $color
            .dropFirst()
            .sink { [weak self] _ in self?.savePreferences() }
            .store(in: &cancellables)

        $opacity
            .dropFirst()
            .sink { [weak self] _ in self?.savePreferences() }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Toggle night vision on/off
    public func toggle() {
        isEnabled.toggle()
    }

    /// Enable night vision
    public func enable() {
        isEnabled = true
    }

    /// Disable night vision
    public func disable() {
        isEnabled = false
    }

    /// Set night vision color
    public func setColor(_ newColor: NightVisionColor) {
        color = newColor
    }

    /// Set overlay opacity
    public func setOpacity(_ newOpacity: Double) {
        opacity = max(0.0, min(1.0, newOpacity))
    }

    /// Cycle through available colors
    public func cycleColor() {
        let allColors = NightVisionColor.allCases
        guard let currentIndex = allColors.firstIndex(of: color) else { return }
        let nextIndex = (currentIndex + 1) % allColors.count
        color = allColors[nextIndex]
    }

    // MARK: - Computed Properties

    /// Current overlay color with opacity applied
    public var overlayColor: Color {
        color.color.opacity(opacity)
    }

    /// Status text for UI display
    public var statusText: String {
        if isEnabled {
            return "Night Vision: \(color.displayName)"
        } else {
            return "Night Vision: Off"
        }
    }

    // MARK: - Persistence

    private let enabledKey = "night_vision_enabled"
    private let colorKey = "night_vision_color"
    private let opacityKey = "night_vision_opacity"

    private func loadPreferences() {
        let defaults = UserDefaults.standard

        isEnabled = defaults.bool(forKey: enabledKey)

        if let colorString = defaults.string(forKey: colorKey),
           let savedColor = NightVisionColor(rawValue: colorString) {
            color = savedColor
        }

        let savedOpacity = defaults.double(forKey: opacityKey)
        if savedOpacity > 0 {
            opacity = savedOpacity
        }
    }

    private func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(isEnabled, forKey: enabledKey)
        defaults.set(color.rawValue, forKey: colorKey)
        defaults.set(opacity, forKey: opacityKey)
    }
}

// MARK: - Night Vision Overlay View

/// Full-screen night vision color overlay
public struct NightVisionOverlayView: View {
    @ObservedObject private var manager = NightVisionManager.shared

    public init() {}

    public var body: some View {
        if manager.isEnabled {
            manager.overlayColor
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.3), value: manager.isEnabled)
                .animation(.easeInOut(duration: 0.3), value: manager.color)
        }
    }
}

// MARK: - Night Vision Control View

/// Compact control for toggling night vision
public struct NightVisionControl: View {
    @ObservedObject private var manager = NightVisionManager.shared
    @State private var showColorPicker = false

    public init() {}

    public var body: some View {
        HStack(spacing: 12) {
            // Toggle button
            Button {
                manager.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: manager.isEnabled ? "eye.fill" : "eye.slash")
                        .font(.title3)

                    Text("Night Vision")
                        .font(.subheadline)
                }
                .foregroundColor(manager.isEnabled ? manager.color.color : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(manager.isEnabled ? manager.color.color.opacity(0.2) : Color(.systemGray6))
                )
            }
            .buttonStyle(.plain)

            // Color picker (only when enabled)
            if manager.isEnabled {
                Button {
                    showColorPicker = true
                } label: {
                    Circle()
                        .fill(manager.color.color)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showColorPicker) {
            NightVisionColorPicker()
        }
    }
}

// MARK: - Night Vision Color Picker

/// Color picker sheet for night vision
public struct NightVisionColorPicker: View {
    @ObservedObject private var manager = NightVisionManager.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // Color selection
                Section("Color") {
                    ForEach(NightVisionColor.allCases, id: \.self) { color in
                        Button {
                            manager.setColor(color)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 24, height: 24)

                                Text(color.displayName)
                                    .foregroundColor(.primary)

                                Spacer()

                                if manager.color == color {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }

                // Opacity slider
                Section("Intensity") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Opacity")
                            Spacer()
                            Text("\(Int(manager.opacity * 100))%")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $manager.opacity, in: 0.3...0.9, step: 0.1)
                            .accentColor(manager.color.color)
                    }
                    .padding(.vertical, 4)
                }

                // Preview
                Section("Preview") {
                    ZStack {
                        // Sample content
                        VStack(spacing: 8) {
                            Image(systemName: "map.fill")
                                .font(.largeTitle)
                            Text("Map Preview")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(Color.black)

                        // Night vision overlay
                        manager.overlayColor
                    }
                    .cornerRadius(12)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            .navigationTitle("Night Vision")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Night Vision Menu Row

/// Menu row for night vision settings
public struct NightVisionMenuRow: View {
    @ObservedObject private var manager = NightVisionManager.shared
    let onTap: () -> Void

    public init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: "eye.fill")
                    .font(.title3)
                    .foregroundColor(manager.isEnabled ? manager.color.color : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Night Vision")
                        .foregroundColor(.primary)

                    Text(manager.statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $manager.isEnabled)
                    .labelsHidden()
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Night Vision Control") {
    VStack(spacing: 20) {
        NightVisionControl()

        Divider()

        NightVisionMenuRow {
            print("Tapped")
        }
    }
    .padding()
}

#Preview("Night Vision Overlay") {
    ZStack {
        Color.black
            .ignoresSafeArea()

        VStack {
            Text("Map Content")
                .foregroundColor(.white)
        }

        NightVisionOverlayView()
    }
    .onAppear {
        NightVisionManager.shared.isEnabled = true
    }
}
