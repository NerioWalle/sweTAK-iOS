import XCTest
import CoreLocation
@testable import sweTAK

/// Tests for Phase 28: Advanced Settings, Chat Components, Map Orientation
final class Phase28Tests: XCTestCase {

    // MARK: - ThemeMode Tests

    func testThemeModeValues() {
        XCTAssertEqual(ThemeMode.system.rawValue, "SYSTEM")
        XCTAssertEqual(ThemeMode.light.rawValue, "LIGHT")
        XCTAssertEqual(ThemeMode.dark.rawValue, "DARK")
        XCTAssertEqual(ThemeMode.nightVision.rawValue, "NIGHT_VISION")
    }

    func testThemeModeDisplayNames() {
        XCTAssertEqual(ThemeMode.system.displayName, "System")
        XCTAssertEqual(ThemeMode.light.displayName, "Light")
        XCTAssertEqual(ThemeMode.dark.displayName, "Dark")
        XCTAssertEqual(ThemeMode.nightVision.displayName, "Night Vision")
    }

    func testThemeModeIcons() {
        XCTAssertEqual(ThemeMode.system.icon, "circle.lefthalf.filled")
        XCTAssertEqual(ThemeMode.light.icon, "sun.max.fill")
        XCTAssertEqual(ThemeMode.dark.icon, "moon.fill")
        XCTAssertEqual(ThemeMode.nightVision.icon, "eye.fill")
    }

    func testThemeModeAllCases() {
        XCTAssertEqual(ThemeMode.allCases.count, 4)
    }

    // MARK: - NightVisionColor Tests

    func testNightVisionColorValues() {
        XCTAssertEqual(NightVisionColor.red.rawValue, "RED")
        XCTAssertEqual(NightVisionColor.green.rawValue, "GREEN")
        XCTAssertEqual(NightVisionColor.blue.rawValue, "BLUE")
    }

    func testNightVisionColorDisplayNames() {
        XCTAssertEqual(NightVisionColor.red.displayName, "Red")
        XCTAssertEqual(NightVisionColor.green.displayName, "Green")
        XCTAssertEqual(NightVisionColor.blue.displayName, "Blue")
    }

    func testNightVisionColorHexValues() {
        XCTAssertEqual(NightVisionColor.red.hexValue, 0xB71C1C)
        XCTAssertEqual(NightVisionColor.green.hexValue, 0x1B5E20)
        XCTAssertEqual(NightVisionColor.blue.hexValue, 0x0D47A1)
    }

    func testNightVisionColorOverlayOpacity() {
        XCTAssertEqual(NightVisionColor.red.overlayOpacity, 0.7)
        XCTAssertEqual(NightVisionColor.green.overlayOpacity, 0.7)
        XCTAssertEqual(NightVisionColor.blue.overlayOpacity, 0.7)
    }

    // MARK: - MapStyle Tests

    func testMapStyleValues() {
        XCTAssertEqual(MapStyle.standard.rawValue, "STANDARD")
        XCTAssertEqual(MapStyle.satellite.rawValue, "SATELLITE")
        XCTAssertEqual(MapStyle.hybrid.rawValue, "HYBRID")
        XCTAssertEqual(MapStyle.terrain.rawValue, "TERRAIN")
        XCTAssertEqual(MapStyle.outdoor.rawValue, "OUTDOOR")
        XCTAssertEqual(MapStyle.topographic.rawValue, "TOPOGRAPHIC")
    }

    func testMapStyleDisplayNames() {
        XCTAssertEqual(MapStyle.standard.displayName, "Standard")
        XCTAssertEqual(MapStyle.satellite.displayName, "Satellite")
        XCTAssertEqual(MapStyle.hybrid.displayName, "Hybrid")
        XCTAssertEqual(MapStyle.terrain.displayName, "Terrain")
        XCTAssertEqual(MapStyle.outdoor.displayName, "Outdoor")
        XCTAssertEqual(MapStyle.topographic.displayName, "Topographic")
    }

    func testMapStyleIcons() {
        XCTAssertEqual(MapStyle.standard.icon, "map")
        XCTAssertEqual(MapStyle.satellite.icon, "globe.americas")
        XCTAssertEqual(MapStyle.hybrid.icon, "map.fill")
        XCTAssertEqual(MapStyle.terrain.icon, "mountain.2")
        XCTAssertEqual(MapStyle.outdoor.icon, "figure.hiking")
        XCTAssertEqual(MapStyle.topographic.icon, "chart.line.uptrend.xyaxis")
    }

