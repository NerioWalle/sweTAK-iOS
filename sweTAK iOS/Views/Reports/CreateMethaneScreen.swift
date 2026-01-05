import SwiftUI
import CoreLocation

/// Screen for creating and sending a METHANE emergency notification request.
/// METHANE: Major incident, Exact location, Type of incident, Hazards,
///          Access routes, Number of casualties, Emergency services
/// Mirrors Android CreateMethaneScreen functionality.
public struct CreateMethaneScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var contactsVM = ContactsViewModel.shared
    @ObservedObject private var locationManager = LocationManager.shared

    // Optional request to duplicate from
    private let duplicateFrom: MethaneRequest?

    // Form state
    // M - Military details
    @State private var callsign = ""
    @State private var unit = ""

    // E - Exact location
    @State private var incidentLocation = ""
    @State private var incidentCoordinates = ""

    // T - Time and type of incident
    @State private var incidentTime = ""
    @State private var incidentType = ""

    // H - Hazards
    @State private var hazards = ""

    // A - Approach routes and landing sites
    @State private var approachRoutes = ""
    @State private var hlsLocation = ""
    @State private var hlsCoordinates = ""

    // N - Numbers of casualties
    @State private var casualtyCountP1 = ""
    @State private var casualtyCountP2 = ""
    @State private var casualtyCountP3 = ""
    @State private var casualtyCountDeceased = ""
    @State private var casualtyDetails = ""

    // E - Expected response
    @State private var assetsPresent = ""
    @State private var assetsRequired = ""

    // Recipients
    @State private var selectedRecipientIds: Set<String> = []
    @State private var showingRecipientPicker = false

    // Validation
    private var isValid: Bool {
        !selectedRecipientIds.isEmpty && !incidentType.isEmpty
    }

    private var availableRecipients: [ContactProfile] {
        contactsVM.contacts.filter { $0.deviceId != TransportCoordinator.shared.deviceId }
    }

    public init(duplicateFrom: MethaneRequest? = nil) {
        self.duplicateFrom = duplicateFrom
    }

    public var body: some View {
        NavigationStack {
            if showingRecipientPicker {
                recipientPickerView
            } else {
                formView
            }
        }
        .onAppear {
            setupDefaults()
        }
    }

    private func setupDefaults() {
        // If duplicating, pre-fill all fields from source (except recipients)
        if let source = duplicateFrom {
            callsign = source.callsign
            unit = source.unit
            incidentLocation = source.incidentLocation
            if let lat = source.incidentLatitude, let lon = source.incidentLongitude {
                incidentCoordinates = String(format: "%.6f, %.6f", lat, lon)
            }
            incidentTime = source.incidentTime
            incidentType = source.incidentType
            hazards = source.hazards
            approachRoutes = source.approachRoutes
            hlsLocation = source.hlsLocation
            if let hlsLat = source.hlsLatitude, let hlsLon = source.hlsLongitude {
                hlsCoordinates = String(format: "%.6f, %.6f", hlsLat, hlsLon)
            }
            casualtyCountP1 = source.casualtyCountP1 > 0 ? String(source.casualtyCountP1) : ""
            casualtyCountP2 = source.casualtyCountP2 > 0 ? String(source.casualtyCountP2) : ""
            casualtyCountP3 = source.casualtyCountP3 > 0 ? String(source.casualtyCountP3) : ""
            casualtyCountDeceased = source.casualtyCountDeceased > 0 ? String(source.casualtyCountDeceased) : ""
            casualtyDetails = source.casualtyDetails
            assetsPresent = source.assetsPresent
            assetsRequired = source.assetsRequired
            // Recipients are intentionally NOT copied - user must select new ones
            return
        }

        // Set default callsign from profile
        if let profile = contactsVM.myProfile {
            callsign = profile.callsign ?? ""
            unit = profile.company ?? ""
        }

        // Set current time
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        incidentTime = formatter.string(from: Date())

        // Set current location if available
        if let location = locationManager.currentLocation {
            incidentCoordinates = String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude)
        }
    }

    // MARK: - Form View

    private var formView: some View {
        Form {
            // Recipients section
            Section {
                Button {
                    showingRecipientPicker = true
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Recipients")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(selectedRecipientIds.isEmpty
                                 ? "Select recipients..."
                                 : "\(selectedRecipientIds.count) selected")
                        }
                        Spacer()
                        Image(systemName: selectedRecipientIds.isEmpty ? "chevron.right" : "checkmark")
                            .foregroundColor(selectedRecipientIds.isEmpty ? .secondary : .blue)
                    }
                }
                .foregroundColor(.primary)
            }

            // M - Military Details
            Section {
                TextField("Callsign", text: $callsign)
                TextField("Unit", text: $unit)
            } header: {
                MethaneSectionHeader(letter: "M", title: "MILITARY DETAILS")
            }

            // E - Exact Location
            Section {
                TextField("Location Description", text: $incidentLocation, axis: .vertical)
                    .lineLimit(2...4)

                HStack {
                    TextField("Coordinates", text: $incidentCoordinates)
                    Button {
                        useCurrentLocation()
                    } label: {
                        Image(systemName: "location.fill")
                    }
                }
            } header: {
                MethaneSectionHeader(letter: "E", title: "EXACT LOCATION")
            }

            // T - Time and Type
            Section {
                HStack {
                    TextField("Time", text: $incidentTime)
                        .frame(width: 80)
                    TextField("Type of Incident *", text: $incidentType)
                }
            } header: {
                MethaneSectionHeader(letter: "T", title: "TIME AND TYPE OF INCIDENT")
            }

            // H - Hazards
            Section {
                TextField("Hazards Present/Potential", text: $hazards, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                MethaneSectionHeader(letter: "H", title: "HAZARDS")
            }

            // A - Approach Routes
            Section {
                TextField("Approach Routes", text: $approachRoutes, axis: .vertical)
                    .lineLimit(2...4)

                TextField("HLS Location", text: $hlsLocation)

                HStack {
                    TextField("HLS Coordinates", text: $hlsCoordinates)
                    Button {
                        useCurrentLocationForHLS()
                    } label: {
                        Image(systemName: "location.fill")
                    }
                }
            } header: {
                MethaneSectionHeader(letter: "A", title: "APPROACH ROUTES & HLS")
            }

            // N - Numbers of Casualties
            Section {
                HStack(spacing: 8) {
                    VStack {
                        Text("P1")
                            .font(.caption)
                            .foregroundColor(.red)
                        TextField("0", text: $casualtyCountP1)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                    }
                    VStack {
                        Text("P2")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        TextField("0", text: $casualtyCountP2)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                    }
                    VStack {
                        Text("P3")
                            .font(.caption)
                            .foregroundColor(.green)
                        TextField("0", text: $casualtyCountP3)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                    }
                    VStack {
                        Text("Dead")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("0", text: $casualtyCountDeceased)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                    }
                }

                TextField("Casualty Details", text: $casualtyDetails, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                MethaneSectionHeader(letter: "N", title: "NUMBERS AND TYPE OF CASUALTIES")
            }

            // E - Expected Response
            Section {
                TextField("Assets Present", text: $assetsPresent, axis: .vertical)
                    .lineLimit(2...4)

                TextField("Assets Required", text: $assetsRequired, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                MethaneSectionHeader(letter: "E", title: "EXPECTED RESPONSE")
            }
        }
        .navigationTitle("Create METHANE")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    sendRequest()
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(!isValid)
            }
        }
    }

    // MARK: - Recipient Picker

    private var recipientPickerView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select Recipients")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    showingRecipientPicker = false
                }
            }
            .padding()

            Divider()

            if availableRecipients.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No devices available")
                        .font(.headline)
                    Text("Devices from the contact book will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(availableRecipients) { recipient in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { selectedRecipientIds.contains(recipient.deviceId) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedRecipientIds.insert(recipient.deviceId)
                                    } else {
                                        selectedRecipientIds.remove(recipient.deviceId)
                                    }
                                }
                            )) {
                                VStack(alignment: .leading) {
                                    Text(recipient.callsign ?? String(recipient.deviceId.prefix(8)))
                                        .font(.body)
                                    if let nickname = recipient.nickname, !nickname.isEmpty {
                                        Text(nickname)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func useCurrentLocation() {
        if let location = locationManager.currentLocation {
            incidentCoordinates = String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude)
        }
    }

    private func useCurrentLocationForHLS() {
        if let location = locationManager.currentLocation {
            hlsCoordinates = String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude)
        }
    }

    private func parseCoordinates(_ input: String) -> (Double?, Double?) {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return (nil, nil) }

        // Try parsing as lat/lon (comma or space separated)
        let pattern = #"(-?\d+\.?\d*)[,\s]+(-?\d+\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            if let latRange = Range(match.range(at: 1), in: trimmed),
               let lonRange = Range(match.range(at: 2), in: trimmed),
               let lat = Double(trimmed[latRange]),
               let lon = Double(trimmed[lonRange]),
               lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 {
                return (lat, lon)
            }
        }

        return (nil, nil)
    }

    private func sendRequest() {
        let (incidentLat, incidentLon) = parseCoordinates(incidentCoordinates)
        let (hlsLat, hlsLon) = parseCoordinates(hlsCoordinates)

        let request = MethaneRequest(
            senderDeviceId: TransportCoordinator.shared.deviceId,
            senderCallsign: contactsVM.myProfile?.callsign ?? "Unknown",
            callsign: callsign,
            unit: unit,
            incidentLocation: incidentLocation,
            incidentLatitude: incidentLat,
            incidentLongitude: incidentLon,
            incidentTime: incidentTime,
            incidentType: incidentType,
            hazards: hazards,
            approachRoutes: approachRoutes,
            hlsLocation: hlsLocation,
            hlsLatitude: hlsLat,
            hlsLongitude: hlsLon,
            casualtyCountP1: Int(casualtyCountP1) ?? 0,
            casualtyCountP2: Int(casualtyCountP2) ?? 0,
            casualtyCountP3: Int(casualtyCountP3) ?? 0,
            casualtyCountDeceased: Int(casualtyCountDeceased) ?? 0,
            casualtyDetails: casualtyDetails,
            assetsPresent: assetsPresent,
            assetsRequired: assetsRequired,
            recipientDeviceIds: Array(selectedRecipientIds),
            direction: .outgoing
        )

        MethaneViewModel.shared.sendMethaneRequest(request)
        dismiss()
    }
}

// MARK: - Section Header

private struct MethaneSectionHeader: View {
    let letter: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Text(letter)
                .font(.headline)
                .foregroundColor(.blue)
            Text("-")
                .foregroundColor(.blue)
            Text(title)
                .foregroundColor(.blue)
        }
    }
}

// MARK: - Preview

#Preview("Create METHANE") {
    CreateMethaneScreen()
}
