import SwiftUI
import MapKit

/// Main view of the app containing the map and navigation to other screens
/// Mirrors Android MapScreen functionality
public struct MainView: View {
    @ObservedObject private var mapVM = MapViewModel.shared
    @ObservedObject private var chatVM = ChatViewModel.shared
    @ObservedObject private var ordersVM = OrdersViewModel.shared
    @ObservedObject private var settingsVM = SettingsViewModel.shared

    // Sheet presentation state
    @State private var showingContacts = false
    @State private var showingChat = false
    @State private var showingSettings = false
    @State private var showingOrders = false
    @State private var showingProfile = false
    @State private var showingLayerMenu = false
    @State private var showingRoutes = false
    @State private var showingAddPin = false

    public init() {}

    // Location manager reference
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var pinsVM = PinsViewModel.shared

    public var body: some View {
        ZStack {
            // Map view
            mapView

            // Overlay controls
            VStack {
                // Top bar with controls
                topControlBar

                Spacer()

                // Bottom bar with navigation buttons
                bottomControlBar
            }

            // Right side map controls
            HStack {
                Spacer()
                VStack {
                    Spacer()
                    MapControlsView(
                        onCenterOnMe: {
                            if let position = locationManager.currentCoordinate {
                                mapVM.saveCameraPosition(
                                    lat: position.latitude,
                                    lng: position.longitude,
                                    zoom: mapVM.zoom,
                                    bearing: mapVM.mapBearing
                                )
                            }
                        },
                        onAddPin: {
                            showingAddPin = true
                        },
                        onShowRoutes: {
                            showingRoutes = true
                        }
                    )
                    Spacer()
                }
                .padding(.trailing, 8)
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            // Start location tracking
            locationManager.requestPermission()

            // Set broadcast interval from settings
            locationManager.setBroadcastInterval(settingsVM.gpsIntervalSeconds)
        }
        .sheet(isPresented: $showingContacts) {
            ContactBookScreen()
        }
        .sheet(isPresented: $showingChat) {
            ChatThreadsScreen()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsScreen()
        }
        .sheet(isPresented: $showingOrders) {
            OrdersListScreen()
        }
        .sheet(isPresented: $showingProfile) {
            ProfileScreen()
        }
        .sheet(isPresented: $showingRoutes) {
            RoutesListSheet()
        }
        .sheet(isPresented: $showingAddPin) {
            if let location = locationManager.currentCoordinate ?? mapVM.crosshairPosition {
                AddPinSheet(location: location) { pin in
                    pinsVM.addPin(pin)
                }
            }
        }
    }

    // MARK: - Map View

    private var mapView: some View {
        MapViewRepresentable(
            region: $mapVM.cameraRegion,
            followMode: mapVM.followMe,
            myPosition: mapVM.myPosition,
            peerPositions: Array(mapVM.peerPositions.values)
        )
    }

    // MARK: - Top Control Bar

    private var topControlBar: some View {
        HStack {
            // Left side: Connection status
            connectionStatusBadge

            Spacer()

            // Right side: Layer picker
            Button(action: { showingLayerMenu = true }) {
                Image(systemName: "square.3.layers.3d")
                    .font(.title2)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .popover(isPresented: $showingLayerMenu) {
                LayerMenuView()
                    .presentationCompactAdaptation(.popover)
            }
        }
        .padding(.horizontal)
        .padding(.top, 60)
    }

    // MARK: - Connection Status Badge

    private var connectionStatusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)

            Text(settingsVM.transportMode.rawValue)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private var connectionColor: Color {
        switch TransportCoordinator.shared.connectionState {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .gray
        case .error: return .red
        }
    }

    // MARK: - Bottom Control Bar

    private var bottomControlBar: some View {
        VStack(spacing: 12) {
            // Follow me and compass buttons
            HStack {
                // Follow me button
                Button(action: { mapVM.toggleFollowMe() }) {
                    Image(systemName: mapVM.followMe ? "location.fill" : "location")
                        .font(.title2)
                        .foregroundColor(mapVM.followMe ? .blue : .primary)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Spacer()

                // Compass / North up button
                Button(action: { mapVM.resetBearing() }) {
                    Image(systemName: "location.north.fill")
                        .font(.title2)
                        .rotationEffect(.degrees(mapVM.mapBearing))
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)

            // Main navigation bar
            HStack(spacing: 0) {
                // Contacts
                NavigationButton(
                    icon: "person.3.fill",
                    label: "Contacts",
                    action: { showingContacts = true }
                )

                // Chat
                NavigationButton(
                    icon: "bubble.left.and.bubble.right.fill",
                    label: "Chat",
                    badge: chatVM.totalUnreadCount,
                    action: { showingChat = true }
                )

                // Profile (center)
                NavigationButton(
                    icon: "person.crop.circle.fill",
                    label: "Profile",
                    isCenter: true,
                    action: { showingProfile = true }
                )

                // Orders
                NavigationButton(
                    icon: "doc.text.fill",
                    label: "Orders",
                    badge: ordersVM.unreadCount,
                    action: { showingOrders = true }
                )

                // Settings
                NavigationButton(
                    icon: "gearshape.fill",
                    label: "Settings",
                    action: { showingSettings = true }
                )
            }
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

// MARK: - Navigation Button

private struct NavigationButton: View {
    let icon: String
    let label: String
    var badge: Int = 0
    var isCenter: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(isCenter ? .title : .title2)
                        .foregroundColor(isCenter ? .blue : .primary)

                    if badge > 0 {
                        Text("\(min(badge, 99))")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 8, y: -4)
                    }
                }

                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Layer Menu View

private struct LayerMenuView: View {
    @ObservedObject private var settingsVM = SettingsViewModel.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Map Style")
                .font(.headline)
                .padding()

            Divider()

            ForEach(SettingsMapStyle.allCases, id: \.self) { style in
                Button(action: {
                    settingsVM.setMapStyle(style)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: iconForStyle(style))
                            .frame(width: 24)

                        Text(style.displayName)

                        Spacer()

                        if settingsVM.settings.mapStyle == style {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                }
                .foregroundColor(.primary)

                if style != SettingsMapStyle.allCases.last {
                    Divider()
                }
            }
        }
        .frame(width: 200)
    }

    private func iconForStyle(_ style: SettingsMapStyle) -> String {
        switch style {
        case .satellite: return "globe"
        case .terrain: return "mountain.2"
        case .streets: return "map"
        case .dark: return "moon.fill"
        }
    }
}

// Note: ProfileScreen is defined in ProfileScreen.swift

// MARK: - Map View Representable

struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let followMode: Bool
    let myPosition: CLLocationCoordinate2D?
    let peerPositions: [PeerPosition]

    // Access pins from ViewModel
    @ObservedObject private var pinsVM = PinsViewModel.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var settingsVM = SettingsViewModel.shared

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.setRegion(region, animated: false)

        // Apply map style
        updateMapType(mapView)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update map type based on settings
        updateMapType(mapView)

        // Update peer annotations
        updatePeerAnnotations(mapView)

        // Update pin annotations
        updatePinAnnotations(mapView)

        // Update breadcrumb overlay
        updateBreadcrumbOverlay(mapView)

        // Follow mode
        if followMode, let position = myPosition {
            let newRegion = MKCoordinateRegion(
                center: position,
                span: region.span
            )
            mapView.setRegion(newRegion, animated: true)
        }
    }

    private func updateMapType(_ mapView: MKMapView) {
        switch settingsVM.settings.mapStyle {
        case .satellite:
            mapView.mapType = .satellite
        case .terrain:
            mapView.mapType = .standard
        case .streets:
            mapView.mapType = .standard
        case .dark:
            mapView.mapType = .mutedStandard
        }
    }

    private func updatePeerAnnotations(_ mapView: MKMapView) {
        let existingPeers = mapView.annotations.compactMap { $0 as? PeerAnnotation }
        let existingIds = Set(existingPeers.map { $0.peerId })
        let newIds = Set(peerPositions.map { $0.deviceId })

        // Remove old annotations
        let toRemove = existingPeers.filter { !newIds.contains($0.peerId) }
        mapView.removeAnnotations(toRemove)

        // Add or update annotations
        for peer in peerPositions {
            if let existing = existingPeers.first(where: { $0.peerId == peer.deviceId }) {
                existing.coordinate = peer.coordinate
            } else {
                let annotation = PeerAnnotation(peer: peer)
                mapView.addAnnotation(annotation)
            }
        }
    }

    private func updatePinAnnotations(_ mapView: MKMapView) {
        let existingPins = mapView.annotations.compactMap { $0 as? PinAnnotation }
        let existingIds = Set(existingPins.map { $0.pinId })
        let newIds = Set(pinsVM.pins.map { $0.id })

        // Remove old annotations
        let toRemove = existingPins.filter { !newIds.contains($0.pinId) }
        mapView.removeAnnotations(toRemove)

        // Add or update annotations
        for pin in pinsVM.pins {
            if let existing = existingPins.first(where: { $0.pinId == pin.id }) {
                existing.coordinate = pin.coordinate
            } else {
                let annotation = PinAnnotation(pin: pin)
                mapView.addAnnotation(annotation)
            }
        }
    }

    private func updateBreadcrumbOverlay(_ mapView: MKMapView) {
        // Remove existing breadcrumb overlays
        let existingOverlays = mapView.overlays.filter { $0 is MKPolyline }
        mapView.removeOverlays(existingOverlays)

        // Add current breadcrumb trail if recording
        if locationManager.isRecordingBreadcrumbs && locationManager.breadcrumbPoints.count >= 2 {
            let coordinates = locationManager.breadcrumbPoints.map { $0.coordinate }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Handle user location
            if annotation is MKUserLocation {
                return nil
            }

            // Handle peer annotations
            if let peerAnnotation = annotation as? PeerAnnotation {
                let identifier = "PeerMarker"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if view == nil {
                    view = MKMarkerAnnotationView(annotation: peerAnnotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                } else {
                    view?.annotation = peerAnnotation
                }

                view?.markerTintColor = .systemBlue
                view?.glyphImage = UIImage(systemName: "person.fill")
                return view
            }

            // Handle pin annotations
            if let pinAnnotation = annotation as? PinAnnotation {
                let identifier = "PinMarker"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if view == nil {
                    view = MKMarkerAnnotationView(annotation: pinAnnotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                } else {
                    view?.annotation = pinAnnotation
                }

                view?.markerTintColor = pinAnnotation.markerColor
                view?.glyphImage = UIImage(systemName: pinAnnotation.glyphName)
                return view
            }

            return nil
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(parent.settingsVM.breadcrumbColor)
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Update region binding
            parent.region = mapView.region
        }
    }
}

// MARK: - Peer Annotation

class PeerAnnotation: NSObject, MKAnnotation {
    let peerId: String
    dynamic var coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?

    init(peer: PeerPosition) {
        self.peerId = peer.deviceId
        self.coordinate = peer.coordinate
        self.title = peer.callsign
        self.subtitle = nil
    }
}

// MARK: - Pin Annotation

class PinAnnotation: NSObject, MKAnnotation {
    let pinId: Int64
    let pinType: NatoType
    dynamic var coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?

    init(pin: NatoPin) {
        self.pinId = pin.id
        self.pinType = pin.type
        self.coordinate = pin.coordinate
        self.title = pin.title.isEmpty ? pin.type.label : pin.title
        self.subtitle = pin.description.isEmpty ? nil : pin.description
    }

    var glyphName: String {
        pinType.sfSymbol
    }

    var markerColor: UIColor {
        switch pinType {
        case .infantry, .marine:
            return .systemRed
        case .intelligence, .surveillance, .droneObserved:
            return .systemOrange
        case .artillery:
            return .systemPurple
        case .op:
            return .systemGreen
        case .photo:
            return .systemBlue
        case .form7S, .formIFS:
            return .systemGray
        }
    }
}

// MARK: - Preview

#Preview {
    MainView()
}
