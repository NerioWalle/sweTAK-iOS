import XCTest
@testable import sweTAK

final class ContactUtilitiesTests: XCTestCase {

    // MARK: - Profile Merging Tests

    func testMergeProfilesPrefersPrimary() {
        let primary = ContactProfile(
            deviceId: "device-1",
            callsign: "Alpha-1",
            firstName: "John"
        )
        let secondary = ContactProfile(
            deviceId: "device-1",
            callsign: "Bravo-2",
            firstName: "Jane",
            lastName: "Doe"
        )

        let merged = ContactUtilities.mergeProfiles(primary, secondary)

        XCTAssertEqual(merged?.callsign, "Alpha-1") // Primary wins
        XCTAssertEqual(merged?.firstName, "John") // Primary wins
        XCTAssertEqual(merged?.lastName, "Doe") // Secondary fills gap
    }

    func testMergeProfilesWithNilPrimary() {
        let secondary = ContactProfile(
            deviceId: "device-1",
            callsign: "Alpha-1"
        )

        let merged = ContactUtilities.mergeProfiles(nil, secondary)

        XCTAssertEqual(merged?.callsign, "Alpha-1")
    }

    func testMergeProfilesWithNilSecondary() {
        let primary = ContactProfile(
            deviceId: "device-1",
            callsign: "Alpha-1"
        )

        let merged = ContactUtilities.mergeProfiles(primary, nil)

        XCTAssertEqual(merged?.callsign, "Alpha-1")
    }

    func testMergeProfilesBothNil() {
        let merged = ContactUtilities.mergeProfiles(nil, nil)
        XCTAssertNil(merged)
    }

    func testMergeProfilesIgnoresNullStrings() {
        let primary = ContactProfile(
            deviceId: "device-1",
            callsign: "null" // Should be treated as empty
        )
        let secondary = ContactProfile(
            deviceId: "device-1",
            callsign: "Alpha-1"
        )

        let merged = ContactUtilities.mergeProfiles(primary, secondary)

        XCTAssertEqual(merged?.callsign, "Alpha-1") // Secondary wins because primary is "null"
    }

    func testMergeProfilesPreservesLatestTimestamp() {
        let primary = ContactProfile(
            deviceId: "device-1",
            lastSeenMs: 1000
        )
        let secondary = ContactProfile(
            deviceId: "device-1",
            lastSeenMs: 2000
        )

        let merged = ContactUtilities.mergeProfiles(primary, secondary)

        XCTAssertEqual(merged?.lastSeenMs, 2000) // Max wins
    }

    // MARK: - Display Name Resolution Tests

    func testResolveDisplayNameWithCallsignAndNickname() {
        let contact = ContactProfile(
            deviceId: "device-1",
            nickname: "Johnny",
            callsign: "Alpha-1"
        )

        let displayName = ContactUtilities.resolveDisplayName(for: contact)

        XCTAssertEqual(displayName, "Alpha-1 - Johnny")
    }

    func testResolveDisplayNameWithCallsignOnly() {
        let contact = ContactProfile(
            deviceId: "device-1",
            callsign: "Alpha-1"
        )

        let displayName = ContactUtilities.resolveDisplayName(for: contact)

        XCTAssertEqual(displayName, "Alpha-1")
    }

    func testResolveDisplayNameWithNicknameOnly() {
        let contact = ContactProfile(
            deviceId: "device-1",
            nickname: "Johnny"
        )

        let displayName = ContactUtilities.resolveDisplayName(for: contact)

        XCTAssertEqual(displayName, "Johnny")
    }

    func testResolveDisplayNameWithFullName() {
        let contact = ContactProfile(
            deviceId: "device-1",
            firstName: "John",
            lastName: "Doe"
        )

        let displayName = ContactUtilities.resolveDisplayName(for: contact)

        XCTAssertEqual(displayName, "John Doe")
    }

