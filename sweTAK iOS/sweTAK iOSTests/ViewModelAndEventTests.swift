import XCTest
import Combine
@testable import sweTAK

// MARK: - Profile ViewModel Tests

final class ProfileViewModelTests: XCTestCase {

    func testSharedInstance() {
        let vm1 = ProfileViewModel.shared
        let vm2 = ProfileViewModel.shared
        XCTAssertTrue(vm1 === vm2)
    }

    func testInitialState() {
        let vm = ProfileViewModel.shared

        // Should have some callsign (default or saved)
        XCTAssertFalse(vm.callsign.isEmpty)
    }

    func testMakeEditableProfile() {
        let vm = ProfileViewModel.shared

        let editable = vm.makeEditableProfile()

        // Should match current profile
        XCTAssertEqual(editable.callsign, vm.profile.callsign)
        XCTAssertEqual(editable.nickname, vm.profile.nickname)
        XCTAssertEqual(editable.role, vm.profile.role)
    }

    func testProfileValidationCallsignRequired() {
        let vm = ProfileViewModel.shared

        // Save empty callsign - should fail validation
        let emptyProfile = EditableProfile(
            callsign: "",
            nickname: "Test"
        )

        vm.saveEditable(emptyProfile)

        XCTAssertFalse(vm.validationErrors.isEmpty)
        XCTAssertTrue(vm.validationErrors.contains { $0.contains("Callsign") })
    }

    func testProfileValidationCallsignLength() {
        let vm = ProfileViewModel.shared

        // Single character callsign should fail
        let shortProfile = EditableProfile(callsign: "A")
        vm.saveEditable(shortProfile)
        XCTAssertTrue(vm.validationErrors.contains { $0.contains("2 characters") })

        // Very long callsign should fail
        let longProfile = EditableProfile(callsign: String(repeating: "A", count: 30))
        vm.saveEditable(longProfile)
        XCTAssertTrue(vm.validationErrors.contains { $0.contains("20 characters") })
    }

    func testProfileValidationEmailFormat() {
        let vm = ProfileViewModel.shared

        // Invalid email
        let invalidEmail = EditableProfile(
            callsign: "TestCallsign",
            email: "not-an-email"
        )

        vm.saveEditable(invalidEmail)
        XCTAssertTrue(vm.validationErrors.contains { $0.contains("email") })
    }

    func testProfileValidationPhoneFormat() {
        let vm = ProfileViewModel.shared

        // Invalid phone
        let invalidPhone = EditableProfile(
            callsign: "TestCallsign",
            phone: "abc"
        )

        vm.saveEditable(invalidPhone)
        XCTAssertTrue(vm.validationErrors.contains { $0.contains("phone") })
    }

    func testValidProfileSaves() {
        let vm = ProfileViewModel.shared

        let validProfile = EditableProfile(
            callsign: "ValidCallsign",
            nickname: "ValidNick",
            firstName: "Test",
            lastName: "User",
            phone: "+46123456789",
            email: "test@example.com",
            role: .squadLeader
        )

        vm.saveEditable(validProfile)

        // Should have no errors
        XCTAssertTrue(vm.validationErrors.isEmpty)

        // Profile should be updated
        XCTAssertEqual(vm.profile.callsign, "ValidCallsign")
        XCTAssertTrue(vm.isConfigured)
    }

    func testAsContactProfile() {
        let vm = ProfileViewModel.shared
        let deviceId = "test-device-123"

        let contact = vm.asContactProfile(deviceId: deviceId)

        XCTAssertEqual(contact.deviceId, deviceId)
    }
}

// MARK: - Refresh Bus Tests

final class RefreshBusTests: XCTestCase {

    func testSharedInstance() {
        let bus1 = RefreshBus.shared
        let bus2 = RefreshBus.shared
        XCTAssertTrue(bus1 === bus2)
    }

