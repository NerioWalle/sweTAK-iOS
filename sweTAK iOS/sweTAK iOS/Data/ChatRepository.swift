import Foundation
import Combine
import os.log

// MARK: - Chat Repository Protocol

/// Protocol for chat data access
public protocol ChatRepositoryProtocol {
    /// Get messages for a specific thread
    func getMessagesForThread(threadId: String) -> AnyPublisher<[ChatMessage], Never>

    /// Observe a specific thread
    func observeThread(threadId: String) -> AnyPublisher<ChatThread?, Never>

    /// Observe all threads
    func observeAllThreads() -> AnyPublisher<[ChatThread], Never>

    /// Send a message
    func sendMessage(threadId: String, fromDeviceId: String, toDeviceId: String, text: String) async

    /// Mark thread as read
    func markThreadAsRead(threadId: String) async

    /// Handle incoming message
    func onIncomingMessage(message: ChatMessage) async
}

// MARK: - In-Memory Chat Repository

/// In-memory implementation of ChatRepository
/// Mirrors Android InMemoryChatRepository functionality
public final class InMemoryChatRepository: ChatRepositoryProtocol, ObservableObject {

    // MARK: - Singleton

    public static let shared = InMemoryChatRepository()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "ChatRepo")

    // MARK: - Published State

    /// All chat threads, sorted by last updated
    @Published public private(set) var threads: [ChatThread] = []

    /// Total unread count across all threads
    @Published public private(set) var totalUnreadCount: Int = 0

    // MARK: - Private Storage

    /// threadId -> messages
    private var messagesByThread: [String: [ChatMessage]] = [:]
    private let messagesSubject = CurrentValueSubject<[String: [ChatMessage]], Never>([:])

    /// threadId -> thread summary
    private var threadMap: [String: ChatThread] = [:]
    private let threadsSubject = CurrentValueSubject<[String: ChatThread], Never>([:])

    /// Thread-safe access
    private let lock = NSLock()

    // MARK: - Callbacks

    /// Called when a new message is added
    public var onMessageAdded: ((ChatMessage) -> Void)?

    /// Called when unread count changes
    public var onUnreadCountChanged: ((Int) -> Void)?

    // MARK: - Initialization

    private init() {
        loadFromStorage()
        setupSubscriptions()
    }

    // MARK: - Subscriptions

    private var cancellables = Set<AnyCancellable>()

    private func setupSubscriptions() {
        threadsSubject
            .map { map in
                map.values.sorted { $0.lastMessageTimestamp ?? 0 > $1.lastMessageTimestamp ?? 0 }
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sorted in
                self?.threads = sorted
                self?.totalUnreadCount = sorted.reduce(0) { $0 + $1.unreadCount }
                self?.onUnreadCountChanged?(self?.totalUnreadCount ?? 0)
            }
            .store(in: &cancellables)
    }

    // MARK: - ChatRepositoryProtocol

    public func getMessagesForThread(threadId: String) -> AnyPublisher<[ChatMessage], Never> {
        messagesSubject
            .map { map in
                (map[threadId] ?? []).sorted { $0.timestampMillis < $1.timestampMillis }
            }
            .eraseToAnyPublisher()
    }

    public func observeThread(threadId: String) -> AnyPublisher<ChatThread?, Never> {
        threadsSubject
            .map { $0[threadId] }
            .eraseToAnyPublisher()
    }

    public func observeAllThreads() -> AnyPublisher<[ChatThread], Never> {
        threadsSubject
            .map { map in
                map.values.sorted { ($0.lastMessageTimestamp ?? 0) > ($1.lastMessageTimestamp ?? 0) }
            }
            .eraseToAnyPublisher()
    }

    public func sendMessage(threadId: String, fromDeviceId: String, toDeviceId: String, text: String) async {
        let now = Date.currentMillis

        let message = ChatMessage(
            id: UUID().uuidString,
            threadId: threadId,
            fromDeviceId: fromDeviceId,
            toDeviceId: toDeviceId,
            text: text,
            timestampMillis: now,
            direction: .outgoing
        )

        lock.lock()
        addMessageInternal(message, incrementUnreadForIncoming: false)
        lock.unlock()

        // Send via transport
        TacDispatcher.sendChatMessage(
            threadId: threadId,
            fromDeviceId: fromDeviceId,
            toDeviceId: toDeviceId,
            text: text
        )

        logger.debug("Sent message to \(toDeviceId): \(text.prefix(50))")
    }

    public func markThreadAsRead(threadId: String) async {
        lock.lock()

        guard var thread = threadMap[threadId] else {
            lock.unlock()
            return
        }

        thread = ChatThread(
            id: thread.id,
            participantDeviceId: thread.participantDeviceId,
            participantCallsign: thread.participantCallsign,
            participantNickname: thread.participantNickname,
            lastMessageText: thread.lastMessageText,
            lastMessageTimestamp: thread.lastMessageTimestamp,
            unreadCount: 0
        )

        threadMap[threadId] = thread
        threadsSubject.send(threadMap)

        lock.unlock()

        saveToStorage()

        logger.debug("Marked thread \(threadId) as read")
    }

    public func onIncomingMessage(message: ChatMessage) async {
        lock.lock()
        addMessageInternal(message, incrementUnreadForIncoming: true)
        lock.unlock()

        onMessageAdded?(message)
        saveToStorage()

        logger.debug("Received message from \(message.fromDeviceId): \(message.text.prefix(50))")
    }

    // MARK: - Additional Public API

    /// Get all messages for a thread synchronously
    public func getMessages(for threadId: String) -> [ChatMessage] {
        lock.lock()
        defer { lock.unlock() }
        return (messagesByThread[threadId] ?? []).sorted { $0.timestampMillis < $1.timestampMillis }
    }

    /// Get a specific thread
    public func getThread(id: String) -> ChatThread? {
        lock.lock()
        defer { lock.unlock() }
        return threadMap[id]
    }

    /// Get or create a thread for a peer
    public func getOrCreateThread(
        peerDeviceId: String,
        peerCallsign: String?,
        peerNickname: String?
    ) -> ChatThread {
        lock.lock()
        defer { lock.unlock() }

        if let existing = threadMap[peerDeviceId] {
            return existing
        }

        let thread = ChatThread(
            id: peerDeviceId,
            participantDeviceId: peerDeviceId,
            participantCallsign: peerCallsign,
            participantNickname: peerNickname
        )

        threadMap[peerDeviceId] = thread
        threadsSubject.send(threadMap)

        return thread
    }

    /// Mark a message as acknowledged
    public func markMessageAcknowledged(messageId: String, threadId: String) {
        lock.lock()

        guard var messages = messagesByThread[threadId] else {
            lock.unlock()
            return
        }

        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            var message = messages[index]
            message.acknowledged = true
            messages[index] = message
            messagesByThread[threadId] = messages
            messagesSubject.send(messagesByThread)
        }

        lock.unlock()

        saveToStorage()
    }

    /// Delete a thread and all its messages
    public func deleteThread(threadId: String) {
        lock.lock()

        messagesByThread.removeValue(forKey: threadId)
        threadMap.removeValue(forKey: threadId)

        messagesSubject.send(messagesByThread)
        threadsSubject.send(threadMap)

        lock.unlock()

        saveToStorage()

        logger.info("Deleted thread \(threadId)")
    }

    /// Clear all chat data
    public func clearAll() {
        lock.lock()

        messagesByThread.removeAll()
        threadMap.removeAll()

        messagesSubject.send(messagesByThread)
        threadsSubject.send(threadMap)

        lock.unlock()

        saveToStorage()

        logger.info("Cleared all chat data")
    }

    /// Update thread participant info
    public func updateThreadParticipant(
        threadId: String,
        callsign: String?,
        nickname: String?
    ) {
        lock.lock()

        guard var thread = threadMap[threadId] else {
            lock.unlock()
            return
        }

        thread = ChatThread(
            id: thread.id,
            participantDeviceId: thread.participantDeviceId,
            participantCallsign: callsign ?? thread.participantCallsign,
            participantNickname: nickname ?? thread.participantNickname,
            lastMessageText: thread.lastMessageText,
            lastMessageTimestamp: thread.lastMessageTimestamp,
            unreadCount: thread.unreadCount
        )

        threadMap[threadId] = thread
        threadsSubject.send(threadMap)

        lock.unlock()

        saveToStorage()
    }

    // MARK: - Private Methods

    private func addMessageInternal(_ message: ChatMessage, incrementUnreadForIncoming: Bool) {
        // Add message to thread
        var messages = messagesByThread[message.threadId] ?? []
        messages.append(message)
        messagesByThread[message.threadId] = messages
        messagesSubject.send(messagesByThread)

        // Update thread summary
        let lastPreview = String(message.text.prefix(64))
        let now = message.timestampMillis

        let existingThread = threadMap[message.threadId]

        let newUnreadCount: Int
        if incrementUnreadForIncoming {
            newUnreadCount = (existingThread?.unreadCount ?? 0) + 1
        } else {
            newUnreadCount = existingThread?.unreadCount ?? 0
        }

        // Determine participant info
        let participantDeviceId = message.direction == .outgoing
            ? message.toDeviceId
            : message.fromDeviceId

        let thread = ChatThread(
            id: message.threadId,
            participantDeviceId: participantDeviceId,
            participantCallsign: existingThread?.participantCallsign,
            participantNickname: existingThread?.participantNickname,
            lastMessageText: lastPreview,
            lastMessageTimestamp: now,
            unreadCount: newUnreadCount
        )

        threadMap[message.threadId] = thread
        threadsSubject.send(threadMap)
    }

    // MARK: - Persistence

    private let messagesStorageKey = "swetak.chat.messages"
    private let threadsStorageKey = "swetak.chat.threads"

    private func loadFromStorage() {
        // Load threads
        if let data = UserDefaults.standard.data(forKey: threadsStorageKey),
           let decoded = try? JSONDecoder().decode([ChatThread].self, from: data) {
            for thread in decoded {
                threadMap[thread.id] = thread
            }
            threadsSubject.send(threadMap)
        }

        // Load messages
        if let data = UserDefaults.standard.data(forKey: messagesStorageKey),
           let decoded = try? JSONDecoder().decode([String: [ChatMessage]].self, from: data) {
            messagesByThread = decoded
            messagesSubject.send(messagesByThread)
        }

        logger.info("Loaded \(self.threadMap.count) threads from storage")
    }

    private func saveToStorage() {
        lock.lock()
        let threads = Array(threadMap.values)
        let messages = messagesByThread
        lock.unlock()

        // Save threads
        if let data = try? JSONEncoder().encode(threads) {
            UserDefaults.standard.set(data, forKey: threadsStorageKey)
        }

        // Save messages
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: messagesStorageKey)
        }
    }
}

// MARK: - ChatListener Conformance

extension InMemoryChatRepository: ChatListener {

    public func onChatMessageReceived(message: ChatMessage) {
        Task {
            await onIncomingMessage(message: message)
        }
    }

    public func onChatAckReceived(ack: ChatAck) {
        markMessageAcknowledged(messageId: ack.messageId, threadId: ack.toDeviceId)
    }
}
