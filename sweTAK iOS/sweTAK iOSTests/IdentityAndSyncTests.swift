import XCTest
@testable import sweTAK

// MARK: - Local Profile Tests

final class LocalProfileTests: XCTestCase {

    func testLocalProfileDefaultInit() {
        let profile = LocalProfile()

        XCTAssertTrue(profile.callsign.isEmpty)
        XCTAssertTrue(profile.nickname.isEmpty)
        XCTAssertTrue(profile.firstName.isEmpty)
        XCTAssertTrue(profile.lastName.isEmpty)
        XCTAssertTrue(profile.company.isEmpty)
        XCTAssertTrue(profile.platoon.isEmpty)
        XCTAssertTrue(profile.squad.isEmpty)
        XCTAssertTrue(profile.phone.isEmpty)
        XCTAssertTrue(profile.email.isEmpty)
        XCTAssertEqual(profile.role, .none)
    }

    func testLocalProfileWithValues() {
        let profile = LocalProfile(
            callsign: "Alpha-1",
            nickname: "Johnny",
            firstName: "John",
            lastName: "Doe",
            company: "1st Company",
            platoon: "2nd Platoon",
            squad: "3rd Squad",
            phone: "+46123456789",
            email: "john@example.com",
            role: .squadLeader
        )

        XCTAssertEqual(profile.callsign, "Alpha-1")
        XCTAssertEqual(profile.nickname, "Johnny")
        XCTAssertEqual(profile.firstName, "John")
        XCTAssertEqual(profile.lastName, "Doe")
        XCTAssertEqual(profile.company, "1st Company")
        XCTAssertEqual(profile.platoon, "2nd Platoon")
        XCTAssertEqual(profile.squad, "3rd Squad")
        XCTAssertEqual(profile.phone, "+46123456789")
        XCTAssertEqual(profile.email, "john@example.com")
        XCTAssertEqual(profile.role, .squadLeader)
    }

    func testLocalProfileCodable() throws {
        let profile = LocalProfile(
            callsign: "Bravo-2",
            nickname: "Mike",
            role: .platoonLeader
        )

        let encoded = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(LocalProfile.self, from: encoded)

        XCTAssertEqual(profile.callsign, decoded.callsign)
        XCTAssertEqual(profile.nickname, decoded.nickname)
        XCTAssertEqual(profile.role, decoded.role)
    }
}

// MARK: - Local Profile Store Tests

final class LocalProfileStoreTests: XCTestCase {

    func testSharedInstance() {
        let store1 = LocalProfileStore.shared
        let store2 = LocalProfileStore.shared
        XCTAssertTrue(store1 === store2)
    }

    func testResolveCallsignDefault() {
        // With empty profile, should return "Unknown"
        let callsign = LocalProfileStore.shared.resolveCallsign()
        XCTAssertFalse(callsign.isEmpty)
    }

    func testLoadProfile() {
        let profile = LocalProfileStore.shared.load()
        // Should not crash, returns default or saved profile
        XCTAssertNotNil(profile)
    }

    func testToContactProfile() {
        let deviceId = "test-device-123"
        let contactProfile = LocalProfileStore.shared.toContactProfile(deviceId: deviceId)

        XCTAssertEqual(contactProfile.deviceId, deviceId)
    }
}

// MARK: - Profile Repository Tests

final class ProfileRepositoryTests: XCTestCase {

    func testSharedInstance() {
        let repo1 = ProfileRepository.shared
        let repo2 = ProfileRepository.shared
        XCTAssertTrue(repo1 === repo2)
    }

    func testGetLocalProfile() {
        let profile = ProfileRepository.shared.getLocalProfile()
        XCTAssertNotNil(profile)
    }

    func testGetNonExistentContact() {
        let contact = ProfileRepository.shared.getContactProfile(deviceId: "non-existent-device")
        // May or may not exist depending on test state
        // Just verify no crash
        _ = contact
    }

