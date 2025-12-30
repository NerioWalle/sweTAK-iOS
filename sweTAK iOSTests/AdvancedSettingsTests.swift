import XCTest
import SwiftUI
@testable import sweTAK

// MARK: - Theme Mode Tests

final class ThemeModeTests: XCTestCase {

    func testThemeModeRawValues() {
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
        XCTAssertFalse(ThemeMode.system.icon.isEmpty)
        XCTAssertFalse(ThemeMode.light.icon.isEmpty)
        XCTAssertFalse(ThemeMode.dark.icon.isEmpty)
        XCTAssertFalse(ThemeMode.nightVision.icon.isEmpty)
    }

    func testThemeModeCaseIterable() {
        XCTAssertEqual(ThemeMode.allCases.count, 4)
    }

    func testThemeModeCodable() throws {
        let mode = ThemeMode.nightVision

        let encoder = JSONEncoder()
        let data = try encoder.encode(mode)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ThemeMode.self, from: data)

        XCTAssertEqual(decoded, mode)
    }
}

// MARK: - Night Vision Color Tests

final class NightVisionColorTests: XCTestCase {

    func testNightVisionColorRawValues() {
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

    func testNightVisionColorCaseIterable() {
        XCTAssertEqual(NightVisionColor.allCases.count, 3)
    }
}

// MARK: - Map Style Tests

final class MapStyleTests: XCTestCase {

    func testMapStyleRawValues() {
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
        XCTAssertEqual(MapStyle.terrain.displayName, "Terrain")
    }

    func testMapStyleIcons() {
        for style in MapStyle.allCases {
            XCTAssertFalse(style.icon.isEmpty)
        }
    }

    func testMapStyleCaseIterable() {
        XCTAssertEqual(MapStyle.allCases.count, 6)
    }
}

// MARK: - Breadcrumb Color Tests

final class BreadcrumbColorTests: XCTestCase {

    func testBreadcrumbColorRawValues() {
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
    }

    func testBreadcrumbColorCaseIterable() {
        XCTAssertEqual(BreadcrumbColor.allCases.count, 6)
    }
}

// MARK: - Position Broadcast Unit Tests

final class PositionBroadcastUnitTests: XCTestCase {

    func testPositionBroadcastUnitRawValues() {
        XCTAssertEqual(PositionBroadcastUnit.seconds.rawValue, "SEC")
        XCTAssertEqual(PositionBroadcastUnit.minutes.rawValue, "MIN")
        XCTAssertEqual(PositionBroadcastUnit.hours.rawValue, "H")
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

    func testPositionBroadcastUnitAbbreviations() {
        XCTAssertEqual(PositionBroadcastUnit.seconds.abbreviation, "sec")
        XCTAssertEqual(PositionBroadcastUnit.minutes.abbreviation, "min")
        XCTAssertEqual(PositionBroadcastUnit.hours.abbreviation, "hr")
    }
}

// MARK: - Unit System Tests

final class UnitSystemTests: XCTestCase {

    func testUnitSystemRawValues() {
        XCTAssertEqual(UnitSystem.metric.rawValue, "METRIC")
        XCTAssertEqual(UnitSystem.imperial.rawValue, "IMPERIAL")
    }

    func testUnitSystemDistanceUnits() {
        XCTAssertEqual(UnitSystem.metric.distanceUnit, "km")
        XCTAssertEqual(UnitSystem.imperial.distanceUnit, "mi")
    }

    func testUnitSystemFormatDistanceMetric() {
        XCTAssertEqual(UnitSystem.metric.formatDistance(500), "500 m")
        XCTAssertEqual(UnitSystem.metric.formatDistance(1500), "1.5 km")
    }

    func testUnitSystemFormatDistanceImperial() {
        let result = UnitSystem.imperial.formatDistance(1609.34) // ~1 mile
        XCTAssertTrue(result.contains("mi"))
    }

    func testUnitSystemFormatAltitude() {
        XCTAssertEqual(UnitSystem.metric.formatAltitude(100), "100 m")
        XCTAssertTrue(UnitSystem.imperial.formatAltitude(100).contains("ft"))
    }
}

// MARK: - Advanced Settings Tests

final class AdvancedSettingsTests: XCTestCase {

