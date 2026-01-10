import XCTest
@testable import sweTAK

final class ProfileTests: XCTestCase {

    // MARK: - MilitaryRole Tests

    func testMilitaryRoleRawValues() {
        XCTAssertEqual(MilitaryRole.none.rawValue, "NONE")
        XCTAssertEqual(MilitaryRole.companyCommander.rawValue, "COMPANY_COMMANDER")
        XCTAssertEqual(MilitaryRole.platoonLeader.rawValue, "PLATOON_LEADER")
        XCTAssertEqual(MilitaryRole.squadLeader.rawValue, "SQUAD_LEADER")
        XCTAssertEqual(MilitaryRole.soldier.rawValue, "SOLDIER")
    }

    func testMilitaryRoleDisplayNames() {
        XCTAssertEqual(MilitaryRole.none.displayName, "None")
        XCTAssertEqual(MilitaryRole.companyCommander.displayName, "Company Commander")
        XCTAssertEqual(MilitaryRole.assistantCompanyCommander.displayName, "Assistant Company Commander")
        XCTAssertEqual(MilitaryRole.troopLeader.displayName, "Troop Leader")
        XCTAssertEqual(MilitaryRole.platoonLeader.displayName, "Platoon Leader")
        XCTAssertEqual(MilitaryRole.squadLeader.displayName, "Squad Leader")
        XCTAssertEqual(MilitaryRole.staffMember.displayName, "Staff Member")
        XCTAssertEqual(MilitaryRole.soldier.displayName, "Soldier")
        XCTAssertEqual(MilitaryRole.other.displayName, "Other")
    }

    func testMilitaryRoleAbbreviations() {
        XCTAssertEqual(MilitaryRole.none.abbreviation, "")
        XCTAssertEqual(MilitaryRole.companyCommander.abbreviation, "CC")
        XCTAssertEqual(MilitaryRole.assistantCompanyCommander.abbreviation, "ACC")
        XCTAssertEqual(MilitaryRole.troopLeader.abbreviation, "TL")
        XCTAssertEqual(MilitaryRole.assistantTroopLeader.abbreviation, "ATL")
        XCTAssertEqual(MilitaryRole.platoonLeader.abbreviation, "PL")
        XCTAssertEqual(MilitaryRole.assistantPlatoonLeader.abbreviation, "APL")
        XCTAssertEqual(MilitaryRole.squadLeader.abbreviation, "SL")
        XCTAssertEqual(MilitaryRole.assistantSquadLeader.abbreviation, "ASL")
        XCTAssertEqual(MilitaryRole.staffMember.abbreviation, "Staff")
        XCTAssertEqual(MilitaryRole.soldier.abbreviation, "Soldier")
    }

    func testMilitaryRoleFromString() {
        // From raw value
        XCTAssertEqual(MilitaryRole.from("COMPANY_COMMANDER"), .companyCommander)
        XCTAssertEqual(MilitaryRole.from("PLATOON_LEADER"), .platoonLeader)
        XCTAssertEqual(MilitaryRole.from("SQUAD_LEADER"), .squadLeader)

        // From display name
        XCTAssertEqual(MilitaryRole.from("Company Commander"), .companyCommander)
        XCTAssertEqual(MilitaryRole.from("Platoon Leader"), .platoonLeader)

        // From abbreviation
        XCTAssertEqual(MilitaryRole.from("CC"), .companyCommander)
        XCTAssertEqual(MilitaryRole.from("PL"), .platoonLeader)
        XCTAssertEqual(MilitaryRole.from("SL"), .squadLeader)

        // Case insensitive
        XCTAssertEqual(MilitaryRole.from("company_commander"), .companyCommander)
        XCTAssertEqual(MilitaryRole.from("pl"), .platoonLeader)

        // Invalid returns none
        XCTAssertEqual(MilitaryRole.from("invalid"), .none)
        XCTAssertEqual(MilitaryRole.from(nil), .none)
        XCTAssertEqual(MilitaryRole.from(""), .none)
    }

    func testMilitaryRoleCaseIterable() {
        XCTAssertEqual(MilitaryRole.allCases.count, 12)
        XCTAssertTrue(MilitaryRole.allCases.contains(.none))
        XCTAssertTrue(MilitaryRole.allCases.contains(.companyCommander))
        XCTAssertTrue(MilitaryRole.allCases.contains(.soldier))
    }

    // MARK: - LocalProfile Tests

    func testLocalProfileCreation() {
        let profile = LocalProfile(
            callsign: "Alpha-1",
            nickname: "John",
            firstName: "John",
            lastName: "Doe",
            company: "1st Company",
            platoon: "2nd Platoon",
            squad: "Alpha Squad",
            phone: "+46701234567",
            email: "john.doe@example.com",
            role: .squadLeader
        )

        XCTAssertEqual(profile.callsign, "Alpha-1")
        XCTAssertEqual(profile.nickname, "John")
        XCTAssertEqual(profile.firstName, "John")
        XCTAssertEqual(profile.lastName, "Doe")
        XCTAssertEqual(profile.company, "1st Company")
        XCTAssertEqual(profile.platoon, "2nd Platoon")
        XCTAssertEqual(profile.squad, "Alpha Squad")
        XCTAssertEqual(profile.phone, "+46701234567")
        XCTAssertEqual(profile.email, "john.doe@example.com")
        XCTAssertEqual(profile.role, .squadLeader)
    }