    func testSaveAndRetrieveContact() {
        let contact = ContactProfile(
            deviceId: "test-device-\(UUID().uuidString)",
            callsign: "TestCallsign",
            firstName: "Test",
            lastName: "User"
        )

        ProfileRepository.shared.saveContactProfile(contact)

        let retrieved = ProfileRepository.shared.getContactProfile(deviceId: contact.deviceId)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.callsign, "TestCallsign")

        // Clean up
        ProfileRepository.shared.deleteContact(deviceId: contact.deviceId)
    }

    func testUpdateFromNetwork() {
        let deviceId = "network-device-\(UUID().uuidString)"

        ProfileRepository.shared.updateFromNetwork(
            deviceId: deviceId,
            callsign: "NetworkCallsign",
            nickname: "NetNick",
            fromHost: "192.168.1.100"
        )

        let contact = ProfileRepository.shared.getContactProfile(deviceId: deviceId)
        XCTAssertNotNil(contact)
        XCTAssertEqual(contact?.callsign, "NetworkCallsign")
        XCTAssertEqual(contact?.nickname, "NetNick")
        XCTAssertEqual(contact?.fromIp, "192.168.1.100")

        // Clean up
        ProfileRepository.shared.deleteContact(deviceId: deviceId)
    }

    func testSearchContacts() {
        // Add a test contact
        let contact = ContactProfile(
            deviceId: "search-test-\(UUID().uuidString)",
            callsign: "SearchableCallsign",
            firstName: "Searchable",
            lastName: "Person"
        )
        ProfileRepository.shared.saveContactProfile(contact)

        // Search should find it
        let results = ProfileRepository.shared.searchContacts(query: "Searchable")
        XCTAssertTrue(results.contains { $0.deviceId == contact.deviceId })

        // Clean up
        ProfileRepository.shared.deleteContact(deviceId: contact.deviceId)
    }
}

// MARK: - Pin Add Event Tests

final class PinAddEventTests: XCTestCase {

    func testPinAddEventInit() {
        let event = PinAddEvent(
            id: 12345,
            lat: 59.3293,
            lon: 18.0686,
            typeName: "FRIENDLY_UNIT",
            title: "Test Pin",
            description: "Test Description",
            createdAtMillis: 1234567890,
            originDeviceId: "test-device"
        )

        XCTAssertEqual(event.id, 12345)
        XCTAssertEqual(event.lat, 59.3293, accuracy: 0.0001)
        XCTAssertEqual(event.lon, 18.0686, accuracy: 0.0001)
        XCTAssertEqual(event.typeName, "FRIENDLY_UNIT")
        XCTAssertEqual(event.title, "Test Pin")
        XCTAssertEqual(event.originDeviceId, "test-device")
        XCTAssertNil(event.photoBase64)
    }

    func testPinAddEventFromNatoPin() {
        let pin = NatoPin(
            id: 99999,
            type: .enemyUnit,
            latitude: 60.0,
            longitude: 20.0,
            title: "Enemy Position",
            description: "Observed enemy",
            createdAtMillis: 9999999,
            originDeviceId: "origin-device"
        )

        let event = PinAddEvent(from: pin, deviceId: "my-device")

        XCTAssertEqual(event.id, pin.id)
        XCTAssertEqual(event.lat, pin.latitude)
        XCTAssertEqual(event.lon, pin.longitude)
        XCTAssertEqual(event.typeName, pin.type.rawValue)
        XCTAssertEqual(event.title, pin.title)
        XCTAssertEqual(event.originDeviceId, "origin-device")
    }
}

// MARK: - Pin Sync Coordinator Tests

final class PinSyncCoordinatorTests: XCTestCase {

    func testSharedInstance() {
        let coord1 = PinSyncCoordinator.shared
        let coord2 = PinSyncCoordinator.shared
        XCTAssertTrue(coord1 === coord2)
    }