    func testAdvancedSettingsDefaults() {
        let settings = AdvancedSettings()

        XCTAssertEqual(settings.themeMode, .system)
        XCTAssertEqual(settings.nightVisionColor, .green)
        XCTAssertEqual(settings.defaultMapStyle, .standard)
        XCTAssertEqual(settings.coordMode, .latLon)
        XCTAssertEqual(settings.orientationMode, .northUp)
        XCTAssertEqual(settings.unitSystem, .metric)
        XCTAssertEqual(settings.breadcrumbColor, .orange)
        XCTAssertTrue(settings.showBreadcrumbs)
        XCTAssertTrue(settings.showOtherUsers)
        XCTAssertEqual(settings.positionBroadcastValue, 30)
        XCTAssertEqual(settings.positionBroadcastUnit, .seconds)
        XCTAssertTrue(settings.messageSigningEnabled)
        XCTAssertFalse(settings.rejectUnsignedMessages)
    }

    func testAdvancedSettingsPositionBroadcastInterval() {
        var settings = AdvancedSettings()

        settings.positionBroadcastValue = 30
        settings.positionBroadcastUnit = .seconds
        XCTAssertEqual(settings.positionBroadcastIntervalSeconds, 30)

        settings.positionBroadcastValue = 5
        settings.positionBroadcastUnit = .minutes
        XCTAssertEqual(settings.positionBroadcastIntervalSeconds, 300)
    }

    func testAdvancedSettingsEffectiveMqttPort() {
        var settings = AdvancedSettings()

        // Non-TLS on default port
        settings.mqttUseTLS = false
        settings.mqttPort = 1883
        XCTAssertEqual(settings.effectiveMqttPort, 1883)

        // TLS switches default port to 8883
        settings.mqttUseTLS = true
        settings.mqttPort = 1883
        XCTAssertEqual(settings.effectiveMqttPort, 8883)

        // Non-TLS switches from 8883 to 1883
        settings.mqttUseTLS = false
        settings.mqttPort = 8883
        XCTAssertEqual(settings.effectiveMqttPort, 1883)

        // Custom port stays unchanged
        settings.mqttUseTLS = true
        settings.mqttPort = 9999
        XCTAssertEqual(settings.effectiveMqttPort, 9999)
    }

    func testAdvancedSettingsCodable() throws {
        let settings = AdvancedSettings(
            themeMode: .dark,
            nightVisionColor: .red,
            defaultMapStyle: .satellite,
            breadcrumbColor: .blue
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AdvancedSettings.self, from: data)

        XCTAssertEqual(decoded, settings)
    }
}

// MARK: - Incoming Chat Notification Tests

final class IncomingChatNotificationTests: XCTestCase {

    func testIncomingChatNotificationInitialization() {
        let notification = IncomingChatNotification(
            threadId: "thread-1",
            fromDeviceId: "device-1",
            textPreview: "Hello!",
            callsign: "Alpha-1",
            nickname: "Johnny"
        )

        XCTAssertEqual(notification.threadId, "thread-1")
        XCTAssertEqual(notification.fromDeviceId, "device-1")
        XCTAssertEqual(notification.textPreview, "Hello!")
        XCTAssertEqual(notification.callsign, "Alpha-1")
        XCTAssertEqual(notification.nickname, "Johnny")
    }

    func testIncomingChatNotificationDisplayName() {
        let withNickname = IncomingChatNotification(
            threadId: "t1",
            fromDeviceId: "d1",
            textPreview: "Hi",
            callsign: "Alpha-1",
            nickname: "Johnny"
        )
        XCTAssertEqual(withNickname.displayName, "Alpha-1 - Johnny")

        let withoutNickname = IncomingChatNotification(
            threadId: "t1",
            fromDeviceId: "d1",
            textPreview: "Hi",
            callsign: "Alpha-1"
        )
        XCTAssertEqual(withoutNickname.displayName, "Alpha-1")
    }
}

// MARK: - Remote Marker Tests

final class RemoteMarkerTests: XCTestCase {

