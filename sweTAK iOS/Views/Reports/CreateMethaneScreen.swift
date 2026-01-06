import SwiftUI
import CoreLocation
import MapKit

/// Screen for creating and sending a METHANE emergency notification request.
/// METHANE: Major incident, Exact location, Type of incident, Hazards,
///          Access routes, Number of casualties, Emergency services
/// Mirrors Android CreateMethaneScreen functionality.
public struct CreateMethaneScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var contactsVM = ContactsViewModel.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var settingsVM = SettingsViewModel.shared

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

    // Location picker
    @State private var showingLocationPicker = false
    @State private var pickingLocationFor: LocationPickerTarget = .incident

    private enum LocationPickerTarget {
        case incident
        case hls
    }

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
                incidentCoordinates = CoordinateFormatter.format(
                    latitude: lat, longitude: lon, format: settingsVM.settings.coordFormat
                )
            }
            incidentTime = source.incidentTime
            incidentType = source.incidentType
            hazards = source.hazards
            approachRoutes = source.approachRoutes
            hlsLocation = source.hlsLocation
            if let hlsLat = source.hlsLatitude, let hlsLon = source.hlsLongitude {
                hlsCoordinates = CoordinateFormatter.format(
                    latitude: hlsLat, longitude: hlsLon, format: settingsVM.settings.coordFormat
                )
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
            incidentCoordinates = CoordinateFormatter.format(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                format: settingsVM.settings.coordFormat
            )
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
                        pickingLocationFor = .incident
                        showingLocationPicker = true
                    } label: {
                        Image(systemName: "map")
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
                        pickingLocationFor = .hls
                        showingLocationPicker = true
                    } label: {
                        Image(systemName: "map")
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
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerSheet(
                initialCoordinate: getInitialCoordinate(),
                coordinateFormat: settingsVM.settings.coordFormat,
                onSelect: { coordinate in
                    let coordString = CoordinateFormatter.format(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        format: settingsVM.settings.coordFormat
                    )
                    switch pickingLocationFor {
                    case .incident:
                        incidentCoordinates = coordString
                    case .hls:
                        hlsCoordinates = coordString
                    }
                }
            )
        }
    }

    private func getInitialCoordinate() -> CLLocationCoordinate2D? {
        // Try to parse existing coordinates for the target field
        let coordString = pickingLocationFor == .incident ? incidentCoordinates : hlsCoordinates
        let (lat, lon) = parseCoordinates(coordString)
        if let lat = lat, let lon = lon {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        // Fall back to current location
        return locationManager.currentLocation?.coordinate
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

    private func parseCoordinates(_ input: String) -> (Double?, Double?) {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return (nil, nil) }

        // Try parsing as decimal lat/lon (comma or space separated)
        let decimalPattern = #"(-?\d+\.?\d*)[,\s]+(-?\d+\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: decimalPattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            if let latRange = Range(match.range(at: 1), in: trimmed),
               let lonRange = Range(match.range(at: 2), in: trimmed),
               let lat = Double(trimmed[latRange]),
               let lon = Double(trimmed[lonRange]),
               lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 {
                return (lat, lon)
            }
        }

        // Try parsing as DMS (e.g., 59°19'45.6"N 18°04'06.9"E)
        let dmsPattern = #"(\d+)°(\d+)'([\d.]+)\"([NS])\s+(\d+)°(\d+)'([\d.]+)\"([EW])"#
        if let regex = try? NSRegularExpression(pattern: dmsPattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            if let latDegRange = Range(match.range(at: 1), in: trimmed),
               let latMinRange = Range(match.range(at: 2), in: trimmed),
               let latSecRange = Range(match.range(at: 3), in: trimmed),
               let latDirRange = Range(match.range(at: 4), in: trimmed),
               let lonDegRange = Range(match.range(at: 5), in: trimmed),
               let lonMinRange = Range(match.range(at: 6), in: trimmed),
               let lonSecRange = Range(match.range(at: 7), in: trimmed),
               let lonDirRange = Range(match.range(at: 8), in: trimmed),
               let latDeg = Double(trimmed[latDegRange]),
               let latMin = Double(trimmed[latMinRange]),
               let latSec = Double(trimmed[latSecRange]),
               let lonDeg = Double(trimmed[lonDegRange]),
               let lonMin = Double(trimmed[lonMinRange]),
               let lonSec = Double(trimmed[lonSecRange]) {

                var lat = latDeg + latMin / 60.0 + latSec / 3600.0
                var lon = lonDeg + lonMin / 60.0 + lonSec / 3600.0

                if trimmed[latDirRange] == "S" { lat = -lat }
                if trimmed[lonDirRange] == "W" { lon = -lon }

                return (lat, lon)
            }
        }

        // Try parsing as MGRS (e.g., "33U UP 12345 67890" or "33UUP1234567890")
        let mgrsPattern = #"(\d{1,2})([C-X])\s*([A-HJ-NP-Z])([A-HJ-NP-V])\s*(\d+)\s*(\d+)"#
        if let regex = try? NSRegularExpression(pattern: mgrsPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            if let zoneRange = Range(match.range(at: 1), in: trimmed),
               let bandRange = Range(match.range(at: 2), in: trimmed),
               let colRange = Range(match.range(at: 3), in: trimmed),
               let rowRange = Range(match.range(at: 4), in: trimmed),
               let eRange = Range(match.range(at: 5), in: trimmed),
               let nRange = Range(match.range(at: 6), in: trimmed),
               let zone = Int(trimmed[zoneRange]) {

                let band = String(trimmed[bandRange]).uppercased()
                let colLetter = String(trimmed[colRange]).uppercased()
                let rowLetter = String(trimmed[rowRange]).uppercased()
                let eStr = String(trimmed[eRange])
                let nStr = String(trimmed[nRange])

                let (lat, lon) = mgrsToLatLon(zone: zone, band: band, col: colLetter, row: rowLetter, easting: eStr, northing: nStr)
                if lat != 0 || lon != 0 {
                    return (lat, lon)
                }
            }
        }

        // Try parsing as UTM (e.g., "34T 123456 6789012")
        let utmPattern = #"(\d+)([A-Z])\s+(\d+)\s+(\d+)"#
        if let regex = try? NSRegularExpression(pattern: utmPattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            if let zoneRange = Range(match.range(at: 1), in: trimmed),
               let letterRange = Range(match.range(at: 2), in: trimmed),
               let eastingRange = Range(match.range(at: 3), in: trimmed),
               let northingRange = Range(match.range(at: 4), in: trimmed),
               let zone = Int(trimmed[zoneRange]),
               let easting = Double(trimmed[eastingRange]),
               let northing = Double(trimmed[northingRange]) {

                let letter = String(trimmed[letterRange])
                let (lat, lon) = utmToLatLon(zone: zone, letter: letter, easting: easting, northing: northing)
                return (lat, lon)
            }
        }

        return (nil, nil)
    }

    private func mgrsToLatLon(zone: Int, band: String, col: String, row: String, easting: String, northing: String) -> (Double, Double) {
        // Convert column letter to 100km easting
        let colLetters: [String] = ["ABCDEFGH", "JKLMNPQR", "STUVWXYZ"]
        let setNumber = (zone - 1) % 3
        let colSet = colLetters[setNumber]

        guard let colIndex = colSet.firstIndex(of: Character(col)) else { return (0, 0) }
        let col100km = (colSet.distance(from: colSet.startIndex, to: colIndex) + 1) * 100000

        // Convert row letter to 100km northing
        let rowLetters = "ABCDEFGHJKLMNPQRSTUV"
        guard let rowIndex = rowLetters.firstIndex(of: Character(row)) else { return (0, 0) }
        let rowOffset = (zone % 2 == 0) ? 5 : 0
        var row100km = ((rowLetters.distance(from: rowLetters.startIndex, to: rowIndex) - rowOffset + 20) % 20) * 100000

        // Parse easting and northing (pad to 5 digits)
        let precision = easting.count
        let multiplier = Int(pow(10.0, Double(5 - precision)))
        guard let e = Int(easting), let n = Int(northing) else { return (0, 0) }

        let fullEasting = Double(col100km + e * multiplier)
        var fullNorthing = Double(row100km + n * multiplier)

        // Adjust northing based on latitude band
        let bandLetters = "CDEFGHJKLMNPQRSTUVWX"
        if let bandIndex = bandLetters.firstIndex(of: Character(band)) {
            let bandNum = bandLetters.distance(from: bandLetters.startIndex, to: bandIndex)
            // Estimate base northing from band
            let bandBaseNorthing = Double(bandNum - 10) * 8 * 111000 // Approximate
            while fullNorthing < bandBaseNorthing - 500000 {
                fullNorthing += 2000000
            }
        }

        return utmToLatLon(zone: zone, letter: band, easting: fullEasting, northing: fullNorthing)
    }

    private func utmToLatLon(zone: Int, letter: String, easting: Double, northing: Double) -> (Double, Double) {
        // Simplified UTM to lat/lon conversion
        let k0 = 0.9996
        let a = 6378137.0 // WGS84 semi-major axis
        let e2 = 0.00669438 // WGS84 eccentricity squared
        let e1 = (1 - sqrt(1 - e2)) / (1 + sqrt(1 - e2))

        let x = easting - 500000.0
        var y = northing

        // Adjust for southern hemisphere
        let letters = "CDEFGHJKLMNPQRSTUVWX"
        if let index = letters.firstIndex(of: Character(letter)), letters.distance(from: letters.startIndex, to: index) < 10 {
            y = y - 10000000.0
        }

        let lonOrigin = Double((zone - 1) * 6 - 180 + 3)

        let M = y / k0
        let mu = M / (a * (1 - e2/4 - 3*e2*e2/64))

        let phi1 = mu + (3*e1/2 - 27*e1*e1*e1/32) * sin(2*mu)
                   + (21*e1*e1/16 - 55*e1*e1*e1*e1/32) * sin(4*mu)

        let N1 = a / sqrt(1 - e2 * sin(phi1) * sin(phi1))
        let T1 = tan(phi1) * tan(phi1)
        let C1 = e2 / (1 - e2) * cos(phi1) * cos(phi1)
        let R1 = a * (1 - e2) / pow(1 - e2 * sin(phi1) * sin(phi1), 1.5)
        let D = x / (N1 * k0)

        let lat = phi1 - (N1 * tan(phi1) / R1) * (D*D/2 - (5 + 3*T1) * D*D*D*D/24)
        let lon = lonOrigin + (D - (1 + 2*T1 + C1) * D*D*D/6) / cos(phi1) * 180 / .pi

        return (lat * 180 / .pi, lon)
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

// MARK: - Location Picker Sheet

private struct LocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var locationManager = LocationManager.shared

    let initialCoordinate: CLLocationCoordinate2D?
    let coordinateFormat: CoordinateFormat
    let onSelect: (CLLocationCoordinate2D) -> Void

    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
                    // Show selected location marker
                    if let coord = selectedCoordinate {
                        Annotation("Selected", coordinate: coord) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                        }
                    }

                    // Show user location
                    UserAnnotation()
                }
                .onTapGesture { position in
                    // This doesn't give us the coordinate directly, we need a workaround
                }
                .gesture(
                    SpatialTapGesture()
                        .onEnded { _ in
                            // We'll use a different approach - center crosshair
                        }
                )

                // Center crosshair for selection
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "plus")
                            .font(.title)
                            .foregroundColor(.red)
                            .shadow(color: .white, radius: 2)
                        Spacer()
                    }
                    Spacer()
                }
                .allowsHitTesting(false)

                // Coordinate display at bottom
                VStack {
                    Spacer()
                    if let coord = selectedCoordinate {
                        Text(CoordinateFormatter.format(
                            latitude: coord.latitude,
                            longitude: coord.longitude,
                            format: coordinateFormat
                        ))
                            .font(.caption)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Pick Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Select") {
                        if let coord = selectedCoordinate {
                            onSelect(coord)
                        }
                        dismiss()
                    }
                    .disabled(selectedCoordinate == nil)
                }
            }
            .onAppear {
                setupInitialPosition()
            }
            .onMapCameraChange { context in
                // Update selected coordinate to map center
                selectedCoordinate = context.region.center
            }
        }
    }

    private func setupInitialPosition() {
        if let initial = initialCoordinate {
            selectedCoordinate = initial
            cameraPosition = .region(MKCoordinateRegion(
                center: initial,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            ))
        } else if let location = locationManager.currentLocation {
            selectedCoordinate = location.coordinate
            cameraPosition = .region(MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            ))
        }
    }
}

// MARK: - Preview

#Preview("Create METHANE") {
    CreateMethaneScreen()
}