    func testProviderConfiguration() {
        let coordinator = PinSyncCoordinator.shared

        var pinProviderCalled = false
        coordinator.provideLocalPins = {
            pinProviderCalled = true
            return []
        }

        var formProviderCalled = false
        coordinator.provideLocalLinkedForms = {
            formProviderCalled = true
            return []
        }

        // Trigger sync (will call providers)
        coordinator.syncAllPins(callsign: "Test", deviceId: "test-device")
        XCTAssertTrue(pinProviderCalled)

        coordinator.syncAllLinkedForms(callsign: "Test", deviceId: "test-device")
        XCTAssertTrue(formProviderCalled)

        // Clean up
        coordinator.provideLocalPins = nil
        coordinator.provideLocalLinkedForms = nil
    }

    func testSyncCallbacks() {
        let coordinator = PinSyncCoordinator.shared

        var startedCalled = false
        var completedCount: Int?

        coordinator.onSyncStarted = { startedCalled = true }
        coordinator.onSyncCompleted = { count in completedCount = count }

        // Provide empty pins
        coordinator.provideLocalPins = { [] }

        coordinator.syncAllPins(callsign: "Test", deviceId: "test-device")

        // Should complete with 0 pins
        XCTAssertEqual(completedCount, 0)

        // Clean up
        coordinator.provideLocalPins = nil
        coordinator.onSyncStarted = nil
        coordinator.onSyncCompleted = nil
    }
}

// MARK: - Tac Dispatcher Tests

final class TacDispatcherTests: XCTestCase {

    func testDeviceId() {
        let deviceId = TacDispatcher.deviceId
        XCTAssertFalse(deviceId.isEmpty)
    }

    func testCallsign() {
        let callsign = TacDispatcher.callsign
        XCTAssertFalse(callsign.isEmpty)
    }

    func testTransportMode() {
        let mode = TacDispatcher.transportMode
        // Should be a valid mode
        XCTAssertTrue(mode == .localUDP || mode == .mqtt)
    }
}

// MARK: - Chat Repository Tests

final class ChatRepositoryTests: XCTestCase {

    func testSharedInstance() {
        let repo1 = InMemoryChatRepository.shared
        let repo2 = InMemoryChatRepository.shared
        XCTAssertTrue(repo1 === repo2)
    }

    func testGetOrCreateThread() {
        let repo = InMemoryChatRepository.shared
        let peerDeviceId = "test-peer-\(UUID().uuidString)"

        let thread = repo.getOrCreateThread(
            peerDeviceId: peerDeviceId,
            peerCallsign: "TestPeer",
            peerNickname: "Tester"
        )

        XCTAssertEqual(thread.id, peerDeviceId)
        XCTAssertEqual(thread.participantDeviceId, peerDeviceId)
        XCTAssertEqual(thread.participantCallsign, "TestPeer")
        XCTAssertEqual(thread.participantNickname, "Tester")

        // Clean up
        repo.deleteThread(threadId: peerDeviceId)
    }

    func testIncomingMessage() async {
        let repo = InMemoryChatRepository.shared
        let threadId = "incoming-test-\(UUID().uuidString)"

        let message = ChatMessage(
            threadId: threadId,
            fromDeviceId: "sender-device",
            toDeviceId: "my-device",
            text: "Hello from test",
            direction: .incoming
        )

        await repo.onIncomingMessage(message: message)

        let messages = repo.getMessages(for: threadId)
        XCTAssertFalse(messages.isEmpty)
        XCTAssertEqual(messages.first?.text, "Hello from test")

        let thread = repo.getThread(id: threadId)
        XCTAssertNotNil(thread)
        XCTAssertEqual(thread?.unreadCount, 1)

        // Clean up
        repo.deleteThread(threadId: threadId)
    }