    func testRemoteMarkerInitialization() {
        let marker = RemoteMarker(
            deviceId: "device-1",
            callsign: "Alpha-1",
            nickname: "Johnny",
            latitude: 59.33,
            longitude: 18.06,
            altitude: 100.0,
            heading: 45.0
        )

        XCTAssertEqual(marker.deviceId, "device-1")
        XCTAssertEqual(marker.callsign, "Alpha-1")
        XCTAssertEqual(marker.nickname, "Johnny")
        XCTAssertEqual(marker.latitude, 59.33)
        XCTAssertEqual(marker.longitude, 18.06)
        XCTAssertEqual(marker.altitude, 100.0)
        XCTAssertEqual(marker.heading, 45.0)
    }

    func testRemoteMarkerDisplayName() {
        let withNickname = RemoteMarker(
            deviceId: "d1",
            callsign: "Alpha-1",
            nickname: "Johnny",
            latitude: 0,
            longitude: 0
        )
        XCTAssertEqual(withNickname.displayName, "Alpha-1 - Johnny")

        let withoutNickname = RemoteMarker(
            deviceId: "d1",
            callsign: "Alpha-1",
            latitude: 0,
            longitude: 0
        )
        XCTAssertEqual(withoutNickname.displayName, "Alpha-1")
    }
}

// MARK: - Friend Tests

final class FriendTests: XCTestCase {

    func testFriendInitialization() {
        let friend = Friend(
            deviceId: "device-1",
            host: "192.168.1.100",
            port: 4242,
            callsign: "Alpha-1",
            approved: true
        )

        XCTAssertEqual(friend.deviceId, "device-1")
        XCTAssertEqual(friend.host, "192.168.1.100")
        XCTAssertEqual(friend.port, 4242)
        XCTAssertEqual(friend.callsign, "Alpha-1")
        XCTAssertTrue(friend.approved)
    }

    func testFriendCodable() throws {
        let friend = Friend(
            deviceId: "device-1",
            host: "192.168.1.100",
            port: 4242,
            callsign: "Alpha-1"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(friend)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Friend.self, from: data)

        XCTAssertEqual(decoded.deviceId, friend.deviceId)
        XCTAssertEqual(decoded.host, friend.host)
        XCTAssertEqual(decoded.port, friend.port)
    }
}

// MARK: - Night Vision Manager Tests

final class NightVisionManagerTests: XCTestCase {

    func testNightVisionManagerSingleton() {
        let manager1 = NightVisionManager.shared
        let manager2 = NightVisionManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    func testNightVisionManagerToggle() {
        let manager = NightVisionManager.shared
        let initialState = manager.isEnabled

        manager.toggle()
        XCTAssertNotEqual(manager.isEnabled, initialState)

        manager.toggle()
        XCTAssertEqual(manager.isEnabled, initialState)
    }

    func testNightVisionManagerEnable() {
        let manager = NightVisionManager.shared
        manager.enable()
        XCTAssertTrue(manager.isEnabled)
    }

    func testNightVisionManagerDisable() {
        let manager = NightVisionManager.shared
        manager.disable()
        XCTAssertFalse(manager.isEnabled)
    }

    func testNightVisionManagerSetColor() {
        let manager = NightVisionManager.shared
        manager.setColor(.red)
        XCTAssertEqual(manager.color, .red)

        manager.setColor(.green)
        XCTAssertEqual(manager.color, .green)
    }

    func testNightVisionManagerSetOpacity() {
        let manager = NightVisionManager.shared

        manager.setOpacity(0.5)
        XCTAssertEqual(manager.opacity, 0.5)

        // Test clamping
        manager.setOpacity(1.5)
        XCTAssertEqual(manager.opacity, 1.0)

        manager.setOpacity(-0.5)
        XCTAssertEqual(manager.opacity, 0.0)
    }

    func testNightVisionManagerCycleColor() {
        let manager = NightVisionManager.shared

        manager.setColor(.red)
        manager.cycleColor()
        XCTAssertEqual(manager.color, .green)

        manager.cycleColor()
        XCTAssertEqual(manager.color, .blue)

        manager.cycleColor()
        XCTAssertEqual(manager.color, .red) // Wraps around
    }

    func testNightVisionManagerStatusText() {
        let manager = NightVisionManager.shared

        manager.disable()
        XCTAssertEqual(manager.statusText, "Night Vision: Off")

        manager.enable()
        manager.setColor(.green)
        XCTAssertEqual(manager.statusText, "Night Vision: Green")
    }
}

// MARK: - Delivery Status Tests

final class DeliveryStatusTests: XCTestCase {