    func testMapStyleAllCases() {
        XCTAssertEqual(MapStyle.allCases.count, 6)
    }

    // MARK: - BreadcrumbColor Tests

    func testBreadcrumbColorValues() {
        XCTAssertEqual(BreadcrumbColor.orange.rawValue, "ORANGE")
        XCTAssertEqual(BreadcrumbColor.red.rawValue, "RED")
        XCTAssertEqual(BreadcrumbColor.blue.rawValue, "BLUE")
        XCTAssertEqual(BreadcrumbColor.green.rawValue, "GREEN")
        XCTAssertEqual(BreadcrumbColor.yellow.rawValue, "YELLOW")
        XCTAssertEqual(BreadcrumbColor.white.rawValue, "WHITE")
    }

    func testBreadcrumbColorDisplayNames() {
        XCTAssertEqual(BreadcrumbColor.orange.displayName, "Orange")
        XCTAssertEqual(BreadcrumbColor.red.displayName, "Red")
        XCTAssertEqual(BreadcrumbColor.blue.displayName, "Blue")
        XCTAssertEqual(BreadcrumbColor.green.displayName, "Green")
        XCTAssertEqual(BreadcrumbColor.yellow.displayName, "Yellow")
        XCTAssertEqual(BreadcrumbColor.white.displayName, "White")
    }

    func testBreadcrumbColorAllCases() {
        XCTAssertEqual(BreadcrumbColor.allCases.count, 6)
    }

    // MARK: - PositionBroadcastUnit Tests

    func testPositionBroadcastUnitValues() {
        XCTAssertEqual(PositionBroadcastUnit.seconds.rawValue, "SEC")
        XCTAssertEqual(PositionBroadcastUnit.minutes.rawValue, "MIN")
        XCTAssertEqual(PositionBroadcastUnit.hours.rawValue, "H")
    }

    func testPositionBroadcastUnitDisplayNames() {
        XCTAssertEqual(PositionBroadcastUnit.seconds.displayName, "Seconds")
        XCTAssertEqual(PositionBroadcastUnit.minutes.displayName, "Minutes")
        XCTAssertEqual(PositionBroadcastUnit.hours.displayName, "Hours")
    }

    func testPositionBroadcastUnitAbbreviations() {
        XCTAssertEqual(PositionBroadcastUnit.seconds.abbreviation, "sec")
        XCTAssertEqual(PositionBroadcastUnit.minutes.abbreviation, "min")
        XCTAssertEqual(PositionBroadcastUnit.hours.abbreviation, "hr")
    }

    func testPositionBroadcastUnitToSeconds() {
        XCTAssertEqual(PositionBroadcastUnit.seconds.toSeconds(30), 30)
        XCTAssertEqual(PositionBroadcastUnit.minutes.toSeconds(5), 300)
        XCTAssertEqual(PositionBroadcastUnit.hours.toSeconds(1), 3600)
    }

    func testPositionBroadcastUnitFromSeconds() {
        XCTAssertEqual(PositionBroadcastUnit.seconds.fromSeconds(30), 30)
        XCTAssertEqual(PositionBroadcastUnit.minutes.fromSeconds(300), 5)
        XCTAssertEqual(PositionBroadcastUnit.hours.fromSeconds(3600), 1)
    }

    // MARK: - UnitSystem Tests

    func testUnitSystemValues() {
        XCTAssertEqual(UnitSystem.metric.rawValue, "METRIC")
        XCTAssertEqual(UnitSystem.imperial.rawValue, "IMPERIAL")
    }

    func testUnitSystemDisplayNames() {
        XCTAssertEqual(UnitSystem.metric.displayName, "Metric")
        XCTAssertEqual(UnitSystem.imperial.displayName, "Imperial")
    }

    func testUnitSystemDistanceUnits() {
        XCTAssertEqual(UnitSystem.metric.distanceUnit, "km")
        XCTAssertEqual(UnitSystem.imperial.distanceUnit, "mi")
    }

    func testUnitSystemSpeedUnits() {
        XCTAssertEqual(UnitSystem.metric.speedUnit, "km/h")
        XCTAssertEqual(UnitSystem.imperial.speedUnit, "mph")
    }

    func testUnitSystemAltitudeUnits() {
        XCTAssertEqual(UnitSystem.metric.altitudeUnit, "m")
        XCTAssertEqual(UnitSystem.imperial.altitudeUnit, "ft")
    }

