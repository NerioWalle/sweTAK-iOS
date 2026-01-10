import SwiftUI
import MapKit

/// Tactical map view with pins, overlays, and peer positions
/// Mirrors Android MapScreen map functionality
public struct TacticalMapView: View {
    @ObservedObject private var mapVM = MapViewModel.shared
    @ObservedObject private var pinsVM = PinsViewModel.shared
    @ObservedObject private var settingsVM = SettingsViewModel.shared
    @ObservedObject private var locationManager = LocationManager.shared

    // Map region binding
    @State private var region: MKCoordinateRegion
    @State private var mapCameraPosition: MapCameraPosition = .automatic

    // Interaction state
    @State private var selectedPin: NatoPin?
    @State private var showingPinDetail = false
    @State private var showingAddPin = false
    @State private var longPressLocation: CLLocationCoordinate2D?

    // Peer interaction state
    @State private var selectedPeer: PeerPosition?
    @State private var showingPeerDetail = false

    // Crosshair state
    @State private var showCrosshair = false

    public init() {
        // Initialize with saved camera position or default
        if let saved = MapViewModel.shared.cameraPosition {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: saved.latitude, longitude: saved.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        } else {
            // Default to Stockholm, Sweden
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
    }

    public var body: some View {
        ZStack {
            // Main map
            mapContent

            // Crosshair overlay
            if showCrosshair {
                crosshairOverlay
            }

            // Coordinate display overlay
            coordinateOverlay
        }
        .onAppear {
            locationManager.startTracking()
        }
        .sheet(isPresented: $showingPinDetail) {
            if let pin = selectedPin {
                PinDetailSheet(pin: pin)
            }
        }
        .sheet(isPresented: $showingAddPin) {
            if let location = longPressLocation {
                AddPinSheet(location: location) { pin in
                    pinsVM.addPin(pin)
                }
            }
        }
        .sheet(isPresented: $showingPeerDetail) {
            if let peer = selectedPeer {
                PeerDetailSheet(peer: peer)
            }
        }
    }

    // MARK: - Map Content

    @ViewBuilder
    private var mapContent: some View {
        Map(position: $mapCameraPosition, interactionModes: .all) {
            // User location
            UserAnnotation()

            // Peer positions
            ForEach(Array(mapVM.peerPositions.values)) { peer in
                Annotation(peer.callsign, coordinate: peer.coordinate) {
                    PeerMarkerView(peer: peer) {
                        selectedPeer = peer
                        showingPeerDetail = true
                    }
                }
            }

            // NATO Pins
            ForEach(pinsVM.pins) { pin in
                Annotation(pin.title, coordinate: pin.coordinate) {
                    PinMarkerView(pin: pin) {
                        selectedPin = pin
                        showingPinDetail = true
                    }
                }
            }

            // Breadcrumb routes
            if locationManager.isRecordingBreadcrumbs {
                MapPolyline(coordinates: locationManager.breadcrumbPoints.map { $0.coordinate })
                    .stroke(settingsVM.breadcrumbColor, lineWidth: 3)
            }
        }
        .mapStyle(mapStyleForSettings)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange { context in
            // Save camera position when it changes
            let center = context.region.center
            let span = context.region.span
            mapVM.saveCameraPosition(
                lat: center.latitude,
                lng: center.longitude,
                zoom: zoomFromSpan(span),
                bearing: 0 // MapKit doesn't expose bearing easily
            )
        }
        .gesture(longPressGesture)
    }

    // MARK: - Map Style

    private var mapStyleForSettings: _MapKit_SwiftUI.MapStyle {
        switch settingsVM.settings.mapStyle {
        case .satellite:
            return .imagery
        case .terrain:
            return .standard(elevation: .realistic)
        case .streets:
            return .standard
        case .dark:
            return .standard(pointsOfInterest: .excludingAll)
        }
    }

    // MARK: - Long Press Gesture

    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onEnded { value in
                switch value {
                case .second(true, let drag):
                    if let location = drag?.location {
                        // Convert screen point to coordinate
                        // Note: This is approximate - proper conversion needs MKMapView
                        let centerLat = region.center.latitude
                        let centerLng = region.center.longitude
                        longPressLocation = CLLocationCoordinate2D(
                            latitude: centerLat,
                            longitude: centerLng
                        )
                        showingAddPin = true
                    }
                default:
                    break
                }
            }
    }