    func testDeliveryStatusRawValues() {
        XCTAssertEqual(DeliveryStatus.pending.rawValue, "PENDING")
        XCTAssertEqual(DeliveryStatus.sent.rawValue, "SENT")
        XCTAssertEqual(DeliveryStatus.delivered.rawValue, "DELIVERED")
        XCTAssertEqual(DeliveryStatus.read.rawValue, "READ")
        XCTAssertEqual(DeliveryStatus.failed.rawValue, "FAILED")
    }

    func testDeliveryStatusDisplayNames() {
        XCTAssertEqual(DeliveryStatus.pending.displayName, "Pending")
        XCTAssertEqual(DeliveryStatus.sent.displayName, "Sent")
        XCTAssertEqual(DeliveryStatus.delivered.displayName, "Delivered")
        XCTAssertEqual(DeliveryStatus.read.displayName, "Read")
        XCTAssertEqual(DeliveryStatus.failed.displayName, "Failed")
    }

    func testDeliveryStatusIcons() {
        for status in DeliveryStatus.allCases {
            XCTAssertFalse(status.icon.isEmpty)
        }
    }

    func testDeliveryStatusIsCompleted() {
        XCTAssertFalse(DeliveryStatus.pending.isCompleted)
        XCTAssertFalse(DeliveryStatus.sent.isCompleted)
        XCTAssertTrue(DeliveryStatus.delivered.isCompleted)
        XCTAssertTrue(DeliveryStatus.read.isCompleted)
        XCTAssertFalse(DeliveryStatus.failed.isCompleted)
    }
}

// MARK: - Status Tracking Utils Tests

final class StatusTrackingUtilsTests: XCTestCase {

    func testFormatTimestampJustNow() {
        let recent = Int64(Date().timeIntervalSince1970 * 1000) - 30000 // 30 seconds ago
        let formatted = StatusTrackingUtils.formatTimestamp(recent)
        XCTAssertEqual(formatted, "Just now")
    }

    func testFormatTimestampMinutesAgo() {
        let fiveMinutesAgo = Int64(Date().timeIntervalSince1970 * 1000) - 300000
        let formatted = StatusTrackingUtils.formatTimestamp(fiveMinutesAgo)
        XCTAssertEqual(formatted, "5m ago")
    }

    func testFormatTimestampHoursAgo() {
        let twoHoursAgo = Int64(Date().timeIntervalSince1970 * 1000) - 7200000
        let formatted = StatusTrackingUtils.formatTimestamp(twoHoursAgo)
        XCTAssertEqual(formatted, "2h ago")
    }
}

// MARK: - METHANE Response Type Tests

final class MethaneResponseTypeTests: XCTestCase {

    func testMethaneResponseTypeRawValues() {
        XCTAssertEqual(MethaneResponseType.acknowledged.rawValue, "ACKNOWLEDGED")
        XCTAssertEqual(MethaneResponseType.enRoute.rawValue, "EN_ROUTE")
        XCTAssertEqual(MethaneResponseType.onScene.rawValue, "ON_SCENE")
        XCTAssertEqual(MethaneResponseType.resourcesDeployed.rawValue, "RESOURCES_DEPLOYED")
        XCTAssertEqual(MethaneResponseType.unableToRespond.rawValue, "UNABLE_TO_RESPOND")
    }

    func testMethaneResponseTypeDisplayNames() {
        XCTAssertEqual(MethaneResponseType.acknowledged.displayName, "Acknowledged")
        XCTAssertEqual(MethaneResponseType.enRoute.displayName, "En Route")
        XCTAssertEqual(MethaneResponseType.onScene.displayName, "On Scene")
    }
}

// MARK: - MEDEVAC Priority Tests

final class MedevacPriorityTests: XCTestCase {