    func testUnitSystemFormatDistanceMetric() {
        XCTAssertEqual(UnitSystem.metric.formatDistance(500), "500 m")
        XCTAssertEqual(UnitSystem.metric.formatDistance(1500), "1.5 km")
    }

    func testUnitSystemFormatDistanceImperial() {
        let result1 = UnitSystem.imperial.formatDistance(100)
        XCTAssertTrue(result1.contains("ft"))

        let result2 = UnitSystem.imperial.formatDistance(5000)
        XCTAssertTrue(result2.contains("mi"))
    }

    func testUnitSystemFormatAltitude() {
        XCTAssertEqual(UnitSystem.metric.formatAltitude(1000), "1000 m")
        XCTAssertTrue(UnitSystem.imperial.formatAltitude(1000).contains("ft"))
    }

    // MARK: - LayersMenuLevel Tests

    func testLayersMenuLevelValues() {
        XCTAssertEqual(LayersMenuLevel.root.rawValue, "ROOT")
        XCTAssertEqual(LayersMenuLevel.mapStyles.rawValue, "MAP_STYLES")
        XCTAssertEqual(LayersMenuLevel.recordedRoutes.rawValue, "RECORDED_ROUTES")
        XCTAssertEqual(LayersMenuLevel.plannedRoutes.rawValue, "PLANNED_ROUTES")
    }

    func testLayersMenuLevelAllCases() {
        XCTAssertEqual(LayersMenuLevel.allCases.count, 4)
    }

    // MARK: - MessagingMenuLevel Tests

    func testMessagingMenuLevelValues() {
        XCTAssertEqual(MessagingMenuLevel.root.rawValue, "ROOT")
        XCTAssertEqual(MessagingMenuLevel.ordersSubmenu.rawValue, "ORDERS_SUBMENU")
        XCTAssertEqual(MessagingMenuLevel.reportsSubmenu.rawValue, "REPORTS_SUBMENU")
        XCTAssertEqual(MessagingMenuLevel.pedarsSubmenu.rawValue, "PEDARS_SUBMENU")
        XCTAssertEqual(MessagingMenuLevel.medevacSubmenu.rawValue, "MEDEVAC_SUBMENU")
        XCTAssertEqual(MessagingMenuLevel.requestsSubmenu.rawValue, "REQUESTS_SUBMENU")
        XCTAssertEqual(MessagingMenuLevel.methaneSubmenu.rawValue, "METHANE_SUBMENU")
    }

    func testMessagingMenuLevelAllCases() {
        XCTAssertEqual(MessagingMenuLevel.allCases.count, 7)
    }

    // MARK: - AdvancedSettings Tests

    func testAdvancedSettingsDefaultInit() {
        let settings = AdvancedSettings()

        XCTAssertEqual(settings.themeMode, .system)
        XCTAssertEqual(settings.nightVisionColor, .green)
        XCTAssertEqual(settings.defaultMapStyle, .standard)
        XCTAssertEqual(settings.coordMode, .latLon)
        XCTAssertEqual(settings.unitSystem, .metric)
        XCTAssertEqual(settings.breadcrumbColor, .orange)
        XCTAssertTrue(settings.showBreadcrumbs)
        XCTAssertTrue(settings.showOtherUsers)
        XCTAssertEqual(settings.positionBroadcastValue, 30)
        XCTAssertEqual(settings.positionBroadcastUnit, .seconds)
        XCTAssertEqual(settings.mqttPort, 1883)
        XCTAssertFalse(settings.mqttUseTLS)
        XCTAssertEqual(settings.mqttMaxMessageAgeMinutes, 5)
        XCTAssertTrue(settings.messageSigningEnabled)
        XCTAssertFalse(settings.rejectUnsignedMessages)
    }