    func testResolveDisplayNameFallsBackToDeviceId() {
        let contact = ContactProfile(deviceId: "device-123-abc")

        let displayName = ContactUtilities.resolveDisplayName(for: contact)

        XCTAssertEqual(displayName, "device-1") // First 8 chars
    }

    func testResolveDisplayNameIgnoresUnknownCallsign() {
        let contact = ContactProfile(
            deviceId: "device-1",
            nickname: "Johnny",
            callsign: "Unknown"
        )

        let displayName = ContactUtilities.resolveDisplayName(for: contact)

        XCTAssertEqual(displayName, "Johnny") // Falls back to nickname
    }

    // MARK: - Callsign Resolution Tests

    func testResolveCallsign() {
        let contact = ContactProfile(
            deviceId: "device-1",
            callsign: "Alpha-1"
        )

        let callsign = ContactUtilities.resolveCallsign(for: contact)

        XCTAssertEqual(callsign, "Alpha-1")
    }

    func testResolveCallsignReturnsUnknownForEmpty() {
        let contact = ContactProfile(deviceId: "device-1")

        let callsign = ContactUtilities.resolveCallsign(for: contact)

        XCTAssertEqual(callsign, "Unknown")
    }

    func testResolveCallsignReturnsUnknownForNullString() {
        let contact = ContactProfile(
            deviceId: "device-1",
            callsign: "unknown"
        )

        let callsign = ContactUtilities.resolveCallsign(for: contact)

        XCTAssertEqual(callsign, "Unknown")
    }

    // MARK: - Last Seen Formatting Tests

    func testFormatLastSeenJustNow() {
        let timestamp = Date.currentMillis - 30_000 // 30 seconds ago

        let formatted = ContactUtilities.formatLastSeen(timestamp)

        XCTAssertEqual(formatted, "Just now")
    }

    func testFormatLastSeenMinutesAgo() {
        let timestamp = Date.currentMillis - 300_000 // 5 minutes ago

        let formatted = ContactUtilities.formatLastSeen(timestamp)

        XCTAssertEqual(formatted, "5m ago")
    }

    func testFormatLastSeenHoursAgo() {
        let timestamp = Date.currentMillis - 7_200_000 // 2 hours ago

        let formatted = ContactUtilities.formatLastSeen(timestamp)

        XCTAssertEqual(formatted, "2h ago")
    }

    func testFormatLastSeenDaysAgo() {
        let timestamp = Date.currentMillis - 172_800_000 // 2 days ago

        let formatted = ContactUtilities.formatLastSeen(timestamp)

        XCTAssertEqual(formatted, "2d ago")
    }

    // MARK: - Online Status Tests

    func testIsOnlineRecent() {
        let contact = ContactProfile(
            deviceId: "device-1",
            lastSeenMs: Date.currentMillis - 60_000 // 1 minute ago
        )

        XCTAssertTrue(ContactUtilities.isOnline(contact))
    }

    func testIsOnlineOld() {
        let contact = ContactProfile(
            deviceId: "device-1",
            lastSeenMs: Date.currentMillis - 600_000 // 10 minutes ago
        )

        XCTAssertFalse(ContactUtilities.isOnline(contact))
    }

    func testIsOnlineNoTimestamp() {
        let contact = ContactProfile(
            deviceId: "device-1",
            lastSeenMs: 0
        )

        XCTAssertFalse(ContactUtilities.isOnline(contact))
    }

    // MARK: - Contact Filtering Tests

