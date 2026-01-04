import SwiftUI
import MapKit
import Photos

/// Main view of the app containing the map and overlay controls
/// Redesigned to match Android MapScreen layout with overlay-based navigation
public struct MainView: View {
    @ObservedObject private var mapVM = MapViewModel.shared
    @ObservedObject private var chatVM = ChatViewModel.shared
    @ObservedObject private var ordersVM = OrdersViewModel.shared
    @ObservedObject private var settingsVM = SettingsViewModel.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var pinsVM = PinsViewModel.shared
    @ObservedObject private var routesVM = RoutesViewModel.shared

    // Sheet presentation state
    @State private var showingContacts = false
    @State private var showingChat = false
    @State private var showingSettings = false
    @State private var showingOrders = false
    @State private var showingProfile = false
    @State private var showingRoutes = false
    @State private var showingAddPin = false
    @State private var showingAbout = false

    // Menu presentation state
    @State private var showingLayerMenu = false
    @State private var showingLightingMenu = false
    @State private var showingMessagingMenu = false

    // Long-press context menu state
    @State private var showingLongPressMenu = false
    @State private var longPressCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    @State private var longPressScreenPoint: CGPoint = .zero

    // Night vision state
    @State private var previousThemeMode: ThemeMode = .dark

    // Recording controls
    @State private var showingRecordingControls = false

    // Crosshair state
    @State private var crosshairOffset: CGSize = .zero
    @State private var showingCoordinateInput = false
    @State private var coordinateInputText = ""
    @State private var coordinateInputError: String? = nil

    // User location screen position (updated by timer for smooth line rendering)
    @State private var userLocationScreenPoint: CGPoint? = nil

    // Timer for smooth crosshair line updates
    private let lineUpdateTimer = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()

    // Pin selection state
    @State private var selectedPin: NatoPin? = nil
    @State private var showingPinActionSheet = false
    @State private var showingPinDetails = false

    // Form sheet state
    @State private var showingSevenSForm = false
    @State private var showingIFSForm = false
    @State private var showingPhotoPicker = false

    // Share sheet for saving photos
    @State private var shareSheetImage: UIImage? = nil
    @State private var showingShareSheet = false

    public init() {}

    /// Key for task ID based on crosshair position (for elevation fetching)
    private var crosshairPositionKey: String {
        guard let pos = mapVM.crosshairPosition else { return "none" }
        // Round to 4 decimal places (~11m precision) to avoid excessive API calls
        return String(format: "%.4f,%.4f", pos.latitude, pos.longitude)
    }