    // MARK: - Crosshair Overlay

    private var crosshairOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Image(systemName: "plus")
                    .font(.title)
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color.white.opacity(0.7))
                    .clipShape(Circle())
                Spacer()
            }
            Spacer()
        }
    }

    // MARK: - Coordinate Display Overlay

    private var coordinateOverlay: some View {
        VStack {
            Spacer()

            HStack {
                // Coordinate display
                VStack(alignment: .leading, spacing: 4) {
                    if let location = locationManager.currentLocation {
                        Text(formatCoordinate(location.coordinate))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white)

                        if let altitude = locationManager.currentAltitude {
                            Text(formatAltitude(altitude))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    } else {
                        Text("No GPS")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)

                Spacer()

                // Recording indicator
                if locationManager.isRecordingBreadcrumbs {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("REC")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text(locationManager.runningDistanceMeters > 0
                             ? formatDistance(locationManager.runningDistanceMeters)
                             : "0 m")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
    }

    // MARK: - Formatting Helpers

    private func formatCoordinate(_ coord: CLLocationCoordinate2D) -> String {
        switch settingsVM.settings.coordFormat {
        case .decimal:
            return String(format: "%.6f, %.6f", coord.latitude, coord.longitude)
        case .dms:
            return formatDMS(coord)
        case .mgrs:
            return formatMGRS(coord)
        case .utm:
            return formatUTM(coord)
        }
    }

    private func formatDMS(_ coord: CLLocationCoordinate2D) -> String {
        func toDMS(_ value: Double, isLat: Bool) -> String {
            let absolute = abs(value)
            let degrees = Int(absolute)
            let minutesDecimal = (absolute - Double(degrees)) * 60
            let minutes = Int(minutesDecimal)
            let seconds = (minutesDecimal - Double(minutes)) * 60

            let direction: String
            if isLat {
                direction = value >= 0 ? "N" : "S"
            } else {
                direction = value >= 0 ? "E" : "W"
            }

            return String(format: "%d°%02d'%05.2f\"%@", degrees, minutes, seconds, direction)
        }

        return "\(toDMS(coord.latitude, isLat: true)) \(toDMS(coord.longitude, isLat: false))"
    }

    private func formatMGRS(_ coord: CLLocationCoordinate2D) -> String {
        // Simplified MGRS - in production use a proper library
        return String(format: "%.4f, %.4f", coord.latitude, coord.longitude)
    }

    private func formatUTM(_ coord: CLLocationCoordinate2D) -> String {
        // Simplified UTM - in production use a proper library
        return String(format: "UTM: %.4f, %.4f", coord.latitude, coord.longitude)
    }

    private func formatAltitude(_ meters: Double) -> String {
        switch settingsVM.settings.unitSystem {
        case .metric:
            return String(format: "Alt: %.0f m", meters)
        case .imperial:
            return String(format: "Alt: %.0f ft", meters * 3.28084)
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        switch settingsVM.settings.unitSystem {
        case .metric:
            if meters >= 1000 {
                return String(format: "%.2f km", meters / 1000)
            }
            return String(format: "%.0f m", meters)
        case .imperial:
            let feet = meters * 3.28084
            if feet >= 5280 {
                return String(format: "%.2f mi", feet / 5280)
            }
            return String(format: "%.0f ft", feet)
        }
    }

    private func zoomFromSpan(_ span: MKCoordinateSpan) -> Double {
        // Approximate zoom level from span
        let maxSpan = max(span.latitudeDelta, span.longitudeDelta)
        return max(1, 20 - log2(maxSpan * 111))
    }
}

// MARK: - Peer Marker View (Blue Triangle)

struct PeerMarkerView: View {
    let peer: PeerPosition
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Blue triangle pointing down
                Image(systemName: "triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(180))

                // Callsign label
                Text(peer.callsign)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .cornerRadius(4)
            }
        }
    }
}

// MARK: - Peer Detail Sheet

struct PeerDetailSheet: View {
    let peer: PeerPosition
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var contactsVM = ContactsViewModel.shared
    @ObservedObject private var settingsVM = SettingsViewModel.shared

    @State private var showingFullProfile = false

    private var contact: ContactProfile? {
        contactsVM.contacts.first { $0.deviceId == peer.deviceId }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Identity") {
                    HStack {
                        Text("Callsign")
                        Spacer()
                        Text(peer.callsign)
                    }

                    if let nickname = contact?.nickname, !nickname.isEmpty {
                        HStack {
                            Text("Nickname")
                            Spacer()
                            Text(nickname)
                        }
                    }
                }

                Section("Location") {
                    HStack {
                        Text("Coordinates")
                        Spacer()
                        Text(CoordinateFormatter.format(
                            latitude: peer.latitude,
                            longitude: peer.longitude,
                            format: settingsVM.settings.coordFormat
                        ))
                        .font(.system(.body, design: .monospaced))
                    }

                    HStack {
                        Text("Last Seen")
                        Spacer()
                        Text(formatDate(peer.lastUpdated))
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button {
                        showingFullProfile = true
                    } label: {
                        HStack {
                            Label("View Full Profile", systemImage: "info.circle")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(peer.callsign)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingFullProfile) {
                PeerFullProfileSheet(peer: peer)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Peer Full Profile Sheet

struct PeerFullProfileSheet: View {
    let peer: PeerPosition
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var contactsVM = ContactsViewModel.shared
    @ObservedObject private var settingsVM = SettingsViewModel.shared

    private var contact: ContactProfile? {
        contactsVM.contacts.first { $0.deviceId == peer.deviceId }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Identity") {
                    HStack {
                        Text("Callsign")
                        Spacer()
                        Text(peer.callsign)
                            .foregroundColor(.secondary)
                    }

                    if let nickname = contact?.nickname, !nickname.isEmpty {
                        HStack {
                            Text("Nickname")
                            Spacer()
                            Text(nickname)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let fullName = contact?.fullName {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(fullName)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if contact?.company != nil || contact?.platoon != nil || contact?.squad != nil {
                    Section("Unit") {
                        if let company = contact?.company {
                            HStack {
                                Text("Company")
                                Spacer()
                                Text(company)
                                    .foregroundColor(.secondary)
                            }
                        }
                        if let platoon = contact?.platoon {
                            HStack {
                                Text("Platoon/Troop")
                                Spacer()
                                Text(platoon)
                                    .foregroundColor(.secondary)
                            }
                        }
                        if let squad = contact?.squad {
                            HStack {
                                Text("Squad")
                                Spacer()
                                Text(squad)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if let role = contact?.role, role != .none {
                    Section("Role") {
                        HStack {
                            Text("Position")
                            Spacer()
                            Text(role.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if contact?.mobile != nil || contact?.email != nil {
                    Section("Contact") {
                        if let mobile = contact?.mobile {
                            HStack {
                                Text("Phone")
                                Spacer()
                                Text(mobile)
                                    .foregroundColor(.secondary)
                            }
                        }
                        if let email = contact?.email {
                            HStack {
                                Text("Email")
                                Spacer()
                                Text(email)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("Location") {
                    HStack {
                        Text("Coordinates")
                        Spacer()
                        Text(CoordinateFormatter.format(
                            latitude: peer.latitude,
                            longitude: peer.longitude,
                            format: settingsVM.settings.coordFormat
                        ))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Last Updated")
                        Spacer()
                        Text(formatDate(peer.lastUpdated))
                            .foregroundColor(.secondary)
                    }
                }

                Section("Device") {
                    HStack {
                        Text("Device ID")
                        Spacer()
                        Text(String(peer.deviceId.prefix(12)) + "...")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Full Profile")
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Pin Marker View

struct PinMarkerView: View {
    let pin: NatoPin
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Image(systemName: pin.type.sfSymbol)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(pinColor)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )

                if !pin.title.isEmpty {
                    Text(pin.title)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(pinColor.opacity(0.8))
                        .cornerRadius(4)
                }
            }
        }
    }

    private var pinColor: Color {
        switch pin.type {
        case .infantry, .marine:
            return .red
        case .intelligence, .surveillance, .droneObserved:
            return .orange
        case .artillery:
            return .purple
        case .op:
            return .green
        case .photo:
            return .blue
        case .form7S, .formIFS:
            return .gray
        }
    }
}

// MARK: - Pin Detail Sheet

struct PinDetailSheet: View {
    let pin: NatoPin
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var pinsVM = PinsViewModel.shared
    @ObservedObject private var settingsVM = SettingsViewModel.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Location") {
                    HStack {
                        Text("Type")
                        Spacer()
                        Label(pin.type.label, systemImage: pin.type.sfSymbol)
                    }

                    HStack {
                        Text("Coordinates")
                        Spacer()
                        Text(formatCoordinate(pin.coordinate))
                            .font(.system(.body, design: .monospaced))
                    }
                }

                Section("Details") {
                    if !pin.title.isEmpty {
                        HStack {
                            Text("Title")
                            Spacer()
                            Text(pin.title)
                        }
                    }

                    if !pin.description.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                            Text(pin.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !pin.authorCallsign.isEmpty {
                        HStack {
                            Text("Author")
                            Spacer()
                            Text(pin.authorCallsign)
                        }
                    }

                    HStack {
                        Text("Created")
                        Spacer()
                        Text(formatDate(pin.createdAtMillis))
                            .foregroundColor(.secondary)
                    }
                }

                // Linked forms for OP pins
                if pin.type == .op {
                    let forms = pinsVM.getFormsForPin(pinId: pin.id, originDeviceId: pin.originDeviceId)
                    if !forms.isEmpty {
                        Section("Linked Forms (\(forms.count))") {
                            ForEach(forms) { form in
                                HStack {
                                    Text(form.formType)
                                    Spacer()
                                    Text(formatDate(form.submittedAtMillis))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        pinsVM.deletePin(pinId: pin.id)
                        dismiss()
                    } label: {
                        Label("Delete Pin", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(pin.title.isEmpty ? pin.type.label : pin.title)
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

    private func formatCoordinate(_ coord: CLLocationCoordinate2D) -> String {
        String(format: "%.6f, %.6f", coord.latitude, coord.longitude)
    }

    private func formatDate(_ millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(millis) / 1000)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Add Pin Sheet

struct AddPinSheet: View {
    let location: CLLocationCoordinate2D
    let onSave: (NatoPin) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var contactsVM = ContactsViewModel.shared

    @State private var selectedType: NatoType = .infantry
    @State private var title = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Pin Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(NatoType.allCases, id: \.self) { type in
                            Label(type.label, systemImage: type.sfSymbol)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Details") {
                    TextField("Title", text: $title)

                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Location") {
                    HStack {
                        Text("Latitude")
                        Spacer()
                        Text(String(format: "%.6f", location.latitude))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Longitude")
                        Spacer()
                        Text(String(format: "%.6f", location.longitude))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add Pin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePin()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func savePin() {
        let pin = NatoPin(
            id: PinsViewModel.shared.generatePinId(),
            latitude: location.latitude,
            longitude: location.longitude,
            type: selectedType,
            title: title,
            description: description,
            authorCallsign: contactsVM.myProfile?.callsign ?? "Unknown",
            originDeviceId: TransportCoordinator.shared.deviceId
        )
        onSave(pin)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    TacticalMapView()
}