    func testMedevacPriorityRawValues() {
        XCTAssertEqual(MedevacPriority.urgent.rawValue, "URGENT")
        XCTAssertEqual(MedevacPriority.priority.rawValue, "PRIORITY")
        XCTAssertEqual(MedevacPriority.routine.rawValue, "ROUTINE")
        XCTAssertEqual(MedevacPriority.convenience.rawValue, "CONVENIENCE")
    }

    func testMedevacPriorityDisplayNames() {
        XCTAssertTrue(MedevacPriority.urgent.displayName.contains("T1"))
        XCTAssertTrue(MedevacPriority.priority.displayName.contains("T2"))
        XCTAssertTrue(MedevacPriority.routine.displayName.contains("T3"))
        XCTAssertTrue(MedevacPriority.convenience.displayName.contains("T4"))
    }

    func testMedevacPriorityColors() {
        XCTAssertEqual(MedevacPriority.urgent.color, "red")
        XCTAssertEqual(MedevacPriority.priority.color, "yellow")
        XCTAssertEqual(MedevacPriority.routine.color, "green")
        XCTAssertEqual(MedevacPriority.convenience.color, "blue")
    }
}

// MARK: - Delivery Summary Tests

final class DeliverySummaryTests: XCTestCase {

    func testDeliverySummaryEmpty() {
        let summary = DeliverySummary(from: [])

        XCTAssertEqual(summary.total, 0)
        XCTAssertEqual(summary.summaryText, "No recipients")
    }

    func testDeliverySummaryFullyRead() {
        let summary = DeliverySummary(from: [.read, .read, .read])

        XCTAssertTrue(summary.isFullyRead)
        XCTAssertTrue(summary.isFullyDelivered)
        XCTAssertEqual(summary.summaryText, "Read by all (3)")
    }

    func testDeliverySummaryFullyDelivered() {
        let summary = DeliverySummary(from: [.delivered, .delivered, .read])

        XCTAssertFalse(summary.isFullyRead)
        XCTAssertTrue(summary.isFullyDelivered)
        XCTAssertEqual(summary.summaryText, "Delivered to all (3)")
    }

    func testDeliverySummaryPartial() {
        let summary = DeliverySummary(from: [.sent, .delivered, .pending])

        XCTAssertFalse(summary.isFullyDelivered)
        XCTAssertEqual(summary.summaryText, "Sent: 2/3")
    }

    func testDeliverySummaryWithFailures() {
        let summary = DeliverySummary(from: [.delivered, .failed, .sent])

        XCTAssertFalse(summary.isFullyDelivered)
        XCTAssertEqual(summary.summaryText, "Failed: 1/3")
    }
}

// MARK: - Banner Notification Type Tests

final class BannerNotificationTypeTests: XCTestCase {

    func testBannerNotificationTypeIcons() {
        XCTAssertEqual(BannerNotificationType.chat.icon, "message.fill")
        XCTAssertEqual(BannerNotificationType.info.icon, "info.circle.fill")
        XCTAssertEqual(BannerNotificationType.success.icon, "checkmark.circle.fill")
        XCTAssertEqual(BannerNotificationType.warning.icon, "exclamationmark.triangle.fill")
        XCTAssertEqual(BannerNotificationType.error.icon, "xmark.circle.fill")
    }
}

// MARK: - Banner Notification Tests

final class BannerNotificationTests: XCTestCase {

    func testBannerNotificationInitialization() {
        let notification = BannerNotification(
            type: .chat,
            title: "New Message",
            message: "Hello there!"
        )

        XCTAssertEqual(notification.type, .chat)
        XCTAssertEqual(notification.title, "New Message")
        XCTAssertEqual(notification.message, "Hello there!")
        XCTAssertEqual(notification.duration, 4.0)
    }

    func testBannerNotificationEquatable() {
        let notification1 = BannerNotification(
            id: "test-id",
            type: .info,
            message: "Test"
        )
        let notification2 = BannerNotification(
            id: "test-id",
            type: .warning,
            message: "Different"
        )

        XCTAssertEqual(notification1, notification2) // Same ID
    }
}