    func testEmitAndSubscribe() {
        let bus = RefreshBus.shared
        var receivedEvent: RefreshEvent?
        var cancellables = Set<AnyCancellable>()

        let expectation = XCTestExpectation(description: "Event received")

        bus.events
            .sink { event in
                receivedEvent = event
                expectation.fulfill()
            }
            .store(in: &cancellables)

        bus.emitProfileChanged()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedEvent, .profileChanged)
    }

    func testSubscribeToSpecificEvent() {
        let bus = RefreshBus.shared
        var eventCount = 0
        var cancellable: AnyCancellable?

        let expectation = XCTestExpectation(description: "Profile event received")

        cancellable = bus.subscribe(to: .profileChanged) {
            eventCount += 1
            expectation.fulfill()
        }

        // Emit profile changed - should trigger
        bus.emitProfileChanged()

        // Emit other events - should NOT trigger
        bus.emitSettingsChanged()
        bus.emitContactsChanged()

        wait(for: [expectation], timeout: 1.0)

        // Small delay to ensure other events don't trigger
        let additionalWait = XCTestExpectation(description: "Wait")
        additionalWait.isInverted = true
        wait(for: [additionalWait], timeout: 0.5)

        XCTAssertEqual(eventCount, 1)

        cancellable?.cancel()
    }

    func testSubscribeToMultipleEvents() {
        let bus = RefreshBus.shared
        var receivedEvents: [RefreshEvent] = []
        var cancellable: AnyCancellable?

        let expectation = XCTestExpectation(description: "Events received")
        expectation.expectedFulfillmentCount = 2

        cancellable = bus.subscribe(to: [.profileChanged, .settingsChanged]) { event in
            receivedEvents.append(event)
            expectation.fulfill()
        }

        bus.emitProfileChanged()
        bus.emitSettingsChanged()
        bus.emitContactsChanged()  // Should not be captured

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(receivedEvents.count, 2)
        XCTAssertTrue(receivedEvents.contains(.profileChanged))
        XCTAssertTrue(receivedEvents.contains(.settingsChanged))
        XCTAssertFalse(receivedEvents.contains(.contactsChanged))

        cancellable?.cancel()
    }

    func testAllEventTypes() {
        let bus = RefreshBus.shared

        // Verify all event emitters work
        bus.emitProfileChanged()
        bus.emitSettingsChanged()
        bus.emitContactsChanged()
        bus.emitPinsChanged()
        bus.emitChatChanged()
        bus.emitConnectionChanged()
        bus.emitTransportModeChanged()
        bus.emitSyncRequested()
        bus.emitMapRefresh()
        bus.emitCustom("test-event")

        // No crash = success
        XCTAssertTrue(true)
    }

    func testCustomEvent() {
        let bus = RefreshBus.shared
        var receivedEvent: RefreshEvent?
        var cancellables = Set<AnyCancellable>()

        let expectation = XCTestExpectation(description: "Custom event received")

        bus.events
            .sink { event in
                if case .custom(let name) = event {
                    receivedEvent = event
                    XCTAssertEqual(name, "my-custom-event")
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        bus.emitCustom("my-custom-event")

        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedEvent)
    }

    func testProfileChangesPublisher() {
        let bus = RefreshBus.shared
        var triggered = false
        var cancellables = Set<AnyCancellable>()

        let expectation = XCTestExpectation(description: "Profile changes triggered")

        bus.profileChanges
            .sink {
                triggered = true
                expectation.fulfill()
            }
            .store(in: &cancellables)

        bus.emitProfileChanged()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(triggered)
    }
}

// MARK: - Settings Data Store Tests

final class SettingsDataStoreTests: XCTestCase {

    func testSharedInstance() {
        let store1 = SettingsDataStore.shared
        let store2 = SettingsDataStore.shared
        XCTAssertTrue(store1 === store2)
    }

    func testGetDefaultValue() {
        let store = SettingsDataStore.shared

        // Clear any existing value
        store.remove(SettingsKeys.DarkMode())

        // Should return default
        let isDarkMode = store.get(SettingsKeys.DarkMode())
        XCTAssertFalse(isDarkMode)  // Default is false
    }

