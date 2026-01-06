import SwiftUI

/// Settings screen for configuring app preferences
/// Mirrors Android SettingsScreen functionality
public struct SettingsScreen: View {
    @ObservedObject private var settingsVM = SettingsViewModel.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetAlert = false
    @State private var showingAdvancedMqtt = false

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                // Appearance section
                appearanceSection

                // Map settings section
                mapSection

                // Measurement section
                measurementSection

                // Transport section
                transportSection

                // MQTT section - always visible so users can configure
                mqttSection

                // Advanced MQTT (collapsible)
                if showingAdvancedMqtt {
                    advancedMqttSection
                }

                // GPS section
                gpsSection

                // Security section
                securitySection

                // Data section
                dataSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Reset All Settings?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    SettingsDataStore.shared.resetAll()
                    RefreshBus.shared.emitSettingsChanged()
                }
            } message: {
                Text("This will reset all settings to their default values. This cannot be undone.")
            }
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section("Appearance") {
            Toggle("Dark Mode", isOn: Binding(
                get: { settingsVM.settings.isDarkMode },
                set: { settingsVM.setDarkMode($0) }
            ))
        }
    }

    // MARK: - Map Section

    @State private var mapTilerApiKey: String = ""

    private var mapSection: some View {
        Section("Map") {
            // Map style picker - using full MapStyle enum
            Picker("Map Style", selection: Binding(
                get: { settingsVM.currentMapStyle },
                set: { settingsVM.setFullMapStyle($0) }
            )) {
                ForEach(MapStyle.allCases, id: \.self) { style in
                    Label(style.displayName, systemImage: style.icon).tag(style)
                }
            }

            // Map orientation picker
            Picker("Orientation", selection: Binding(
                get: { settingsVM.settings.mapOrientation },
                set: { settingsVM.setMapOrientation($0) }
            )) {
                ForEach(MapOrientationMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            // Breadcrumb color
            NavigationLink {
                BreadcrumbColorPicker()
            } label: {
                HStack {
                    Text("Breadcrumb Color")
                    Spacer()
                    Circle()
                        .fill(settingsVM.breadcrumbColor)
                        .frame(width: 24, height: 24)
                }
            }

            // Map provider picker
            Picker("Map Provider", selection: Binding(
                get: { settingsVM.mapProvider },
                set: { settingsVM.setMapProvider($0) }
            )) {
                ForEach(MapProvider.allCases, id: \.self) { provider in
                    Label(provider.displayName, systemImage: provider.icon).tag(provider)
                }
            }

            // MapTiler API Key - only show if MapTiler is selected or configured
            if settingsVM.mapProvider == .mapTiler || settingsVM.mapTilerSettings.isValid {
                NavigationLink {
                    MapTilerSettingsView()
                } label: {
                    HStack {
                        Text("MapTiler Cloud")
                        Spacer()
                        Text(settingsVM.mapTilerSettings.isValid ? "Configured" : "Not Set")
                            .foregroundColor(settingsVM.mapProvider == .mapTiler && !settingsVM.mapTilerSettings.isValid ? .orange : .secondary)
                    }
                }
            }
        }
    }

    // MARK: - Measurement Section

    private var measurementSection: some View {
        Section("Measurement") {
            // Unit system
            Picker("Unit System", selection: Binding(
                get: { settingsVM.settings.unitSystem },
                set: { settingsVM.setUnitSystem($0) }
            )) {
                ForEach(UnitSystem.allCases, id: \.self) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }

            // Coordinate format
            Picker("Coordinate Format", selection: Binding(
                get: { settingsVM.settings.coordFormat },
                set: { settingsVM.setCoordFormat($0) }
            )) {
                ForEach(CoordinateFormat.allCases, id: \.self) { format in
                    Text(format.displayName).tag(format)
                }
            }
        }
    }

    // MARK: - Transport Section

    private var transportSection: some View {
        Section {
            Picker("Transport Mode", selection: Binding(
                get: { settingsVM.transportMode },
                set: { settingsVM.setTransportMode($0) }
            )) {
                Text("Local WiFi (UDP)").tag(TransportMode.localUDP)
                Text("Internet (MQTT)").tag(TransportMode.mqtt)
            }
            .pickerStyle(.inline)

            // Connection status
            HStack {
                Text("Status")
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(settingsVM.connectionStateDescription)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Transport")
        } footer: {
            Text("UDP works on local WiFi networks. MQTT requires an internet connection and server.")
        }
    }

    private var statusColor: Color {
        switch TransportCoordinator.shared.connectionState {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .gray
        case .error: return .red
        }
    }

    // MARK: - MQTT Section

    private var mqttSection: some View {
        Section {
            // Host
            HStack {
                Text("Host")
                Spacer()
                TextField("mqtt.example.com", text: Binding(
                    get: { settingsVM.mqttSettings.host },
                    set: { updateMqttHost($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }

            // Port
            HStack {
                Text("Port")
                Spacer()
                TextField("8883", text: Binding(
                    get: { String(settingsVM.mqttSettings.port) },
                    set: { if let port = Int($0) { updateMqttPort(port) } }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
            }

            // Username
            HStack {
                Text("Username")
                Spacer()
                TextField("Optional", text: Binding(
                    get: { settingsVM.mqttSettings.username },
                    set: { updateMqttUsername($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }

            // Password
            HStack {
                Text("Password")
                Spacer()
                SecureField("Optional", text: Binding(
                    get: { settingsVM.mqttSettings.password },
                    set: { updateMqttPassword($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
                .multilineTextAlignment(.trailing)
            }

            // TLS toggle
            Toggle("Use TLS/SSL", isOn: Binding(
                get: { settingsVM.mqttSettings.useTls },
                set: { updateMqttTls($0) }
            ))

            // Message age limit
            Stepper("Max Age: \(settingsVM.mqttSettings.maxMessageAgeMinutes) min",
                    value: Binding(
                        get: { settingsVM.mqttSettings.maxMessageAgeMinutes },
                        set: { updateMqttMaxAge($0) }
                    ),
                    in: 0...1440,
                    step: 60)

            // Connect/Disconnect button
            Button(action: {
                if settingsVM.isConnected {
                    settingsVM.disconnectMQTT()
                } else {
                    settingsVM.connectMQTT()
                }
            }) {
                HStack {
                    Spacer()
                    if case .connecting = settingsVM.connectionState {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                            .padding(.trailing, 8)
                    }
                    Text(buttonText)
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(buttonColor)
            .disabled(isButtonDisabled)

            // Show advanced toggle
            Button(action: {
                withAnimation {
                    showingAdvancedMqtt.toggle()
                }
            }) {
                HStack {
                    Text(showingAdvancedMqtt ? "Hide Advanced Settings" : "Show Advanced Settings")
                        .foregroundColor(.blue)
                    Spacer()
                    Image(systemName: showingAdvancedMqtt ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
        } header: {
            HStack {
                Text("MQTT Configuration")
                Spacer()
                // Connection status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(connectionStatusColor)
                        .frame(width: 8, height: 8)
                    Text(settingsVM.connectionStateDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } footer: {
            if !settingsVM.mqttSettings.isValid {
                Text("Enter a valid host to connect")
                    .foregroundColor(.orange)
            } else if case .error(let msg) = settingsVM.connectionState {
                Text("Error: \(msg)")
                    .foregroundColor(.red)
            }
        }
    }

    private var connectionStatusColor: Color {
        switch settingsVM.connectionState {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .gray
        case .error: return .red
        }
    }

    private var buttonText: String {
        switch settingsVM.connectionState {
        case .connected: return "Disconnect"
        case .connecting: return "Connecting..."
        case .disconnected: return "Connect"
        case .error: return "Retry"
        }
    }

    private var buttonColor: Color {
        switch settingsVM.connectionState {
        case .connected: return .red
        case .connecting: return .orange
        case .disconnected, .error: return .blue
        }
    }

    private var isButtonDisabled: Bool {
        if case .connecting = settingsVM.connectionState {
            return true
        }
        return !settingsVM.mqttSettings.isValid && !settingsVM.isConnected
    }

    // MARK: - GPS Section

    private var gpsSection: some View {
        Section {
            HStack {
                Text("Broadcast Interval")
                Spacer()
                Picker("", selection: Binding(
                    get: { settingsVM.settings.gpsInterval.value },
                    set: { settingsVM.setGpsInterval(value: $0, unit: settingsVM.settings.gpsInterval.unit) }
                )) {
                    ForEach([1, 2, 5, 10, 15, 30, 60], id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 80)

                Picker("", selection: Binding(
                    get: { settingsVM.settings.gpsInterval.unit },
                    set: { settingsVM.setGpsInterval(value: settingsVM.settings.gpsInterval.value, unit: $0) }
                )) {
                    Text("sec").tag("s")
                    Text("min").tag("m")
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }
        } header: {
            Text("Position Broadcasting")
        } footer: {
            Text("How often to broadcast your position to other devices. Current: \(settingsVM.settings.gpsInterval.displayString)")
        }
    }

    // MARK: - Security Section

    private var securitySection: some View {
        Section {
            Toggle("Message Signing", isOn: Binding(
                get: { settingsVM.settings.messageSigningEnabled },
                set: { settingsVM.setMessageSigningEnabled($0) }
            ))
        } header: {
            Text("Security")
        } footer: {
            Text("Sign outgoing messages with HMAC-SHA256 to prevent tampering")
        }
    }

    // MARK: - Advanced MQTT Section

    private var advancedMqttSection: some View {
        Section {
            // Client ID
            HStack {
                Text("Client ID")
                Spacer()
                TextField("Auto-generated", text: Binding(
                    get: { SettingsDataStore.shared.get(SettingsKeys.MqttClientId()) },
                    set: { SettingsDataStore.shared.set(SettingsKeys.MqttClientId(), value: $0) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }

            // Keep-alive interval
            Stepper("Keep-alive: 60s", value: .constant(60), in: 15...300, step: 15)

            // Clean session toggle
            Toggle("Clean Session", isOn: .constant(true))

            // QoS level
            Picker("QoS Level", selection: .constant(1)) {
                Text("0 - At most once").tag(0)
                Text("1 - At least once").tag(1)
                Text("2 - Exactly once").tag(2)
            }
        } header: {
            Text("Advanced MQTT")
        } footer: {
            Text("Leave Client ID empty for auto-generation")
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section {
            // Sync now button
            Button(action: {
                let deviceId = TransportCoordinator.shared.deviceId
                TacDispatcher.performFullSync(deviceId: deviceId)
                RefreshBus.shared.emitSyncRequested()
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.blue)
                    Text("Sync Now")
                        .foregroundColor(.primary)
                    Spacer()
                }
            }

            // Clear chat data
            Button(action: {
                InMemoryChatRepository.shared.clearAll()
                RefreshBus.shared.emitChatChanged()
            }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.orange)
                    Text("Clear Chat History")
                        .foregroundColor(.primary)
                    Spacer()
                }
            }

            // Clear contacts
            Button(action: {
                ProfileRepository.shared.clearContacts()
                RefreshBus.shared.emitContactsChanged()
            }) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .foregroundColor(.orange)
                    Text("Clear Contacts")
                        .foregroundColor(.primary)
                    Spacer()
                }
            }

            // Reset all settings
            Button(action: {
                showingResetAlert = true
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.red)
                    Text("Reset All Settings")
                        .foregroundColor(.red)
                    Spacer()
                }
            }
        } header: {
            Text("Data Management")
        } footer: {
            Text("Device ID: \(settingsVM.deviceId.prefix(8))...")
        }
    }

    // MARK: - MQTT Helpers

    private func updateMqttHost(_ host: String) {
        var settings = settingsVM.mqttSettings
        settings.host = host
        settingsVM.updateMqttSettings(settings)
    }

    private func updateMqttPort(_ port: Int) {
        var settings = settingsVM.mqttSettings
        settings.port = port
        settingsVM.updateMqttSettings(settings)
    }

    private func updateMqttUsername(_ username: String) {
        var settings = settingsVM.mqttSettings
        settings.username = username
        settingsVM.updateMqttSettings(settings)
    }

    private func updateMqttPassword(_ password: String) {
        var settings = settingsVM.mqttSettings
        settings.password = password
        settingsVM.updateMqttSettings(settings)
    }

    private func updateMqttTls(_ useTls: Bool) {
        var settings = settingsVM.mqttSettings
        settings.useTls = useTls
        // Auto-update port when toggling TLS
        if useTls && settings.port == 1883 {
            settings.port = 8883
        } else if !useTls && settings.port == 8883 {
            settings.port = 1883
        }
        settingsVM.updateMqttSettings(settings)
    }

    private func updateMqttMaxAge(_ minutes: Int) {
        var settings = settingsVM.mqttSettings
        settings.maxMessageAgeMinutes = minutes
        settingsVM.updateMqttSettings(settings)
    }
}

// MARK: - Breadcrumb Color Picker

private struct BreadcrumbColorPicker: View {
    @ObservedObject private var settingsVM = SettingsViewModel.shared
    @Environment(\.dismiss) private var dismiss

    private let colors: [(String, Color)] = [
        ("Orange", Color(red: 1.0, green: 0.6, blue: 0.0)),
        ("Red", Color.red),
        ("Blue", Color.blue),
        ("Green", Color.green),
        ("Yellow", Color.yellow),
        ("White", Color.white),
        ("Purple", Color.purple),
        ("Cyan", Color.cyan)
    ]

    var body: some View {
        List {
            ForEach(colors, id: \.0) { name, color in
                Button(action: {
                    settingsVM.setBreadcrumbColor(color)
                    dismiss()
                }) {
                    HStack {
                        Circle()
                            .fill(color)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        Text(name)
                            .foregroundColor(.primary)

                        Spacer()

                        if isSelected(color) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Breadcrumb Color")
    }

    private func isSelected(_ color: Color) -> Bool {
        // Simple comparison - in practice might need better color comparison
        return settingsVM.breadcrumbColor.description == color.description
    }
}

// MARK: - Profile Edit View

/// View for editing user profile
struct ProfileEditView: View {
    @ObservedObject private var profileVM = ProfileViewModel.shared
    @Environment(\.dismiss) private var dismiss
    @State private var editableProfile: EditableProfile

    init() {
        _editableProfile = State(initialValue: ProfileViewModel.shared.makeEditableProfile())
    }

    var body: some View {
        Form {
            // Basic info
            Section("Identity") {
                TextField("Callsign", text: $editableProfile.callsign)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                TextField("Nickname", text: $editableProfile.nickname)
                    .autocorrectionDisabled()
            }

            // Personal info
            Section("Personal") {
                TextField("First Name", text: $editableProfile.firstName)
                TextField("Last Name", text: $editableProfile.lastName)
            }

            // Contact info
            Section("Contact") {
                TextField("Phone", text: $editableProfile.phone)
                    .keyboardType(.phonePad)

                TextField("Email", text: $editableProfile.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            // Organization
            Section("Organization") {
                TextField("Company", text: $editableProfile.company)
                TextField("Platoon", text: $editableProfile.platoon)
                TextField("Squad", text: $editableProfile.squad)
            }

            // Role
            Section("Role") {
                Picker("Military Role", selection: $editableProfile.role) {
                    ForEach(MilitaryRole.allCases, id: \.self) { role in
                        Text(role.displayName).tag(role)
                    }
                }
            }

            // Validation errors
            if !profileVM.validationErrors.isEmpty {
                Section {
                    ForEach(profileVM.validationErrors, id: \.self) { error in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    profileVM.saveEditable(editableProfile)
                    if profileVM.validationErrors.isEmpty {
                        dismiss()
                    }
                }
                .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - MapTiler Settings View

/// View for configuring MapTiler Cloud API key
struct MapTilerSettingsView: View {
    @ObservedObject private var settingsVM = SettingsViewModel.shared
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""

    var body: some View {
        Form {
            Section {
                SecureField("API Key", text: $apiKey)
                    .textContentType(.password)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            } header: {
                Text("MapTiler Cloud API Key")
            } footer: {
                Text("Get your free API key at maptiler.com/cloud\n\nMapTiler provides high-quality terrain, outdoor, and topographic map tiles.")
            }

            Section {
                Button("Save API Key") {
                    settingsVM.setMapTilerApiKey(apiKey)
                    dismiss()
                }
                .disabled(apiKey.isEmpty)

                if settingsVM.mapTilerSettings.isValid {
                    Button("Clear API Key", role: .destructive) {
                        settingsVM.setMapTilerApiKey("")
                        apiKey = ""
                    }
                }
            }

            if settingsVM.mapTilerSettings.isValid {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("MapTiler is configured")
                    }

                    Text("Terrain, Outdoor, and Topographic map styles will now use MapTiler Cloud tiles.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Status")
                }
            }
        }
        .navigationTitle("MapTiler Cloud")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            apiKey = settingsVM.mapTilerSettings.apiKey
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsScreen()
}

#Preview("Profile Edit") {
    NavigationStack {
        ProfileEditView()
    }
}

#Preview("MapTiler Settings") {
    NavigationStack {
        MapTilerSettingsView()
    }
}