    func testLocalProfileDefaultValues() {
        let profile = LocalProfile()

        XCTAssertEqual(profile.callsign, "")
        XCTAssertEqual(profile.nickname, "")
        XCTAssertEqual(profile.firstName, "")
        XCTAssertEqual(profile.lastName, "")
        XCTAssertEqual(profile.company, "")
        XCTAssertEqual(profile.platoon, "")
        XCTAssertEqual(profile.squad, "")
        XCTAssertEqual(profile.phone, "")
        XCTAssertEqual(profile.email, "")
        XCTAssertEqual(profile.role, .none)
    }

    func testLocalProfileCodable() throws {
        let original = LocalProfile(
            callsign: "Bravo-2",
            nickname: "Bob",
            firstName: "Robert",
            lastName: "Smith",
            company: "2nd Company",
            platoon: "1st Platoon",
            squad: "Bravo Squad",
            phone: "+46709876543",
            email: "bob.smith@example.com",
            role: .platoonLeader
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LocalProfile.self, from: data)

        XCTAssertEqual(decoded.callsign, original.callsign)
        XCTAssertEqual(decoded.nickname, original.nickname)
        XCTAssertEqual(decoded.firstName, original.firstName)
        XCTAssertEqual(decoded.lastName, original.lastName)
        XCTAssertEqual(decoded.company, original.company)
        XCTAssertEqual(decoded.platoon, original.platoon)
        XCTAssertEqual(decoded.squad, original.squad)
        XCTAssertEqual(decoded.phone, original.phone)
        XCTAssertEqual(decoded.email, original.email)
        XCTAssertEqual(decoded.role, original.role)
    }

    func testLocalProfileEquatable() {
        let profile1 = LocalProfile(
            callsign: "Alpha-1",
            nickname: "John",
            role: .squadLeader
        )

        let profile2 = LocalProfile(
            callsign: "Alpha-1",
            nickname: "John",
            role: .squadLeader
        )

        let profile3 = LocalProfile(
            callsign: "Alpha-2",
            nickname: "Jane",
            role: .soldier
        )

        XCTAssertEqual(profile1, profile2)
        XCTAssertNotEqual(profile1, profile3)
    }

    // MARK: - ContactProfile Tests

    func testContactProfileCreation() {
        let profile = ContactProfile(
            deviceId: "device-123",
            nickname: "Johnny",
            callsign: "Alpha-1",
            firstName: "John",
            lastName: "Doe",
            company: "1st Company",
            platoon: "2nd Platoon",
            squad: "Alpha Squad",
            mobile: "+46701234567",
            email: "john@example.com",
            role: .squadLeader
        )

        XCTAssertEqual(profile.id, "device-123")
        XCTAssertEqual(profile.deviceId, "device-123")
        XCTAssertEqual(profile.callsign, "Alpha-1")
        XCTAssertEqual(profile.nickname, "Johnny")
        XCTAssertEqual(profile.role, .squadLeader)
    }

    func testContactProfileDisplayName() {
        let withCallsign = ContactProfile(
            deviceId: "device-1",
            callsign: "Alpha-1"
        )
        XCTAssertEqual(withCallsign.displayName, "Alpha-1")

        let withNickname = ContactProfile(
            deviceId: "device-2",
            nickname: "Johnny"
        )
        XCTAssertEqual(withNickname.displayName, "Johnny")

        let withBoth = ContactProfile(
            deviceId: "device-3",
            nickname: "Johnny",
            callsign: "Alpha-1"
        )
        XCTAssertEqual(withBoth.displayName, "Alpha-1") // Callsign takes precedence

        let withNeither = ContactProfile(deviceId: "device-4")
        XCTAssertEqual(withNeither.displayName, "device-4")
    }

    func testContactProfileFullName() {
        let withBoth = ContactProfile(
            deviceId: "device-1",
            firstName: "John",
            lastName: "Doe"
        )
        XCTAssertEqual(withBoth.fullName, "John Doe")

        let firstOnly = ContactProfile(
            deviceId: "device-2",
            firstName: "John"
        )
        XCTAssertEqual(firstOnly.fullName, "John")

        let lastOnly = ContactProfile(
            deviceId: "device-3",
            lastName: "Doe"
        )
        XCTAssertEqual(lastOnly.fullName, "Doe")

        let neither = ContactProfile(deviceId: "device-4")
        XCTAssertNil(neither.fullName)
    }

    func testContactProfileIsOnline() {
        // Recently seen - should be online
        let recentProfile = ContactProfile(
            deviceId: "device-1",
            lastSeenMs: Int64(Date().timeIntervalSince1970 * 1000)
        )
        XCTAssertTrue(recentProfile.isOnline)

        // Old timestamp - should be offline
        let oldProfile = ContactProfile(
            deviceId: "device-2",
            lastSeenMs: Int64((Date().timeIntervalSince1970 - 600) * 1000) // 10 minutes ago
        )
        XCTAssertFalse(oldProfile.isOnline)
    }