    func testAdvancedSettingsCustomInit() {
        let settings = AdvancedSettings(
            themeMode: .dark,
            nightVisionColor: .red,
            defaultMapStyle: .satellite,
            coordMode: .mgrs,
            unitSystem: .imperial,
            breadcrumbColor: .blue,
            showBreadcrumbs: false,
            showOtherUsers: false,
            positionBroadcastValue: 60,
            positionBroadcastUnit: .minutes,
            mqttHost: "mqtt.example.com",
            mqttPort: 8883,
            mqttUseTLS: true,
            mqttMaxMessageAgeMinutes: 10,
            messageSigningEnabled: false,
            rejectUnsignedMessages: true
        )

        XCTAssertEqual(settings.themeMode, .dark)
        XCTAssertEqual(settings.nightVisionColor, .red)
        XCTAssertEqual(settings.defaultMapStyle, .satellite)
        XCTAssertEqual(settings.coordMode, .mgrs)
        XCTAssertEqual(settings.unitSystem, .imperial)
        XCTAssertEqual(settings.breadcrumbColor, .blue)
        XCTAssertFalse(settings.showBreadcrumbs)
        XCTAssertFalse(settings.showOtherUsers)
        XCTAssertEqual(settings.positionBroadcastValue, 60)
        XCTAssertEqual(settings.positionBroadcastUnit, .minutes)
        XCTAssertEqual(settings.mqttHost, "mqtt.example.com")
        XCTAssertEqual(settings.mqttPort, 8883)
        XCTAssertTrue(settings.mqttUseTLS)
        XCTAssertEqual(settings.mqttMaxMessageAgeMinutes, 10)
        XCTAssertFalse(settings.messageSigningEnabled)
        XCTAssertTrue(settings.rejectUnsignedMessages)
    }

    func testAdvancedSettingsPositionBroadcastIntervalSeconds() {
        let settings1 = AdvancedSettings(positionBroadcastValue: 30, positionBroadcastUnit: .seconds)
        XCTAssertEqual(settings1.positionBroadcastIntervalSeconds, 30)

        let settings2 = AdvancedSettings(positionBroadcastValue: 5, positionBroadcastUnit: .minutes)
        XCTAssertEqual(settings2.positionBroadcastIntervalSeconds, 300)

        let settings3 = AdvancedSettings(positionBroadcastValue: 1, positionBroadcastUnit: .hours)
        XCTAssertEqual(settings3.positionBroadcastIntervalSeconds, 3600)
    }

    func testAdvancedSettingsEffectiveMqttPort() {
        // TLS enabled with default non-TLS port should switch to 8883
        let settings1 = AdvancedSettings(mqttPort: 1883, mqttUseTLS: true)
        XCTAssertEqual(settings1.effectiveMqttPort, 8883)

        // TLS disabled with TLS port should switch to 1883
        let settings2 = AdvancedSettings(mqttPort: 8883, mqttUseTLS: false)
        XCTAssertEqual(settings2.effectiveMqttPort, 1883)

        // Custom port should stay unchanged
        let settings3 = AdvancedSettings(mqttPort: 9000, mqttUseTLS: true)
        XCTAssertEqual(settings3.effectiveMqttPort, 9000)
    }

    func testAdvancedSettingsEquatable() {
        let settings1 = AdvancedSettings()
        let settings2 = AdvancedSettings()
        XCTAssertEqual(settings1, settings2)

        let settings3 = AdvancedSettings(themeMode: .dark)
        XCTAssertNotEqual(settings1, settings3)
    }

