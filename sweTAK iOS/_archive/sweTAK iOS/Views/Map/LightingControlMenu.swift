import SwiftUI

// MARK: - Lighting Control Menu Level

/// Navigation level for lighting control menu
public enum LightingMenuLevel: String, Codable {
    case root = "ROOT"
    case nightVision = "NIGHT_VISION"
    case torch = "TORCH"
    case screen = "SCREEN"
}

// MARK: - Lighting Control Menu

/// Lighting control menu providing access to night vision, torch, and screen brightness controls
public struct LightingControlMenu: View {
    @Binding var isPresented: Bool

    // Theme/Night Vision
    @Binding var themeMode: ThemeMode
    @Binding var previousThemeMode: ThemeMode
    @Binding var nightDimmerAlpha: Float
    @Binding var nightVisionColor: NightVisionColor

    // Torch
    @ObservedObject private var torchManager = TorchManager.shared

    // Screen brightness
    @ObservedObject private var brightnessManager = ScreenBrightnessManager.shared

    @State private var menuLevel: LightingMenuLevel = .root

    public init(
        isPresented: Binding<Bool>,
        themeMode: Binding<ThemeMode>,
        previousThemeMode: Binding<ThemeMode>,
        nightDimmerAlpha: Binding<Float>,
        nightVisionColor: Binding<NightVisionColor>
    ) {
        self._isPresented = isPresented
        self._themeMode = themeMode
        self._previousThemeMode = previousThemeMode
        self._nightDimmerAlpha = nightDimmerAlpha
        self._nightVisionColor = nightVisionColor
    }