    func testContactProfileToJSON() {
        let profile = ContactProfile(
            deviceId: "device-123",
            nickname: "Johnny",
            callsign: "Alpha-1",
            firstName: "John",
            lastName: "Doe",
            company: "1st Company",
            mobile: "+46701234567",
            role: .squadLeader
        )

        let json = profile.toJSON()

        XCTAssertEqual(json["deviceId"] as? String, "device-123")
        XCTAssertEqual(json["callsign"] as? String, "Alpha-1")
        XCTAssertEqual(json["nick"] as? String, "Johnny")
        XCTAssertEqual(json["first"] as? String, "John")
        XCTAssertEqual(json["last"] as? String, "Doe")
        XCTAssertEqual(json["company"] as? String, "1st Company")
        XCTAssertEqual(json["mobile"] as? String, "+46701234567")
        XCTAssertEqual(json["role"] as? String, "SQUAD_LEADER")
    }

    func testContactProfileFromJSON() {
        let json: [String: Any] = [
            "callsign": "Bravo-2",
            "nick": "Bobby",
            "first": "Robert",
            "last": "Smith",
            "company": "2nd Company",
            "platoon": "3rd Platoon",
            "squad": "Bravo Squad",
            "mobile": "+46709876543",
            "email": "bob@example.com",
            "role": "PLATOON_LEADER"
        ]

        let profile = ContactProfile.fromJSON(json, deviceId: "device-456", fromIp: "192.168.1.100")

        XCTAssertEqual(profile.deviceId, "device-456")
        XCTAssertEqual(profile.callsign, "Bravo-2")
        XCTAssertEqual(profile.nickname, "Bobby")
        XCTAssertEqual(profile.firstName, "Robert")
        XCTAssertEqual(profile.lastName, "Smith")
        XCTAssertEqual(profile.company, "2nd Company")
        XCTAssertEqual(profile.platoon, "3rd Platoon")
        XCTAssertEqual(profile.squad, "Bravo Squad")
        XCTAssertEqual(profile.mobile, "+46709876543")
        XCTAssertEqual(profile.email, "bob@example.com")
        XCTAssertEqual(profile.role, .platoonLeader)
        XCTAssertEqual(profile.fromIp, "192.168.1.100")
    }

    func testContactProfileFromJSONWithUnknownCallsign() {
        let json: [String: Any] = [
            "callsign": "Unknown",
            "nickname": "Test"
        ]

        let profile = ContactProfile.fromJSON(json, deviceId: "device-123")

        XCTAssertNil(profile.callsign) // "Unknown" should be converted to nil
        XCTAssertEqual(profile.nickname, "Test")
    }

    // MARK: - Friend Tests

    func testFriendCreation() {
        let friend = Friend(
            deviceId: "device-123",
            host: "192.168.1.100",
            port: 4242,
            callsign: "Alpha-1",
            approved: true,
            lastLat: 59.33,
            lastLon: 18.06
        )

        XCTAssertEqual(friend.id, "device-123")
        XCTAssertEqual(friend.deviceId, "device-123")
        XCTAssertEqual(friend.host, "192.168.1.100")
        XCTAssertEqual(friend.port, 4242)
        XCTAssertEqual(friend.callsign, "Alpha-1")
        XCTAssertTrue(friend.approved)
        XCTAssertEqual(friend.lastLat, 59.33)
        XCTAssertEqual(friend.lastLon, 18.06)
    }

    func testFriendDefaultValues() {
        let friend = Friend(
            deviceId: "device-456",
            host: "192.168.1.200",
            port: 4242
        )

        XCTAssertEqual(friend.callsign, "")
        XCTAssertTrue(friend.approved) // Default is approved
        XCTAssertNil(friend.lastLat)
        XCTAssertNil(friend.lastLon)
    }

    // MARK: - RemoteMarker Tests

    func testRemoteMarkerCreation() {
        let marker = RemoteMarker(
            deviceId: "device-123",
            callsign: "Alpha-1",
            nickname: "Johnny",
            lat: 59.33,
            lon: 18.06
        )

        XCTAssertEqual(marker.id, "device-123")
        XCTAssertEqual(marker.deviceId, "device-123")
        XCTAssertEqual(marker.callsign, "Alpha-1")
        XCTAssertEqual(marker.nickname, "Johnny")
        XCTAssertEqual(marker.lat, 59.33)
        XCTAssertEqual(marker.lon, 18.06)
    }

    // MARK: - SettingsViewModel Profile Tests

    func testSettingsViewModelSingleton() {
        let vm1 = SettingsViewModel.shared
        let vm2 = SettingsViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    func testSettingsViewModelHasDeviceId() {
        let vm = SettingsViewModel.shared
        XCTAssertFalse(vm.deviceId.isEmpty)
    }

    func testSettingsViewModelHasCallsign() {
        let vm = SettingsViewModel.shared
        // Callsign returns "Unknown" if profile.callsign is empty
        XCTAssertFalse(vm.callsign.isEmpty)
    }
}