    func testAdvancedSettingsCodable() throws {
        let original = AdvancedSettings(
            themeMode: .dark,
            coordMode: .mgrs,
            mqttHost: "test.mqtt.com"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AdvancedSettings.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - MapOrientationMode Tests

    func testMapOrientationModeValues() {
        XCTAssertEqual(MapOrientationMode.northUp.rawValue, "NORTH_UP")
        XCTAssertEqual(MapOrientationMode.headingUp.rawValue, "HEADING_UP")
        XCTAssertEqual(MapOrientationMode.freeRotate.rawValue, "FREE_ROTATE")
    }

    func testMapOrientationModeDisplayNames() {
        XCTAssertEqual(MapOrientationMode.northUp.displayName, "North Up")
        XCTAssertEqual(MapOrientationMode.headingUp.displayName, "Heading Up")
        XCTAssertEqual(MapOrientationMode.freeRotate.displayName, "Free Rotate")
    }

    func testMapOrientationModeIcons() {
        XCTAssertEqual(MapOrientationMode.northUp.icon, "location.north.fill")
        XCTAssertEqual(MapOrientationMode.headingUp.icon, "location.north.line.fill")
        XCTAssertEqual(MapOrientationMode.freeRotate.icon, "arrow.triangle.2.circlepath")
    }

    func testMapOrientationModeAllCases() {
        XCTAssertEqual(MapOrientationMode.allCases.count, 3)
    }

    // MARK: - ChatDirection Tests

    func testChatDirectionValues() {
        XCTAssertEqual(ChatDirection.incoming.rawValue, "INCOMING")
        XCTAssertEqual(ChatDirection.outgoing.rawValue, "OUTGOING")
    }

    // MARK: - ChatMessage Tests

    func testChatMessageCreation() {
        let message = ChatMessage(
            threadId: "thread-123",
            fromDeviceId: "device-A",
            toDeviceId: "device-B",
            text: "Hello, World!",
            timestampMillis: 1704067200000,
            direction: .outgoing
        )

        XCTAssertEqual(message.threadId, "thread-123")
        XCTAssertEqual(message.fromDeviceId, "device-A")
        XCTAssertEqual(message.toDeviceId, "device-B")
        XCTAssertEqual(message.text, "Hello, World!")
        XCTAssertEqual(message.timestampMillis, 1704067200000)
        XCTAssertEqual(message.direction, .outgoing)
        XCTAssertFalse(message.acknowledged)
    }

    func testChatMessageWithAcknowledgment() {
        let message = ChatMessage(
            threadId: "thread-123",
            fromDeviceId: "device-A",
            toDeviceId: "device-B",
            text: "Acknowledged message",
            timestampMillis: Date.currentMillis,
            direction: .outgoing,
            acknowledged: true
        )

        XCTAssertTrue(message.acknowledged)
    }

    // MARK: - IncomingChatNotification Tests

    func testIncomingChatNotificationCreation() {
        let notification = IncomingChatNotification(
            threadId: "thread-456",
            fromDeviceId: "device-X",
            textPreview: "New message preview",
            callsign: "Bravo-2",
            nickname: "Bob"
        )

        XCTAssertEqual(notification.threadId, "thread-456")
        XCTAssertEqual(notification.fromDeviceId, "device-X")
        XCTAssertEqual(notification.textPreview, "New message preview")
        XCTAssertEqual(notification.callsign, "Bravo-2")
        XCTAssertEqual(notification.nickname, "Bob")
    }

    func testIncomingChatNotificationEquality() {
        let notif1 = IncomingChatNotification(
            threadId: "thread-1",
            fromDeviceId: "device-1",
            textPreview: "Hello",
            callsign: "Alpha",
            nickname: nil
        )

        let notif2 = IncomingChatNotification(
            threadId: "thread-1",
            fromDeviceId: "device-1",
            textPreview: "Hello",
            callsign: "Alpha",
            nickname: nil
        )

        XCTAssertEqual(notif1, notif2)
    }

    // MARK: - RemoteMarker Tests

    func testRemoteMarkerCreation() {
        let marker = RemoteMarker(
            deviceId: "device-123",
            callsign: "Charlie-1",
            nickname: "Chuck",
            latitude: 59.3293,
            longitude: 18.0686
        )

        XCTAssertEqual(marker.deviceId, "device-123")
        XCTAssertEqual(marker.callsign, "Charlie-1")
        XCTAssertEqual(marker.nickname, "Chuck")
        XCTAssertEqual(marker.latitude, 59.3293, accuracy: 0.0001)
        XCTAssertEqual(marker.longitude, 18.0686, accuracy: 0.0001)
    }

    func testRemoteMarkerIdentifiable() {
        let marker = RemoteMarker(
            deviceId: "unique-device-id",
            callsign: "Delta-1",
            latitude: 59.0,
            longitude: 18.0
        )

        XCTAssertEqual(marker.id, "unique-device-id")
    }

    func testRemoteMarkerEquality() {
        let marker1 = RemoteMarker(
            deviceId: "device-1",
            callsign: "Alpha",
            latitude: 59.0,
            longitude: 18.0
        )

        let marker2 = RemoteMarker(
            deviceId: "device-1",
            callsign: "Alpha",
            latitude: 59.0,
            longitude: 18.0
        )

        XCTAssertEqual(marker1, marker2)
    }

    // MARK: - CoordMode Tests

    func testCoordModeValues() {
        XCTAssertEqual(CoordMode.mgrs.rawValue, "MGRS")
        XCTAssertEqual(CoordMode.latLon.rawValue, "LATLON")
    }

    func testCoordModeDisplayNames() {
        XCTAssertEqual(CoordMode.mgrs.displayName, "MGRS")
        XCTAssertEqual(CoordMode.latLon.displayName, "Lat/Lon")
    }

    // MARK: - PositionUnit Tests

    func testPositionUnitValues() {
        XCTAssertEqual(PositionUnit.sec.rawValue, "SEC")
        XCTAssertEqual(PositionUnit.min.rawValue, "MIN")
        XCTAssertEqual(PositionUnit.hour.rawValue, "H")
    }

    func testPositionUnitToMillis() {
        XCTAssertEqual(PositionUnit.sec.toMillis(30), 30_000)
        XCTAssertEqual(PositionUnit.min.toMillis(5), 300_000)
        XCTAssertEqual(PositionUnit.hour.toMillis(1), 3_600_000)
    }

    // MARK: - Friend Tests

    func testFriendCreation() {
        let friend = Friend(
            deviceId: "friend-device",
            host: "192.168.1.100",
            port: 5000
        )

        XCTAssertEqual(friend.deviceId, "friend-device")
        XCTAssertEqual(friend.host, "192.168.1.100")
        XCTAssertEqual(friend.port, 5000)
        XCTAssertTrue(friend.approved)
        XCTAssertEqual(friend.callsign, "")
        XCTAssertNil(friend.lastPosition)
    }

    func testFriendWithCallsignAndPosition() {
        var friend = Friend(
            deviceId: "friend-device",
            host: "192.168.1.100",
            port: 5000,
            callsign: "Echo-1",
            approved: true
        )

        friend.lastPosition = CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06)

        XCTAssertEqual(friend.callsign, "Echo-1")
        XCTAssertNotNil(friend.lastPosition)
        XCTAssertEqual(friend.lastPosition?.latitude, 59.33, accuracy: 0.01)
        XCTAssertEqual(friend.lastPosition?.longitude, 18.06, accuracy: 0.01)
    }

    // MARK: - MapViewModel Singleton Tests

    func testMapViewModelSingleton() {
        let vm1 = MapViewModel.shared
        let vm2 = MapViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    // MARK: - SettingsViewModel Singleton Tests

    func testSettingsViewModelSingleton() {
        let vm1 = SettingsViewModel.shared
        let vm2 = SettingsViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    // MARK: - ChatViewModel Singleton Tests

    func testChatViewModelSingleton() {
        let vm1 = ChatViewModel.shared
        let vm2 = ChatViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    // MARK: - ContactsViewModel Singleton Tests

    func testContactsViewModelSingleton() {
        let vm1 = ContactsViewModel.shared
        let vm2 = ContactsViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    // MARK: - TransportMode Tests

    func testTransportModeValues() {
        // Verify transport modes exist
        _ = TransportMode.mqtt
        _ = TransportMode.localUDP
    }

    // MARK: - Comprehensive Enum CaseIterable Tests

    func testAllEnumsHaveAllCases() {
        // Verify all CaseIterable enums have expected case counts
        XCTAssertGreaterThan(ThemeMode.allCases.count, 0)
        XCTAssertGreaterThan(NightVisionColor.allCases.count, 0)
        XCTAssertGreaterThan(MapStyle.allCases.count, 0)
        XCTAssertGreaterThan(BreadcrumbColor.allCases.count, 0)
        XCTAssertGreaterThan(PositionBroadcastUnit.allCases.count, 0)
        XCTAssertGreaterThan(UnitSystem.allCases.count, 0)
        XCTAssertGreaterThan(LayersMenuLevel.allCases.count, 0)
        XCTAssertGreaterThan(MessagingMenuLevel.allCases.count, 0)
        XCTAssertGreaterThan(MapOrientationMode.allCases.count, 0)
        XCTAssertGreaterThan(CoordMode.allCases.count, 0)
        XCTAssertGreaterThan(PositionUnit.allCases.count, 0)
    }

    // MARK: - JSON Encoding/Decoding Tests

    func testThemeModeEncodeDecode() throws {
        let original = ThemeMode.nightVision
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ThemeMode.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testNightVisionColorEncodeDecode() throws {
        let original = NightVisionColor.blue
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NightVisionColor.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testMapStyleEncodeDecode() throws {
        let original = MapStyle.terrain
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MapStyle.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testCoordModeEncodeDecode() throws {
        let original = CoordMode.mgrs
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CoordMode.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testChatMessageEncodeDecode() throws {
        let original = ChatMessage(
            threadId: "thread-test",
            fromDeviceId: "from-device",
            toDeviceId: "to-device",
            text: "Test message",
            timestampMillis: 1704067200000,
            direction: .outgoing
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)

        XCTAssertEqual(original.threadId, decoded.threadId)
        XCTAssertEqual(original.text, decoded.text)
        XCTAssertEqual(original.direction, decoded.direction)
    }
}