    public var body: some View {
        NavigationStack {
            List {
                switch menuLevel {
                case .root:
                    rootSection
                case .nightVision:
                    nightVisionSection
                case .torch:
                    torchSection
                case .screen:
                    screenSection
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if menuLevel != .root {
                        Button {
                            menuLevel = .root
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }

    // MARK: - Navigation

    private var navigationTitle: String {
        switch menuLevel {
        case .root: return "Lighting"
        case .nightVision: return "Night Vision"
        case .torch: return "Torch"
        case .screen: return "Screen Brightness"
        }
    }

    // MARK: - Root Section

    @ViewBuilder
    private var rootSection: some View {
        Section {
            // Night Vision
            LightingMenuRow(
                icon: "moon.fill",
                title: "Night Vision",
                subtitle: themeMode == .nightVision ? "Enabled" : "Disabled",
                color: themeMode == .nightVision ? nightVisionColor.color : .secondary,
                hasSubmenu: true
            ) {
                menuLevel = .nightVision
            }

            // Torch
            if torchManager.hasTorch {
                LightingMenuRow(
                    icon: torchManager.isEnabled ? "flashlight.on.fill" : "flashlight.off.fill",
                    title: "Torch",
                    subtitle: torchManager.isEnabled ? "On" : "Off",
                    color: torchManager.isEnabled ? .yellow : .secondary,
                    hasSubmenu: true
                ) {
                    menuLevel = .torch
                }
            }

            // Screen Brightness
            LightingMenuRow(
                icon: "sun.max.fill",
                title: "Screen Brightness",
                subtitle: "\(Int(brightnessManager.brightness * 100))%",
                color: brightnessManager.brightness < 0.5 ? .orange : .secondary,
                hasSubmenu: true
            ) {
                menuLevel = .screen
            }
        }
    }

    // MARK: - Night Vision Section

    @ViewBuilder
    private var nightVisionSection: some View {
        Section {
            // Enable/Disable toggle
            Toggle(isOn: Binding(
                get: { themeMode == .nightVision },
                set: { enabled in
                    if enabled {
                        previousThemeMode = themeMode
                        themeMode = .nightVision
                    } else {
                        themeMode = previousThemeMode
                    }
                }
            )) {
                Label("Enabled", systemImage: "moon.fill")
            }
            .tint(nightVisionColor.color)
        }

        Section("Color") {
            ForEach(NightVisionColor.allCases, id: \.self) { color in
                Button {
                    nightVisionColor = color
                } label: {
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.color)
                            .frame(width: 24, height: 24)

                        Text(color.displayName)
                            .foregroundColor(.primary)

                        Spacer()

                        if nightVisionColor == color {
                            Image(systemName: "checkmark")
                                .foregroundColor(color.color)
                        }
                    }
                }
            }
        }

        Section("Intensity") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Dimmer")
                    Spacer()
                    Text("\(Int(nightDimmerAlpha * 100))%")
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { Double(nightDimmerAlpha) },
                        set: { nightDimmerAlpha = Float($0) }
                    ),
                    in: 0.10...0.90
                )
                .tint(nightVisionColor.color)

                // Preview bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(nightVisionColor.color.opacity(Double(nightDimmerAlpha)))
                    .frame(height: 12)
            }
        }
    }

    // MARK: - Torch Section

    @ViewBuilder
    private var torchSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { torchManager.isEnabled },
                set: { torchManager.setEnabled($0) }
            )) {
                Label(
                    torchManager.isEnabled ? "On" : "Off",
                    systemImage: torchManager.isEnabled ? "flashlight.on.fill" : "flashlight.off.fill"
                )
            }
            .tint(.yellow)
        }

        if torchManager.supportsTorchIntensity {
            Section("Intensity") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Brightness")
                        Spacer()
                        Text("\(Int(torchManager.intensity * 100))%")
                            .foregroundColor(.secondary)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(torchManager.intensity) },
                            set: { torchManager.setIntensity(Float($0)) }
                        ),
                        in: 0.1...1.0
                    )
                    .tint(.yellow)
                    .disabled(!torchManager.isEnabled)
                }
            }
        } else {
            Section {
                Text("Intensity control not supported on this device")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Screen Section

    @ViewBuilder
    private var screenSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Brightness")
                    Spacer()
                    Text("\(Int(brightnessManager.brightness * 100))%")
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { Double(brightnessManager.brightness) },
                        set: { brightnessManager.setBrightness(Float($0)) }
                    ),
                    in: 0.01...1.0
                )
                .tint(.orange)
            }
        }

        Section("Quick Settings") {
            HStack(spacing: 16) {
                ForEach(BrightnessPreset.allCases, id: \.self) { preset in
                    Button {
                        brightnessManager.setPreset(preset)
                    } label: {
                        Text(preset.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.orange)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }

        Section {
            Button {
                brightnessManager.restoreOriginalBrightness()
            } label: {
                Label("Restore Original Brightness", systemImage: "arrow.uturn.backward")
            }
        }
    }
}

// MARK: - Lighting Menu Row

private struct LightingMenuRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var hasSubmenu: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if hasSubmenu {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Lighting Control Button

/// Compact button that opens the lighting control menu
public struct LightingControlButton: View {
    @Binding var showMenu: Bool

    let themeMode: ThemeMode
    let torchEnabled: Bool
    let screenBrightness: Float
    let nightVisionColor: NightVisionColor

    public init(
        showMenu: Binding<Bool>,
        themeMode: ThemeMode,
        torchEnabled: Bool = false,
        screenBrightness: Float = 1.0,
        nightVisionColor: NightVisionColor = .red
    ) {
        self._showMenu = showMenu
        self.themeMode = themeMode
        self.torchEnabled = torchEnabled
        self.screenBrightness = screenBrightness
        self.nightVisionColor = nightVisionColor
    }

    public var body: some View {
        Button {
            showMenu = true
        } label: {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(.regularMaterial)
                .clipShape(Circle())
                .shadow(radius: 2)
        }
    }

    private var iconName: String {
        if torchEnabled {
            return "flashlight.on.fill"
        } else if themeMode == .nightVision {
            return "moon.fill"
        } else {
            return "sun.max.fill"
        }
    }

    private var iconColor: Color {
        if torchEnabled {
            return .yellow
        } else if themeMode == .nightVision {
            return nightVisionColor.color
        } else if screenBrightness < 0.5 {
            return .orange
        } else {
            return .primary
        }
    }
}

// MARK: - Night Vision Overlay

/// Full-screen overlay for night vision mode
public struct NightVisionOverlay: View {
    let color: NightVisionColor
    let alpha: Float

    public init(color: NightVisionColor, alpha: Float) {
        self.color = color
        self.alpha = alpha
    }

    public var body: some View {
        color.color
            .opacity(Double(alpha))
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

// MARK: - Previews

#Preview("Lighting Control Menu") {
    LightingControlMenu(
        isPresented: .constant(true),
        themeMode: .constant(.dark),
        previousThemeMode: .constant(.dark),
        nightDimmerAlpha: .constant(0.5),
        nightVisionColor: .constant(.red)
    )
}

#Preview("Lighting Button") {
    VStack(spacing: 20) {
        LightingControlButton(
            showMenu: .constant(false),
            themeMode: .dark
        )

        LightingControlButton(
            showMenu: .constant(false),
            themeMode: .nightVision,
            nightVisionColor: .red
        )

        LightingControlButton(
            showMenu: .constant(false),
            themeMode: .dark,
            torchEnabled: true
        )
    }
    .padding()
}

#Preview("Night Vision Overlay") {
    ZStack {
        Color.black
        Text("Map Content")
            .foregroundColor(.white)
        NightVisionOverlay(color: .red, alpha: 0.5)
    }
}