    func testSetAndGetValue() {
        let store = SettingsDataStore.shared

        // Set a value
        store.set(SettingsKeys.DarkMode(), value: true)

        // Get the value back
        let isDarkMode = store.get(SettingsKeys.DarkMode())
        XCTAssertTrue(isDarkMode)

        // Reset for other tests
        store.set(SettingsKeys.DarkMode(), value: false)
    }

    func testObserveChanges() {
        let store = SettingsDataStore.shared
        var cancellables = Set<AnyCancellable>()

        var receivedValues: [Bool] = []
        let expectation = XCTestExpectation(description: "Value changes observed")
        expectation.expectedFulfillmentCount = 2  // Initial + change

        store.observe(SettingsKeys.DarkMode())
            .sink { value in
                receivedValues.append(value)
                if receivedValues.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        store.set(SettingsKeys.DarkMode(), value: true)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(receivedValues.count, 2)

        // Reset
        store.set(SettingsKeys.DarkMode(), value: false)
    }

    func testRemoveValue() {
        let store = SettingsDataStore.shared
        let key = SettingsKeys.Nickname()

        // Set a value
        store.set(key, value: "TestNickname")
        XCTAssertEqual(store.get(key), "TestNickname")

        // Remove it
        store.remove(key)

        // Should return default
        XCTAssertEqual(store.get(key), "")  // Default is empty string
    }

    func testExistsCheck() {
        let store = SettingsDataStore.shared
        let key = SettingsKeys.Nickname()

        // Remove any existing value
        store.remove(key)
        XCTAssertFalse(store.exists(key))

        // Set a value
        store.set(key, value: "TestNickname")
        XCTAssertTrue(store.exists(key))

        // Clean up
        store.remove(key)
    }

    func testPrimitiveAccessors() {
        let store = SettingsDataStore.shared

        // String
        store.setString("test.string", value: "Hello")
        XCTAssertEqual(store.getString("test.string"), "Hello")

        // Int
        store.setInt("test.int", value: 42)
        XCTAssertEqual(store.getInt("test.int"), 42)

        // Bool
        store.setBool("test.bool", value: true)
        XCTAssertTrue(store.getBool("test.bool"))

        // Defaults
        XCTAssertEqual(store.getString("nonexistent", default: "default"), "default")
        XCTAssertEqual(store.getInt("nonexistent", default: 99), 99)
        XCTAssertFalse(store.getBool("nonexistent", default: false))
    }

    func testConvenienceProperties() {
        let store = SettingsDataStore.shared

        // Test isDarkMode property
        store.isDarkMode = true
        XCTAssertTrue(store.isDarkMode)
        store.isDarkMode = false
        XCTAssertFalse(store.isDarkMode)

        // Test coordinateFormat property
        store.coordinateFormat = .dms
        XCTAssertEqual(store.coordinateFormat, .dms)

        // Test unitSystem property
        store.unitSystem = .imperial
        XCTAssertEqual(store.unitSystem, .imperial)

        // Test transportMode property
        store.transportMode = .mqtt
        XCTAssertEqual(store.transportMode, .mqtt)

        // Reset
        store.transportMode = .localUDP
        store.unitSystem = .metric
        store.coordinateFormat = .mgrs
    }

    func testDeviceIdGeneration() {
        let store = SettingsDataStore.shared

        let deviceId = store.deviceId

        // Should be a valid UUID string
        XCTAssertFalse(deviceId.isEmpty)
        XCTAssertNotNil(UUID(uuidString: deviceId))

        // Should be persistent
        XCTAssertEqual(store.deviceId, deviceId)
    }

    func testMqttProperties() {
        let store = SettingsDataStore.shared

        store.mqttHost = "test.mqtt.server"
        XCTAssertEqual(store.mqttHost, "test.mqtt.server")

        store.mqttPort = 1883
        XCTAssertEqual(store.mqttPort, 1883)

        store.mqttUseTls = false
        XCTAssertFalse(store.mqttUseTls)

        // Reset
        store.mqttHost = ""
        store.mqttPort = 8883
        store.mqttUseTls = true
    }

    func testExportAll() {
        let store = SettingsDataStore.shared

        // Set some values
        store.set(SettingsKeys.Callsign(), value: "ExportTest")
        store.set(SettingsKeys.DarkMode(), value: true)

        let exported = store.exportAll()

        // Should have swetak prefixed keys
        let swetakKeys = exported.keys.filter { $0.hasPrefix("swetak.") }
        XCTAssertFalse(swetakKeys.isEmpty)

        // Reset
        store.set(SettingsKeys.DarkMode(), value: false)
    }
}

// MARK: - Editable Profile Tests

final class EditableProfileTests: XCTestCase {