    /// Fetch elevation for crosshair position using MapTiler or Open-Elevation API
    private func fetchCrosshairElevation(latitude: Double, longitude: Double) async -> Double? {
        let apiKey = settingsVM.mapTilerSettings.apiKey

        // Build URLs to try
        var urls: [String] = []

        // MapTiler API (if key provided)
        if !apiKey.isEmpty {
            let cleanKey = apiKey.replacingOccurrences(of: "pk.", with: "").trimmingCharacters(in: .whitespaces)
            urls.append("https://api.maptiler.com/elevation/point.json?key=\(cleanKey)&lat=\(latitude)&lon=\(longitude)&units=m")
        }

        // Open-Elevation (public fallback)
        urls.append("https://api.open-elevation.com/api/v1/lookup?locations=\(latitude),\(longitude)")

        // Try each URL
        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else { continue }

                if let elevation = parseElevation(from: data) {
                    return elevation
                }
            } catch {
                continue
            }
        }
        return nil
    }

    /// Parse elevation from API response
    private func parseElevation(from data: Data) -> Double? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // MapTiler plain JSON: { "elevation": 123.4, ... }
        if let elevation = json["elevation"] as? Double {
            return elevation
        }

        // MapTiler GeoJSON: features[0].properties.elevation
        if let features = json["features"] as? [[String: Any]],
           let first = features.first,
           let properties = first["properties"] as? [String: Any],
           let elevation = properties["elevation"] as? Double {
            return elevation
        }

        // Open-Elevation: { "results": [ { "elevation": 123, ... } ] }
        if let results = json["results"] as? [[String: Any]],
           let first = results.first,
           let elevation = first["elevation"] as? Double {
            return elevation
        }

        return nil
    }

    public var body: some View {
        ZStack {
            // Full-screen map (background)
            mapView

            // Line from my position to crosshair (only when not following)
            if !mapVM.followMe {
                crosshairLineOverlay
            }

            // Crosshair overlay at center (only when not following)
            if !mapVM.followMe {
                crosshairOverlay
            }

            // Long-press context menu overlay
            if showingLongPressMenu {
                longPressMenuOverlay
            }

            // Night vision overlay (when enabled)
            if settingsVM.themeMode == .nightVision {
                NightVisionOverlay(
                    color: settingsVM.nightVisionColor,
                    alpha: settingsVM.nightDimmerAlpha
                )
            }

            // UI Overlays
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                let topPadding: CGFloat = isLandscape ? 16 : 48
                let sidePadding: CGFloat = isLandscape ? 48 : max(32, geometry.safeAreaInsets.leading)

                VStack(spacing: 0) {
                    // Top control panel (Layers, Lighting, Messaging)
                    topControlPanel
                        .padding(.top, geometry.safeAreaInsets.top + topPadding)
                        .padding(.horizontal, sidePadding)

                    Spacer()

                    // HUD overlay at bottom-left
                    fullHudOverlay
                        .padding(.horizontal, sidePadding)
                        .padding(.bottom, max(32, geometry.safeAreaInsets.bottom))
                }
            }

            // Bottom-right map controls
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    mapControlButtons
                        .padding(.trailing, 32)
                        .padding(.bottom, 100)
                }
            }

            // Compass and Heading HUD (top-left, below top bar)
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                let topPadding: CGFloat = isLandscape ? 16 : 48
                let sidePadding: CGFloat = isLandscape ? 48 : max(32, geometry.safeAreaInsets.leading)

                VStack(alignment: .center, spacing: 8) {
                    Spacer()
                        .frame(height: geometry.safeAreaInsets.top + topPadding + 68)

                    // Compass needle showing north
                    compassNeedleView

                    // Heading angle display
                    headingAngleView
                }
                .padding(.leading, sidePadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .ignoresSafeArea(edges: .all)
        .onAppear {
            // Reset centering flag so we center on user with 20km radius
            mapVM.resetInitialCentering()

            locationManager.requestPermission()
            locationManager.setBroadcastInterval(settingsVM.gpsIntervalSeconds)
            locationManager.startTracking()
        }
        .task(id: crosshairPositionKey) {
            // Fetch elevation when crosshair position changes
            guard let pos = mapVM.crosshairPosition else {
                mapVM.updateCrosshairAltitude(nil)
                return
            }
            let elevation = await fetchCrosshairElevation(latitude: pos.latitude, longitude: pos.longitude)
            mapVM.updateCrosshairAltitude(elevation)
        }
        .onReceive(locationManager.$currentLocation) { location in
            // Center map on user's position with 20km radius on first location update
            if let location = location, !mapVM.hasCenteredInitially {
                if let mapView = MapViewRepresentable.mapViewReference {
                    // Calculate bounds for 20km radius (like Android implementation)
                    let radiusMeters = 20_000.0
                    let bounds = regionForRadius(center: location.coordinate, radiusMeters: radiusMeters)
                    mapView.setRegion(bounds, animated: true)
                    mapVM.markInitiallyCentered()
                }
            }
        }
        // Sheet presentations
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
        .sheet(isPresented: $showingAbout) {
            AboutScreen()
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
        .sheet(isPresented: $showingLightingMenu) {
            LightingControlMenu(
                isPresented: $showingLightingMenu,
                themeMode: $settingsVM.themeMode,
                previousThemeMode: $previousThemeMode,
                nightDimmerAlpha: $settingsVM.nightDimmerAlpha,
                nightVisionColor: $settingsVM.nightVisionColor
            )
            .presentationDetents([.medium, .large])
        }
        // Pin details sheet
        .sheet(isPresented: $showingPinDetails) {
            if let pin = selectedPin {
                PinViewDialog(
                    pin: pin,
                    isPresented: $showingPinDetails,
                    coordMode: settingsVM.settings.coordFormat == .mgrs ? .mgrs : .latLon,
                    onSaveToPhotos: { base64String in
                        savePhotoToLibrary(base64String: base64String)
                    },
                    onSaveToFiles: { base64String in
                        savePhotoToFiles(base64String: base64String)
                    },
                    onEdit: {
                        showingPinDetails = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingPinActionSheet = true
                        }
                    },
                    onDelete: {
                        pinsVM.deletePin(pinId: pin.id)
                        showingPinDetails = false
                    }
                )
            }
        }
        .confirmationDialog(
            selectedPin?.title.isEmpty == false ? selectedPin!.title : (selectedPin?.type.label ?? "Pin Options"),
            isPresented: $showingPinActionSheet,
            titleVisibility: .visible
        ) {
            if let pin = selectedPin {
                Button("View") {
                    showingPinDetails = true
                }
                Button("Edit") {
                    // TODO: Open edit pin sheet
                }
                Button("Delete", role: .destructive) {
                    pinsVM.deletePin(pinId: pin.id)
                }
                Button("Cancel", role: .cancel) {}
            }
        } message: {
            if let pin = selectedPin {
                Text(formatCoordinate(pin.coordinate))
            }
        }
        // 7S Form sheet
        .sheet(isPresented: $showingSevenSForm) {
            SevenSFormSheet(
                draft: SevenSFormData.createDraft(
                    reporter: settingsVM.callsign,
                    latitude: longPressCoordinate.latitude,
                    longitude: longPressCoordinate.longitude,
                    placeText: formatCoordinate(longPressCoordinate)
                )
            ) { formData in
                // Create a pin with form data
                let pin = NatoPin(
                    id: pinsVM.generatePinId(),
                    latitude: formData.latitude ?? longPressCoordinate.latitude,
                    longitude: formData.longitude ?? longPressCoordinate.longitude,
                    type: .form7S,
                    title: "7S Report",
                    description: format7SDescription(formData),
                    authorCallsign: formData.reporter,
                    originDeviceId: TransportCoordinator.shared.deviceId
                )
                pinsVM.addPin(pin)
            }
        }
        // IFS Form sheet
        .sheet(isPresented: $showingIFSForm) {
            IndirectFireFormSheet(
                draft: IndirectFireFormData.createDraft(
                    observer: settingsVM.callsign,
                    observerLatitude: locationManager.currentCoordinate?.latitude,
                    observerLongitude: locationManager.currentCoordinate?.longitude,
                    observerPositionText: locationManager.currentCoordinate.map { formatCoordinate($0) },
                    targetLatitude: longPressCoordinate.latitude,
                    targetLongitude: longPressCoordinate.longitude
                ),
                targetCoordinateText: formatCoordinate(longPressCoordinate)
            ) { formData in
                // Create a pin with form data
                let pin = NatoPin(
                    id: pinsVM.generatePinId(),
                    latitude: formData.targetLatitude ?? longPressCoordinate.latitude,
                    longitude: formData.targetLongitude ?? longPressCoordinate.longitude,
                    type: .formIFS,
                    title: "IFS Request",
                    description: formatIFSDescription(formData),
                    authorCallsign: formData.observer,
                    originDeviceId: TransportCoordinator.shared.deviceId
                )
                pinsVM.addPin(pin)
            }
        }
        // Photo picker sheet
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoCaptureView(coordinate: longPressCoordinate) { image, location, subject, description in
                // Handle the captured photo with location, subject, and description
                saveGeotaggedPhoto(image: image, location: location, subject: subject, description: description)
            }
        }
        // Share sheet for saving photos to Files
        .sheet(isPresented: $showingShareSheet) {
            if let image = shareSheetImage {
                ShareSheet(items: [image])
            }
        }
    }

    // MARK: - Form Description Formatters

    private func format7SDescription(_ formData: SevenSFormData) -> String {
        """
        Date/Time: \(formData.dateTime)
        Place: \(formData.place)
        Force Size: \(formData.forceSize)
        Type: \(formData.type)
        Occupation: \(formData.occupation)
        Symbols: \(formData.symbols)
        Reporter: \(formData.reporter)
        """
    }

    private func formatIFSDescription(_ formData: IndirectFireFormData) -> String {
        var description = """
        Observer: \(formData.observer)
        Request: \(formData.requestType.displayName)
        Target: \(formData.targetDescription)
        Observer Pos: \(formData.observerPosition)
        Enemy Forces: \(formData.enemyForces)
        Enemy Activity: \(formData.enemyActivity)
        Terrain: \(formData.targetTerrain)
        """
        if let width = formData.widthMeters {
            description += "\nWidth: \(width)m"
        }
        if let angle = formData.angleOfViewMils {
            description += "\nAngle: \(angle) mils"
        }
        if let distance = formData.distanceMeters {
            description += "\nDistance: \(distance)m"
        }
        return description
    }

    private func saveGeotaggedPhoto(image: UIImage, location: CLLocationCoordinate2D?, subject: String, description: String) {
        guard let coord = location ?? Optional(longPressCoordinate) else { return }

        let title = subject.isEmpty ? "Photo" : subject
        let desc = description.isEmpty ? "Photo taken at \(formatCoordinate(coord))" : description

        // Convert image to base64 (compressed JPEG)
        let photoBase64: String?
        if let imageData = image.jpegData(compressionQuality: 0.7) {
            photoBase64 = imageData.base64EncodedString()
        } else {
            photoBase64 = nil
        }

        let pin = NatoPin(
            id: pinsVM.generatePinId(),
            latitude: coord.latitude,
            longitude: coord.longitude,
            type: .photo,
            title: title,
            description: desc,
            authorCallsign: settingsVM.callsign,
            originDeviceId: TransportCoordinator.shared.deviceId,
            photoUri: photoBase64
        )
        pinsVM.addPin(pin)
    }

    private func savePhotoToLibrary(base64String: String) {
        guard let imageData = Data(base64Encoded: base64String),
              let image = UIImage(data: imageData) else { return }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        }
    }

    private func savePhotoToFiles(base64String: String) {
        guard let imageData = Data(base64Encoded: base64String),
              let image = UIImage(data: imageData) else { return }

        shareSheetImage = image
        showingShareSheet = true
    }

    // MARK: - Map View

    private var mapView: some View {
        MapViewRepresentable(
            region: $mapVM.cameraRegion,
            followMode: mapVM.followMe,
            myPosition: mapVM.myPosition,
            peerPositions: Array(mapVM.peerPositions.values),
            onLongPress: { coordinate, screenPoint in
                longPressCoordinate = coordinate
                longPressScreenPoint = screenPoint
                showingLongPressMenu = true
            },
            onPinSelected: { pin in
                selectedPin = pin
                showingPinActionSheet = true
            },
            onUserLocationScreenUpdate: { point in
                userLocationScreenPoint = point
            },
            onUserDraggedMap: {
                // User dragged the map - disable follow mode and show crosshair
                if mapVM.followMe {
                    mapVM.setFollowMe(false)
                }
            }
        )
    }

    // MARK: - Top Control Panel (Android-style)

    private var topControlPanel: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left side: Map and Lighting controls
            HStack(spacing: 8) {
                // Layers menu button
                layersMenuButton

                // Lighting control button
                lightingMenuButton
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()

            // Right side: LAN, Messaging, Pins, and Settings
            HStack(spacing: 8) {
                // LAN menu (contains Contact Book and seen devices)
                lanMenuButton

                // Messaging menu button
                messagingMenuButton

                // Pins menu button
                pinsMenuButton

                // Settings menu (contains My Profile, Settings, About)
                settingsMenuButton
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Layers Menu Button

    private var layersMenuButton: some View {
        Menu {
            ForEach(MapStyle.allCases, id: \.self) { style in
                Button {
                    settingsVM.setFullMapStyle(style)
                } label: {
                    HStack {
                        Label(style.displayName, systemImage: style.icon)
                        if settingsVM.currentMapStyle == style {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            Menu("Recorded Routes") {
                Button {
                    showingRecordingControls = true
                } label: {
                    Label(
                        locationManager.isRecordingBreadcrumbs ? "Stop Recording" : "Start Recording",
                        systemImage: locationManager.isRecordingBreadcrumbs ? "stop.fill" : "record.circle"
                    )
                }

                Button {
                    showingRoutes = true
                } label: {
                    Label("View Routes", systemImage: "list.bullet")
                }
            }

            Menu("Planned Routes") {
                Button {
                    // TODO: Start route planning mode
                } label: {
                    Label("Plan Route", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                }

                Button {
                    showingRoutes = true
                } label: {
                    Label("View Routes", systemImage: "list.bullet")
                }
            }
        } label: {
            Image(systemName: "map.fill")
                .font(.title2)
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
        }
        .confirmationDialog("Breadcrumb Recording", isPresented: $showingRecordingControls) {
            if locationManager.isRecordingBreadcrumbs {
                Button("Stop Recording") {
                    if let route = locationManager.stopRecordingBreadcrumbs() {
                        routesVM.addBreadcrumbRoute(route)
                    }
                }
            } else {
                Button("Start Recording") {
                    locationManager.startRecordingBreadcrumbs()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Lighting Menu Button

    private var lightingMenuButton: some View {
        Button {
            showingLightingMenu = true
        } label: {
            Image(systemName: lightingIcon)
                .font(.title2)
                .foregroundColor(lightingIconColor)
                .frame(width: 44, height: 44)
        }
    }

    private var lightingIcon: String {
        if TorchManager.shared.isEnabled {
            return "flashlight.on.fill"
        } else if settingsVM.themeMode == .nightVision {
            return "moon.fill"
        } else {
            return "sun.max.fill"
        }
    }

    private var lightingIconColor: Color {
        if TorchManager.shared.isEnabled {
            return .yellow
        } else if settingsVM.themeMode == .nightVision {
            return settingsVM.nightVisionColor.color
        } else {
            return .primary
        }
    }

    // MARK: - Messaging Menu Button

    private var messagingMenuButton: some View {
        MessagingMenuButton(
            onOpenChat: { showingChat = true },
            onCreateOBOOrder: { /* TODO: Create OBO order */ },
            onCreateFivePOrder: { /* TODO: Create 5P order */ },
            onListOrders: { showingOrders = true },
            onCreatePedars: { /* TODO: Create PEDARS */ },
            onListPedars: { /* TODO: List PEDARS */ },
            onCreateMist: { /* TODO: Create MIST */ },
            onListMist: { /* TODO: List MIST */ },
            onCreateMethane: { /* TODO: Create METHANE */ },
            onListMethane: { /* TODO: List METHANE */ }
        )
    }

    // MARK: - LAN Menu Button

    private var lanMenuButton: some View {
        Menu {
            // Contact Book
            Button {
                showingContacts = true
            } label: {
                Label("Contact Book", systemImage: "person.3.fill")
            }

            Divider()

            // Seen Devices section
            let visibleContacts = ContactsViewModel.shared.contacts.filter {
                !ContactsViewModel.shared.blockedDeviceIds.contains($0.deviceId)
            }

            if visibleContacts.isEmpty {
                Text("No devices seen")
            } else {
                ForEach(visibleContacts.prefix(10), id: \.deviceId) { contact in
                    Button {
                        // Could navigate to contact detail
                    } label: {
                        Label(
                            contact.callsign ?? String(contact.deviceId.prefix(8)),
                            systemImage: contact.isOnline ? "circle.fill" : "circle"
                        )
                    }
                }

                if visibleContacts.count > 10 {
                    Button {
                        showingContacts = true
                    } label: {
                        Text("View all \(visibleContacts.count) devices...")
                    }
                }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "wifi")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)

                // Badge for online contacts count
                let onlineCount = ContactsViewModel.shared.contacts.filter { $0.isOnline }.count
                if onlineCount > 0 {
                    Text("\(min(onlineCount, 99))")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.green)
                        .clipShape(Circle())
                        .offset(x: 6, y: -2)
                }
            }
        }
    }

    // MARK: - Pins Menu Button

    private var pinsMenuButton: some View {
        Menu {
            // Synchronise pins
            Button {
                // Request all pins from network
                TransportCoordinator.shared.requestAllPins(callsign: settingsVM.callsign)
            } label: {
                Label("Synchronise", systemImage: "arrow.triangle.2.circlepath")
            }

            // Reset all pins
            Button(role: .destructive) {
                pinsVM.clearAllPins()
            } label: {
                Label("Reset All Pins", systemImage: "trash")
            }

            // Broadcast my position
            Button {
                if let position = locationManager.currentCoordinate {
                    TransportCoordinator.shared.publishPosition(
                        callsign: settingsVM.callsign,
                        latitude: position.latitude,
                        longitude: position.longitude
                    )
                }
            } label: {
                Label("Broadcast My Position", systemImage: "antenna.radiowaves.left.and.right")
            }

            Divider()

            // List of all pins
            if pinsVM.pins.isEmpty {
                Text("No pins")
                    .foregroundColor(.secondary)
            } else {
                ForEach(pinsVM.pins, id: \.id) { pin in
                    Button {
                        // Center map on this pin
                        mapVM.saveCameraPosition(
                            lat: pin.latitude,
                            lng: pin.longitude,
                            zoom: max(mapVM.zoom, 15),
                            bearing: mapVM.mapBearing
                        )
                        mapVM.setFollowMe(false)
                    } label: {
                        Label(
                            pin.title.isEmpty ? pin.type.label : pin.title,
                            systemImage: pin.type.sfSymbol
                        )
                    }
                }
            }
        } label: {
            Image(systemName: "mappin.and.ellipse")
                .font(.title2)
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
        }
    }

    // MARK: - Settings Menu Button

    private var settingsMenuButton: some View {
        Menu {
            // My Profile
            Button {
                showingProfile = true
            } label: {
                Label("My Profile", systemImage: "person.crop.circle.fill")
            }

            // Settings
            Button {
                showingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

            Divider()

            // About
            Button {
                showingAbout = true
            } label: {
                Label("About", systemImage: "info.circle")
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.title2)
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
        }
    }

    // MARK: - Map Control Buttons (Bottom-Right, Android-style)

    private var mapControlButtons: some View {
        VStack(spacing: 12) {
            // Center/Follow button - uses MyLocationIcon matching Android
            Button {
                // Enable follow mode and reset crosshair
                crosshairOffset = .zero
                mapVM.updateCrosshairPosition(nil)
                mapVM.setFollowMe(true)
            } label: {
                MyLocationIcon(
                    size: 24,
                    color: mapVM.followMe ? .blue : .primary
                )
                .frame(width: 48, height: 48)
                .background(mapVM.followMe ? Color.blue.opacity(0.2) : Color.clear)
                .clipShape(Circle())
            }

            // Zoom in button
            MapControlButton(icon: "plus") {
                if let mapView = MapViewRepresentable.mapViewReference {
                    let currentZoom = mapView.region.span.latitudeDelta
                    let newSpan = max(currentZoom / 2.0, 0.001)  // Zoom in (smaller span)
                    let newRegion = MKCoordinateRegion(
                        center: mapView.centerCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: newSpan, longitudeDelta: newSpan)
                    )
                    mapView.setRegion(newRegion, animated: true)
                }
            }

            // Zoom out button
            MapControlButton(icon: "minus") {
                if let mapView = MapViewRepresentable.mapViewReference {
                    let currentZoom = mapView.region.span.latitudeDelta
                    let newSpan = min(currentZoom * 2.0, 180.0)  // Zoom out (larger span)
                    let newRegion = MKCoordinateRegion(
                        center: mapView.centerCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: newSpan, longitudeDelta: newSpan)
                    )
                    mapView.setRegion(newRegion, animated: true)
                }
            }

            // Recording button - video recorder style matching Android
            if locationManager.isRecordingBreadcrumbs {
                VStack(spacing: 4) {
                    Button {
                        if let route = locationManager.stopRecordingBreadcrumbs() {
                            routesVM.addBreadcrumbRoute(route)
                        }
                    } label: {
                        RecordButtonIcon(isRecording: true, size: 48)
                    }

                    Text(formatRecordingDuration())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(4)
                }
            } else {
                Button {
                    locationManager.startRecordingBreadcrumbs()
                } label: {
                    RecordButtonIcon(isRecording: false, size: 48)
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Compass Needle View

    private var compassNeedleView: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 44, height: 44)

            // Compass needle pointing north
            // Rotate based on device heading (negative because we want to show where north is)
            Image(systemName: "location.north.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.red)
                .rotationEffect(.degrees(-(locationManager.currentHeadingDegrees ?? 0)))
        }
        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }

    // MARK: - Heading Angle View

    private var headingAngleView: some View {
        let heading = locationManager.currentHeadingDegrees ?? 0
        let cardinalDirection = headingToCardinal(heading)
        let useMils = settingsVM.settings.coordFormat == .mgrs

        return HStack(spacing: 4) {
            Image(systemName: "arrow.up")
                .font(.caption)
                .foregroundColor(.primary)

            if useMils {
                // Military format: show mils (6400 mils = 360°)
                let mils = heading * (6400.0 / 360.0)
                Text(String(format: "%.0f mils", mils))
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
            } else {
                Text(String(format: "%.0f°", heading))
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
            }

            Text(cardinalDirection)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }

    private func headingToCardinal(_ heading: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((heading + 22.5) / 45.0) % 8
        return directions[index]
    }

    // MARK: - Crosshair Line Overlay (SwiftUI for instant updates)

    private var crosshairLineOverlay: some View {
        GeometryReader { geometry in
            let screenCenter = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let crosshairScreenPos = CGPoint(
                x: screenCenter.x + crosshairOffset.width,
                y: screenCenter.y + crosshairOffset.height
            )

            // Use the timer-updated screen point for smooth rendering
            let startPoint: CGPoint = {
                guard let userPoint = userLocationScreenPoint else {
                    return screenCenter
                }

                // Check if the point is within the visible screen area
                let screenBounds = CGRect(origin: .zero, size: geometry.size)
                if screenBounds.contains(userPoint) {
                    return userPoint
                }

                // User is off-screen - calculate direction and draw to edge
                let dirX = userPoint.x - crosshairScreenPos.x
                let dirY = userPoint.y - crosshairScreenPos.y
                let magnitude = sqrt(dirX * dirX + dirY * dirY)

                if magnitude > 0 {
                    let normX = dirX / magnitude
                    let normY = dirY / magnitude

                    // Find intersection with screen edge
                    var scale: CGFloat = magnitude

                    // Check left/right edges
                    if normX > 0 {
                        let rightDist = (geometry.size.width - crosshairScreenPos.x) / normX
                        scale = min(scale, rightDist)
                    } else if normX < 0 {
                        let leftDist = crosshairScreenPos.x / (-normX)
                        scale = min(scale, leftDist)
                    }

                    // Check top/bottom edges
                    if normY > 0 {
                        let bottomDist = (geometry.size.height - crosshairScreenPos.y) / normY
                        scale = min(scale, bottomDist)
                    } else if normY < 0 {
                        let topDist = crosshairScreenPos.y / (-normY)
                        scale = min(scale, topDist)
                    }

                    return CGPoint(
                        x: crosshairScreenPos.x + normX * scale,
                        y: crosshairScreenPos.y + normY * scale
                    )
                }

                return screenCenter
            }()

            Path { path in
                path.move(to: startPoint)
                path.addLine(to: crosshairScreenPos)
            }
            .stroke(Color.blue, lineWidth: 2)
        }
        .allowsHitTesting(false)
        .onReceive(lineUpdateTimer) { _ in
            // Update user location screen point for smooth line rendering
            // Only update when not in follow mode
            guard !mapVM.followMe,
                  let mapView = MapViewRepresentable.mapViewReference else {
                return
            }

            // Update user location screen point for line drawing
            // Only update if the value has changed significantly to reduce UI churn
            if let userLocation = mapView.userLocation.location?.coordinate {
                let newPoint = mapView.convert(userLocation, toPointTo: nil)
                if let current = userLocationScreenPoint {
                    let dx = abs(newPoint.x - current.x)
                    let dy = abs(newPoint.y - current.y)
                    // Only update if moved more than 1 pixel
                    if dx > 1 || dy > 1 {
                        userLocationScreenPoint = newPoint
                    }
                } else {
                    userLocationScreenPoint = newPoint
                }
            }

            // Update crosshair position based on map center + offset
            // This ensures the HUD shows accurate crosshair coordinates
            if abs(crosshairOffset.width) < 1 && abs(crosshairOffset.height) < 1 {
                let mapCenter = mapView.centerCoordinate
                // Only update if position changed significantly
                if let current = mapVM.crosshairPosition {
                    let latDiff = abs(mapCenter.latitude - current.latitude)
                    let lonDiff = abs(mapCenter.longitude - current.longitude)
                    if latDiff > 0.000001 || lonDiff > 0.000001 {
                        mapVM.updateCrosshairPosition(mapCenter)
                    }
                } else {
                    mapVM.updateCrosshairPosition(mapCenter)
                }
            }
        }
    }

    // MARK: - Crosshair Overlay

    private var crosshairOverlay: some View {
        ZStack {
            // Invisible hit target for gestures (larger than crosshair)
            Color.clear
                .frame(width: 80, height: 80)
                .contentShape(Rectangle())

            // Crosshair visual
            CrosshairOverlay(color: .red, size: 40, lineWidth: 2)
        }
        .offset(crosshairOffset)
        .gesture(crosshairGesture)
        .onTapGesture(count: 2) {
            // Double-tap: reset crosshair to center and return to my position
            withAnimation(.easeInOut(duration: 0.2)) {
                crosshairOffset = .zero
                mapVM.updateCrosshairPosition(nil)
            }
            // Center on my position
            if let myPos = locationManager.currentCoordinate {
                mapVM.saveCameraPosition(
                    lat: myPos.latitude,
                    lng: myPos.longitude,
                    zoom: mapVM.zoom,
                    bearing: mapVM.mapBearing
                )
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            // Long-press: show coordinate input dialog
            coordinateInputText = ""
            coordinateInputError = nil
            showingCoordinateInput = true
        }
        .sheet(isPresented: $showingCoordinateInput) {
            CoordinateInputDialog(
                coordMode: settingsVM.settings.coordFormat == .mgrs ? .mgrs : .latLon,
                text: $coordinateInputText,
                isPresented: $showingCoordinateInput,
                error: coordinateInputError,
                onGoThere: { text in
                    handleCoordinateInput(text)
                }
            )
            .presentationDetents([.medium])
        }
    }

    private func handleCoordinateInput(_ text: String) {
        // Parse coordinate string
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        // Try to parse as decimal lat/lon (e.g., "59.32941, 18.06857")
        let components = trimmed.replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .map { String($0) }

        if components.count >= 2,
           let lat = Double(components[0]),
           let lon = Double(components[1]),
           lat >= -90, lat <= 90,
           lon >= -180, lon <= 180 {
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            mapVM.updateCrosshairPosition(coordinate)
            mapVM.saveCameraPosition(
                lat: coordinate.latitude,
                lng: coordinate.longitude,
                zoom: mapVM.zoom,
                bearing: mapVM.mapBearing
            )
            withAnimation {
                crosshairOffset = .zero
            }
            showingCoordinateInput = false
        } else {
            coordinateInputError = "Invalid coordinates. Use format: 59.32941, 18.06857"
        }
    }

    private var crosshairGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                crosshairOffset = CGSize(
                    width: value.translation.width,
                    height: value.translation.height
                )
                // Update crosshair position in real-time based on offset
                updateCrosshairCoordinate(from: crosshairOffset)
            }
            .onEnded { value in
                // Keep the offset and update crosshair position
                updateCrosshairCoordinate(from: crosshairOffset)
            }
    }

    /// Calculate the crosshair coordinate based on its screen offset from center
    private func updateCrosshairCoordinate(from offset: CGSize) {
        // If offset is essentially zero, crosshair is centered
        if abs(offset.width) < 1 && abs(offset.height) < 1 {
            mapVM.updateCrosshairPosition(nil)
            return
        }

        // Get map center and span
        let region = mapVM.cameraRegion
        let center = region.center

        // Approximate screen size (typical iPhone map view area)
        // We use a reasonable estimate since we don't have actual view dimensions here
        let screenWidth: CGFloat = 393  // iPhone 14 Pro width
        let screenHeight: CGFloat = 600 // Approximate map view height

        // Calculate degrees per pixel
        let latPerPixel = region.span.latitudeDelta / screenHeight
        let lonPerPixel = region.span.longitudeDelta / screenWidth

        // Calculate new coordinate
        // Note: latitude increases going north (up), but screen Y increases going down
        let newLat = center.latitude - (Double(offset.height) * latPerPixel)
        let newLon = center.longitude + (Double(offset.width) * lonPerPixel)

        let newCoordinate = CLLocationCoordinate2D(latitude: newLat, longitude: newLon)
        mapVM.updateCrosshairPosition(newCoordinate)
    }

    // MARK: - Full HUD Overlay (Bottom-Left, Android-style)

    private var fullHudOverlay: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                HudOverlay(
                    myPosition: locationManager.currentCoordinate,
                    crosshairPosition: mapVM.crosshairPosition,
                    coordMode: settingsVM.settings.coordFormat == .mgrs ? .mgrs : .latLon,
                    myAltitudeMeters: locationManager.currentAltitude,
                    crosshairAltitudeMeters: mapVM.crosshairAltitudeMeters,
                    unitSystem: currentUnitSystem
                )

                // Recording indicator
                if locationManager.isRecordingBreadcrumbs {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("REC")
                            .font(.caption2)
                            .fontWeight(.bold)
                        Text(formatDistance(locationManager.runningDistanceMeters))
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .padding(.top, 8)
                }
            }

            Spacer()
        }
    }

    // MARK: - Long-Press Context Menu Overlay

    private var longPressMenuOverlay: some View {
        LongPressMenuOverlay(
            isPresented: $showingLongPressMenu,
            coordinate: longPressCoordinate,
            coordMode: settingsVM.settings.coordFormat == .mgrs ? .mgrs : .latLon,
            onPinChosen: { pinType in
                let pin = NatoPin(
                    id: pinsVM.generatePinId(),
                    latitude: longPressCoordinate.latitude,
                    longitude: longPressCoordinate.longitude,
                    type: pinType,
                    title: "",
                    description: "",
                    authorCallsign: ContactsViewModel.shared.myProfile?.callsign ?? "Unknown",
                    originDeviceId: TransportCoordinator.shared.deviceId
                )
                pinsVM.addPin(pin)
            },
            onFormChosen: { formType in
                switch formType {
                case .sevenS:
                    showingSevenSForm = true
                case .ifs:
                    showingIFSForm = true
                }
            },
            onPhotoChosen: {
                showingPhotoPicker = true
            },
            onCopyCoordinates: {
                let coordString = formatCoordinate(longPressCoordinate)
                UIPasteboard.general.string = coordString
            }
        )
    }

    // MARK: - Unit System Helper

    private var currentUnitSystem: UnitSystem {
        switch settingsVM.settings.unitSystem {
        case .metric: return .metric
        case .imperial: return .imperial
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
            return MapCoordinateUtils.toMgrs(lat: coord.latitude, lon: coord.longitude)
        case .utm:
            // UTM uses same zone calculation as MGRS but different format
            return MapCoordinateUtils.toMgrs(lat: coord.latitude, lon: coord.longitude)
        }
    }

    private func formatDMS(_ coord: CLLocationCoordinate2D) -> String {
        func toDMS(_ value: Double, isLat: Bool) -> String {
            let absolute = abs(value)
            let degrees = Int(absolute)
            let minutesDecimal = (absolute - Double(degrees)) * 60
            let minutes = Int(minutesDecimal)
            let seconds = (minutesDecimal - Double(minutes)) * 60
            let direction = isLat ? (value >= 0 ? "N" : "S") : (value >= 0 ? "E" : "W")
            return String(format: "%d°%02d'%05.2f\"%@", degrees, minutes, seconds, direction)
        }
        return "\(toDMS(coord.latitude, isLat: true)) \(toDMS(coord.longitude, isLat: false))"
    }

    private func formatAltitude(_ meters: Double) -> String {
        switch settingsVM.settings.unitSystem {
        case .metric:
            return String(format: "%.0f m", meters)
        case .imperial:
            return String(format: "%.0f ft", meters * 3.28084)
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

    private func formatRecordingDuration() -> String {
        guard let start = locationManager.recordingStartTime else { return "0:00" }
        let duration = Date().timeIntervalSince(start)
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Calculate MKCoordinateRegion for a given radius around a center point
    /// Matches Android's latLngBoundsForRadius implementation
    private func regionForRadius(center: CLLocationCoordinate2D, radiusMeters: Double) -> MKCoordinateRegion {
        let earthRadius = 6371000.0  // meters
        let latRad = center.latitude * .pi / 180.0

        // Calculate deltas in radians
        let dLat = radiusMeters / earthRadius
        let dLon = radiusMeters / (earthRadius * cos(latRad))

        // Convert to degrees and double for full span (radius * 2)
        let latSpan = (dLat * 180.0 / .pi) * 2.0
        let lonSpan = (dLon * 180.0 / .pi) * 2.0

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan)
        )
    }
}

// MARK: - Control Panel Button

private struct ControlPanelButton: View {
    let icon: String
    var badge: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)

                if badge > 0 {
                    Text("\(min(badge, 99))")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 6, y: -2)
                }
            }
        }
    }
}

// MARK: - Map Control Button

private struct MapControlButton: View {
    let icon: String
    var isActive: Bool = false
    var activeColor: Color = .blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isActive ? activeColor : .primary)
                .frame(width: 48, height: 48)
                .background(isActive ? activeColor.opacity(0.2) : Color.clear)
                .clipShape(Circle())
        }
    }
}