    func testMarkThreadAsRead() async {
        let repo = InMemoryChatRepository.shared
        let threadId = "read-test-\(UUID().uuidString)"

        // Add incoming message (creates unread)
        let message = ChatMessage(
            threadId: threadId,
            fromDeviceId: "sender",
            toDeviceId: "receiver",
            text: "Unread message",
            direction: .incoming
        )
        await repo.onIncomingMessage(message: message)

        // Verify unread
        var thread = repo.getThread(id: threadId)
        XCTAssertEqual(thread?.unreadCount, 1)

        // Mark as read
        await repo.markThreadAsRead(threadId: threadId)

        // Verify read
        thread = repo.getThread(id: threadId)
        XCTAssertEqual(thread?.unreadCount, 0)

        // Clean up
        repo.deleteThread(threadId: threadId)
    }

    func testUpdateThreadParticipant() {
        let repo = InMemoryChatRepository.shared
        let threadId = "update-test-\(UUID().uuidString)"

        // Create thread
        _ = repo.getOrCreateThread(
            peerDeviceId: threadId,
            peerCallsign: "OldCallsign",
            peerNickname: nil
        )

        // Update participant
        repo.updateThreadParticipant(
            threadId: threadId,
            callsign: "NewCallsign",
            nickname: "NewNickname"
        )

        let thread = repo.getThread(id: threadId)
        XCTAssertEqual(thread?.participantCallsign, "NewCallsign")
        XCTAssertEqual(thread?.participantNickname, "NewNickname")

        // Clean up
        repo.deleteThread(threadId: threadId)
    }
}

// MARK: - Chat Thread Tests

final class ChatThreadTests: XCTestCase {

    func testChatThreadInit() {
        let thread = ChatThread(
            id: "thread-1",
            participantDeviceId: "device-1",
            participantCallsign: "Alpha",
            participantNickname: "Al",
            lastMessageText: "Hello",
            lastMessageTimestamp: 1234567890,
            unreadCount: 5
        )

        XCTAssertEqual(thread.id, "thread-1")
        XCTAssertEqual(thread.participantDeviceId, "device-1")
        XCTAssertEqual(thread.participantCallsign, "Alpha")
        XCTAssertEqual(thread.participantNickname, "Al")
        XCTAssertEqual(thread.lastMessageText, "Hello")
        XCTAssertEqual(thread.lastMessageTimestamp, 1234567890)
        XCTAssertEqual(thread.unreadCount, 5)
    }

    func testChatThreadCodable() throws {
        let thread = ChatThread(
            id: "thread-codable",
            participantDeviceId: "device-2",
            participantCallsign: "Bravo"
        )

        let encoded = try JSONEncoder().encode(thread)
        let decoded = try JSONDecoder().decode(ChatThread.self, from: encoded)

        XCTAssertEqual(thread.id, decoded.id)
        XCTAssertEqual(thread.participantDeviceId, decoded.participantDeviceId)
        XCTAssertEqual(thread.participantCallsign, decoded.participantCallsign)
    }
}

// MARK: - Chat Message Tests

final class ChatMessageTests: XCTestCase {

    func testChatMessageInit() {
        let message = ChatMessage(
            threadId: "thread-1",
            fromDeviceId: "sender",
            toDeviceId: "receiver",
            text: "Test message",
            direction: .outgoing
        )

        XCTAssertFalse(message.id.isEmpty)
        XCTAssertEqual(message.threadId, "thread-1")
        XCTAssertEqual(message.fromDeviceId, "sender")
        XCTAssertEqual(message.toDeviceId, "receiver")
        XCTAssertEqual(message.text, "Test message")
        XCTAssertEqual(message.direction, .outgoing)
        XCTAssertFalse(message.acknowledged)
    }

    func testChatDirectionRawValues() {
        XCTAssertEqual(ChatDirection.outgoing.rawValue, "OUTGOING")
        XCTAssertEqual(ChatDirection.incoming.rawValue, "INCOMING")
    }
}