    func testDefaultInit() {
        let profile = EditableProfile()

        XCTAssertTrue(profile.callsign.isEmpty)
        XCTAssertTrue(profile.nickname.isEmpty)
        XCTAssertTrue(profile.firstName.isEmpty)
        XCTAssertTrue(profile.lastName.isEmpty)
        XCTAssertEqual(profile.role, .none)
    }

    func testInitWithValues() {
        let profile = EditableProfile(
            callsign: "Alpha-1",
            nickname: "Al",
            firstName: "John",
            lastName: "Doe",
            company: "1st Company",
            platoon: "2nd Platoon",
            squad: "3rd Squad",
            phone: "+46123456789",
            email: "john@example.com",
            role: .platoonLeader
        )

        XCTAssertEqual(profile.callsign, "Alpha-1")
        XCTAssertEqual(profile.nickname, "Al")
        XCTAssertEqual(profile.firstName, "John")
        XCTAssertEqual(profile.lastName, "Doe")
        XCTAssertEqual(profile.company, "1st Company")
        XCTAssertEqual(profile.platoon, "2nd Platoon")
        XCTAssertEqual(profile.squad, "3rd Squad")
        XCTAssertEqual(profile.phone, "+46123456789")
        XCTAssertEqual(profile.email, "john@example.com")
        XCTAssertEqual(profile.role, .platoonLeader)
    }

    func testMutability() {
        var profile = EditableProfile()

        profile.callsign = "Changed"
        profile.role = .squadLeader

        XCTAssertEqual(profile.callsign, "Changed")
        XCTAssertEqual(profile.role, .squadLeader)
    }
}

// MARK: - Refresh Event Tests

final class RefreshEventTests: XCTestCase {

    func testEquality() {
        XCTAssertEqual(RefreshEvent.profileChanged, RefreshEvent.profileChanged)
        XCTAssertNotEqual(RefreshEvent.profileChanged, RefreshEvent.settingsChanged)
    }

    func testCustomEventEquality() {
        XCTAssertEqual(RefreshEvent.custom("test"), RefreshEvent.custom("test"))
        XCTAssertNotEqual(RefreshEvent.custom("test1"), RefreshEvent.custom("test2"))
    }
}

// MARK: - Settings Keys Tests

final class SettingsKeysTests: XCTestCase {

    func testKeyStrings() {
        XCTAssertEqual(SettingsKeys.Callsign().key, "swetak.profile.callsign")
        XCTAssertEqual(SettingsKeys.DarkMode().key, "swetak.display.dark_mode")
        XCTAssertEqual(SettingsKeys.MqttHost().key, "swetak.mqtt.host")
        XCTAssertEqual(SettingsKeys.TransportModeKey().key, "swetak.network.transport_mode")
    }

    func testDefaultValues() {
        XCTAssertTrue(SettingsKeys.Callsign().defaultValue.isEmpty)
        XCTAssertFalse(SettingsKeys.DarkMode().defaultValue)
        XCTAssertEqual(SettingsKeys.MqttPort().defaultValue, 8883)
        XCTAssertTrue(SettingsKeys.MqttUseTls().defaultValue)
        XCTAssertEqual(SettingsKeys.UdpPort().defaultValue, 4242)
    }
}
