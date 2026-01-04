import SwiftUI
import MapKit

/// Main application entry point for sweTAK iOS
@main
public struct sweTAKApp: App {

    // MARK: - State

    @StateObject private var appState = AppState()
    @State private var showAboutScreen = false

    // MARK: - Body

    public var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .preferredColorScheme(colorScheme)
                .sheet(isPresented: $showAboutScreen) {
                    AboutScreen(showStartupCheckbox: true)
                }
                .onAppear {
                    // Show About screen at startup if not disabled
                    if AboutScreenHelper.shouldShowAtStartup {
                        showAboutScreen = true
                    }
                    // Apply saved transport settings before starting
                    let settings = SettingsViewModel.shared
                    if settings.transportMode == .mqtt && settings.mqttSettings.isValid {
                        // Apply MQTT configuration
                        let config = MQTTConfiguration(
                            host: settings.mqttSettings.host,
                            port: settings.mqttSettings.port,
                            useTLS: settings.mqttSettings.useTls,
                            username: settings.mqttSettings.username.isEmpty ? nil : settings.mqttSettings.username,
                            password: settings.mqttSettings.password.isEmpty ? nil : settings.mqttSettings.password
                        )
                        TransportCoordinator.shared.mqttConfiguration = config
                        TransportCoordinator.shared.setMode(.mqtt)
                    } else {
                        // Start with UDP (default)
                        TransportCoordinator.shared.start()
                    }

                    // Start listening for orders
                    OrdersViewModel.shared.startListening(deviceId: TransportCoordinator.shared.deviceId)
                }
        }
    }

    private var colorScheme: ColorScheme? {
        if SettingsViewModel.shared.settings.isDarkMode {
            return .dark
        }
        return nil
    }

    public init() {}
}

/// Global application state
public final class AppState: ObservableObject {

    // MARK: - Published Properties

    @Published public var isConnected: Bool = false
    @Published public var deviceId: String = ""

    // MARK: - Computed Properties

    var connectionStatusColor: Color {
        isConnected ? .green : .red
    }

    var connectionStatusText: String {
        isConnected ? "Connected" : "Disconnected"
    }

    // MARK: - Initialization

    public init() {
        setupBindings()
    }

    private func setupBindings() {
        // Observe transport coordinator state
        TransportCoordinator.shared.$connectionState
            .map { $0.isConnected }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isConnected)

        TransportCoordinator.shared.$deviceId
            .receive(on: DispatchQueue.main)
            .assign(to: &$deviceId)
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .environmentObject(AppState())
}