    func testFilterForChatExcludesSelf() {
        let contacts = [
            ContactProfile(deviceId: "device-1", callsign: "Alpha-1"),
            ContactProfile(deviceId: "my-device", callsign: "Me")
        ]

        let filtered = ContactUtilities.filterForChat(
            contacts: contacts,
            blockedIds: [],
            myDeviceId: "my-device"
        )

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.deviceId, "device-1")
    }

    func testFilterForChatExcludesBlocked() {
        let contacts = [
            ContactProfile(deviceId: "device-1", callsign: "Alpha-1"),
            ContactProfile(deviceId: "device-2", callsign: "Bravo-2")
        ]

        let filtered = ContactUtilities.filterForChat(
            contacts: contacts,
            blockedIds: ["device-2"],
            myDeviceId: "my-device"
        )

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.deviceId, "device-1")
    }

    func testFilterForChatExcludesUnknown() {
        let contacts = [
            ContactProfile(deviceId: "device-1", callsign: "Alpha-1"),
            ContactProfile(deviceId: "device-2", callsign: "Unknown"),
            ContactProfile(deviceId: "device-3") // No callsign or nickname
        ]

        let filtered = ContactUtilities.filterForChat(
            contacts: contacts,
            blockedIds: [],
            myDeviceId: "my-device"
        )

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.deviceId, "device-1")
    }

    // MARK: - Sorting Tests

    func testSortByCallsign() {
        let contacts = [
            ContactProfile(deviceId: "device-1", callsign: "Charlie-3"),
            ContactProfile(deviceId: "device-2", callsign: "Alpha-1"),
            ContactProfile(deviceId: "device-3", callsign: "Bravo-2")
        ]

        let sorted = ContactUtilities.sortByCallsign(contacts)

        XCTAssertEqual(sorted[0].callsign, "Alpha-1")
        XCTAssertEqual(sorted[1].callsign, "Bravo-2")
        XCTAssertEqual(sorted[2].callsign, "Charlie-3")
    }

    func testSortByLastSeen() {
        let contacts = [
            ContactProfile(deviceId: "device-1", lastSeenMs: 1000),
            ContactProfile(deviceId: "device-2", lastSeenMs: 3000),
            ContactProfile(deviceId: "device-3", lastSeenMs: 2000)
        ]

        let sorted = ContactUtilities.sortByLastSeen(contacts)

        XCTAssertEqual(sorted[0].deviceId, "device-2") // Most recent first
        XCTAssertEqual(sorted[1].deviceId, "device-3")
        XCTAssertEqual(sorted[2].deviceId, "device-1")
    }

    // MARK: - String Extension Tests

    func testCleanedForProfileWithValidString() {
        let result = "John".cleanedForProfile
        XCTAssertEqual(result, "John")
    }

    func testCleanedForProfileWithNullString() {
        let result = "null".cleanedForProfile
        XCTAssertNil(result)
    }

    func testCleanedForProfileWithUnknownString() {
        let result = "Unknown".cleanedForProfile
        XCTAssertNil(result)
    }

    func testCleanedForProfileWithEmptyString() {
        let result = "".cleanedForProfile
        XCTAssertNil(result)
    }

    func testCleanedForProfileWithWhitespace() {
        let result = "   ".cleanedForProfile
        XCTAssertNil(result)
    }

    // MARK: - LongPressFormType Tests

    func testLongPressFormTypeDisplayNames() {
        XCTAssertEqual(LongPressFormType.sevenS.displayName, "7S (Contact Report)")
        XCTAssertEqual(LongPressFormType.ifs.displayName, "IFS (Indirect Fire)")
    }

    func testLongPressFormTypeIcons() {
        XCTAssertEqual(LongPressFormType.sevenS.icon, "doc.text")
        XCTAssertEqual(LongPressFormType.ifs.icon, "scope")
    }

    func testLongPressFormTypeCaseIterable() {
        XCTAssertEqual(LongPressFormType.allCases.count, 2)
    }

    // MARK: - LongPressMenuLevel Tests

    func testLongPressMenuLevelRawValues() {
        XCTAssertEqual(LongPressMenuLevel.root.rawValue, "ROOT")
        XCTAssertEqual(LongPressMenuLevel.pin.rawValue, "PIN")
        XCTAssertEqual(LongPressMenuLevel.form.rawValue, "FORM")
    }
}