// MARK: - Map View Representable

struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let followMode: Bool
    let myPosition: CLLocationCoordinate2D?
    let peerPositions: [PeerPosition]
    var onLongPress: ((CLLocationCoordinate2D, CGPoint) -> Void)?
    var onPinSelected: ((NatoPin) -> Void)?
    var onUserLocationScreenUpdate: ((CGPoint?) -> Void)?
    var onUserDraggedMap: (() -> Void)?
    var onMapReady: ((MKMapView) -> Void)?

    @ObservedObject private var pinsVM = PinsViewModel.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var settingsVM = SettingsViewModel.shared
    @ObservedObject private var routesVM = RoutesViewModel.shared

    // Static reference to allow direct map control
    static var mapViewReference: MKMapView?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.setRegion(region, animated: false)

        // Store reference for direct control
        MapViewRepresentable.mapViewReference = mapView

        // Apply map style
        updateMapType(mapView)

        // Add long-press gesture recognizer
        let longPressGesture = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPressGesture.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPressGesture)

        // Add pan gesture recognizer to detect user dragging
        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        panGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(panGesture)

        // Notify that map is ready
        onMapReady?(mapView)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update static reference
        MapViewRepresentable.mapViewReference = mapView

        // Update map type based on settings
        updateMapType(mapView)

        // Update peer annotations
        updatePeerAnnotations(mapView)

        // Update pin annotations
        updatePinAnnotations(mapView)

        // Update breadcrumb overlay
        updateBreadcrumbOverlay(mapView)

        // Report user location screen position for crosshair line
        if let userLocation = mapView.userLocation.location?.coordinate {
            let screenPoint = mapView.convert(userLocation, toPointTo: mapView)
            if mapView.bounds.contains(screenPoint) {
                onUserLocationScreenUpdate?(screenPoint)
            } else {
                onUserLocationScreenUpdate?(nil)
            }
        } else {
            onUserLocationScreenUpdate?(nil)
        }

        // Follow mode - continuously center on user position (keeping current zoom)
        if followMode, let position = myPosition {
            let currentCenter = mapView.centerCoordinate
            let latDiff = abs(position.latitude - currentCenter.latitude)
            let lonDiff = abs(position.longitude - currentCenter.longitude)

            if latDiff > 0.0001 || lonDiff > 0.0001 {
                context.coordinator.isProgrammaticRegionChange = true
                let newRegion = MKCoordinateRegion(
                    center: position,
                    span: mapView.region.span  // Keep current zoom
                )
                mapView.setRegion(newRegion, animated: true)
            }
        }
        context.coordinator.wasFollowing = followMode
    }

    private func updateMapType(_ mapView: MKMapView) {
        // Remove existing tile overlays
        let existingOverlays = mapView.overlays.filter { $0 is MKTileOverlay }
        mapView.removeOverlays(existingOverlays)

        let currentStyle = settingsVM.currentMapStyle

        // Check if MapTiler is configured for terrain/outdoor/topographic styles
        if let tileURLTemplate = settingsVM.mapTilerURL(for: currentStyle) {
            // Use MapTiler tiles
            mapView.mapType = .standard  // Base layer
            let tileOverlay = MKTileOverlay(urlTemplate: tileURLTemplate)
            tileOverlay.canReplaceMapContent = true
            tileOverlay.maximumZ = 19
            tileOverlay.minimumZ = 0
            mapView.addOverlay(tileOverlay, level: .aboveLabels)
            mapView.showsBuildings = false
        } else {
            // Use Apple's native map types
            switch currentStyle {
            case .standard:
                mapView.mapType = .standard
                mapView.showsBuildings = true
            case .satellite:
                mapView.mapType = .satellite
                mapView.showsBuildings = true
            case .hybrid:
                mapView.mapType = .hybrid
                mapView.showsBuildings = true
            case .terrain:
                // Fallback: use mutedStandard for terrain feel
                mapView.mapType = .mutedStandard
                mapView.showsBuildings = false
            case .outdoor:
                // Fallback: use standard
                mapView.mapType = .standard
                mapView.showsBuildings = false
            case .topographic:
                // Fallback: use mutedStandard
                mapView.mapType = .mutedStandard
                mapView.showsBuildings = false
            }
        }
    }

    private func updatePeerAnnotations(_ mapView: MKMapView) {
        let existingPeers = mapView.annotations.compactMap { $0 as? PeerAnnotation }
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
        // Remove existing breadcrumb overlays (but not crosshair line)
        let existingOverlays = mapView.overlays.filter { $0 is BreadcrumbPolyline || $0 is SavedRoutePolyline }
        mapView.removeOverlays(existingOverlays)

        // Add current breadcrumb trail if recording
        if locationManager.isRecordingBreadcrumbs && locationManager.breadcrumbPoints.count >= 2 {
            let coordinates = locationManager.breadcrumbPoints.map { $0.coordinate }
            let polyline = BreadcrumbPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
        }

        // Add visible saved routes
        for route in RoutesViewModel.shared.visibleBreadcrumbRoutes {
            if route.points.count >= 2 {
                let coordinates = route.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                let polyline = SavedRoutePolyline(coordinates: coordinates, count: coordinates.count)
                mapView.addOverlay(polyline)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: MapViewRepresentable
        var wasFollowing: Bool = false
        var isProgrammaticRegionChange: Bool = false

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }

            let mapView = gesture.view as! MKMapView
            let screenPoint = gesture.location(in: mapView)
            let coordinate = mapView.convert(screenPoint, toCoordinateFrom: mapView)

            parent.onLongPress?(coordinate, screenPoint)
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            if gesture.state == .began {
                // User started dragging the map - disable follow mode
                parent.onUserDraggedMap?()
            }
        }

        // Allow pan gesture to work simultaneously with map's built-in gestures
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
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

            // Handle pin annotations - use circular markers like Android
            if let pinAnnotation = annotation as? PinAnnotation {
                let identifier = "PinMarker_\(pinAnnotation.pinType.rawValue)"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

                if view == nil {
                    view = MKAnnotationView(annotation: pinAnnotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                    // Add info button for View/Edit/Delete options
                    let infoButton = UIButton(type: .detailDisclosure)
                    view?.rightCalloutAccessoryView = infoButton
                } else {
                    view?.annotation = pinAnnotation
                }

                // Use circular marker matching Android style
                view?.image = PinMarkerImageCache.shared.image(for: pinAnnotation.pinType)
                view?.centerOffset = CGPoint(x: 0, y: 0)  // Center on coordinate
                return view
            }

            return nil
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard let pinAnnotation = view.annotation as? PinAnnotation else { return }

            // Find the pin and call the selection callback
            if let pin = parent.pinsVM.pins.first(where: { $0.id == pinAnnotation.pinId }) {
                parent.onPinSelected?(pin)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // Handle tile overlays (MapTiler)
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }

            // Handle crosshair line overlay
            if let polyline = overlay as? CrosshairLinePolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 2
                return renderer
            }

            // Handle breadcrumb polyline overlays (active recording)
            if let polyline = overlay as? BreadcrumbPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(parent.settingsVM.breadcrumbColor)
                renderer.lineWidth = 3
                return renderer
            }

            // Handle saved route polyline overlays
            if let polyline = overlay as? SavedRoutePolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(parent.settingsVM.breadcrumbColor).withAlphaComponent(0.7)
                renderer.lineWidth = 3
                return renderer
            }

            // Handle any other polyline overlays
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(parent.settingsVM.breadcrumbColor)
                renderer.lineWidth = 3
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Skip updating binding if this was a programmatic change (prevents infinite loop)
            if isProgrammaticRegionChange {
                isProgrammaticRegionChange = false
                return
            }
            // Update region binding only for user-initiated changes
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

// MARK: - Custom Polyline Classes

/// Polyline for active breadcrumb recording
class BreadcrumbPolyline: MKPolyline {}

/// Polyline for saved routes
class SavedRoutePolyline: MKPolyline {}

/// Polyline for crosshair-to-position line
class CrosshairLinePolyline: MKPolyline {}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    MainView()
}
