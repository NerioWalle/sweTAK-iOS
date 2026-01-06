import Foundation
import Combine
import os.log

/// UI state for a chat thread
public struct ChatUIState {
    public var messages: [ChatMessage] = []
    public var inputText: String = ""
    public var isSendEnabled: Bool = false

    public init(messages: [ChatMessage] = [], inputText: String = "", isSendEnabled: Bool = false) {
        self.messages = messages
        self.inputText = inputText
        self.isSendEnabled = isSendEnabled
    }
}

/// ViewModel for managing chat functionality
/// Mirrors Android ChatViewModel functionality
public final class ChatViewModel: ObservableObject {

    // MARK: - Singleton

    public static let shared = ChatViewModel()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.swetak", category: "ChatViewModel")

    // MARK: - Published State

    @Published public private(set) var uiState = ChatUIState()
    @Published public private(set) var threads: [String: [ChatMessage]] = [:]
    @Published public private(set) var unreadCounts: [String: Int] = [:]

    // MARK: - Current Thread

    private var currentThreadId: String?
    private var currentPeerCallsign: String?
    private var currentPeerNickname: String?

    // MARK: - Storage Keys

    private enum Keys {
        static let threads = "swetak_chat_threads"
        static let unreadCounts = "swetak_chat_unread"
    }

    // MARK: - Initialization

    private init() {
        loadFromStorage()
        setupListeners()
    }

    // MARK: - Listeners

    private func setupListeners() {
        TransportCoordinator.shared.chatListener = self
    }

    // MARK: - Storage

    private func loadFromStorage() {
        // Load threads
        if let data = UserDefaults.standard.data(forKey: Keys.threads),
           let storedThreads = try? JSONDecoder().decode([String: [ChatMessage]].self, from: data) {
            threads = storedThreads
            logger.info("Loaded \(storedThreads.count) chat threads from storage")
        }

        // Load unread counts
        if let data = UserDefaults.standard.data(forKey: Keys.unreadCounts),
           let storedCounts = try? JSONDecoder().decode([String: Int].self, from: data) {
            unreadCounts = storedCounts
        }
    }

    private func saveThreads() {
        if let data = try? JSONEncoder().encode(threads) {
            UserDefaults.standard.set(data, forKey: Keys.threads)
        }
    }

    private func saveUnreadCounts() {
        if let data = try? JSONEncoder().encode(unreadCounts) {
            UserDefaults.standard.set(data, forKey: Keys.unreadCounts)
        }
    }

    // MARK: - Thread Management

    /// Set the current active thread
    public func setThread(threadId: String, peerCallsign: String, peerNickname: String? = nil) {
        currentThreadId = threadId
        currentPeerCallsign = peerCallsign
        currentPeerNickname = peerNickname

        // Load messages for this thread
        let messages = threads[threadId] ?? []
        uiState = ChatUIState(messages: messages, inputText: "", isSendEnabled: false)

        // Clear unread count for this thread
        unreadCounts[threadId] = 0
        saveUnreadCounts()

        logger.debug("Set thread: \(threadId) with \(peerCallsign)")
    }

    /// Close the current thread
    public func closeThread() {
        currentThreadId = nil
        currentPeerCallsign = nil
        currentPeerNickname = nil
        uiState = ChatUIState()
    }

    /// Get all thread IDs sorted by latest message (most recent first)
    public var allThreadIds: [String] {
        Array(threads.keys).sorted { threadA, threadB in
            let lastTimestampA = threads[threadA]?.last?.timestampMillis ?? 0
            let lastTimestampB = threads[threadB]?.last?.timestampMillis ?? 0
            return lastTimestampA > lastTimestampB
        }
    }

    /// Get messages for a thread
    public func getMessages(forThread threadId: String) -> [ChatMessage] {
        threads[threadId] ?? []
    }

    /// Get total unread count
    public var totalUnreadCount: Int {
        unreadCounts.values.reduce(0, +)
    }

    // MARK: - Input Handling

    /// Update input text
    public func onInputTextChanged(_ newText: String) {
        uiState.inputText = newText
        uiState.isSendEnabled = !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Send the current message
    public func onSendClicked() {
        guard let threadId = currentThreadId else { return }
        let text = uiState.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let myDeviceId = TransportCoordinator.shared.deviceId
        let toDeviceId = threadId // One-to-one chat keyed by peer deviceId
        let timestamp = Date.currentMillis

        // Create outgoing message
        let message = ChatMessage(
            id: "\(timestamp)-\(text.hashValue)",
            threadId: threadId,
            fromDeviceId: myDeviceId,
            toDeviceId: toDeviceId,
            text: text,
            timestampMillis: timestamp,
            direction: .outgoing,
            acknowledged: false
        )

        // Update UI
        uiState.messages.append(message)
        uiState.inputText = ""
        uiState.isSendEnabled = false

        // Update threads storage
        var threadMessages = threads[threadId] ?? []
        threadMessages.append(message)
        threads[threadId] = threadMessages
        saveThreads()

        // Send over network
        TransportCoordinator.shared.sendChat(message)

        logger.debug("Sent message to \(toDeviceId): \(text.prefix(50))")
    }

    /// Convenience method to send a message
    public func sendMessage(_ text: String) {
        onInputTextChanged(text)
        onSendClicked()
    }

    // MARK: - Incoming Messages

    /// Add an incoming message
    public func addIncomingMessage(_ message: ChatMessage) {
        // For incoming messages, we key threads by the sender's deviceId
        // This ensures conversations are grouped correctly regardless of what threadId the sender uses
        let effectiveThreadId = message.fromDeviceId

        logger.info("addIncomingMessage: from=\(message.fromDeviceId), originalThreadId=\(message.threadId), effectiveThreadId=\(effectiveThreadId), currentThreadId=\(self.currentThreadId ?? "nil")")

        // Update threads storage using the sender's deviceId as the thread key
        var threadMessages = threads[effectiveThreadId] ?? []

        // Avoid duplicates
        if !threadMessages.contains(where: { $0.id == message.id }) {
            // Create message with corrected threadId
            let correctedMessage = ChatMessage(
                id: message.id,
                threadId: effectiveThreadId,
                fromDeviceId: message.fromDeviceId,
                toDeviceId: message.toDeviceId,
                text: message.text,
                timestampMillis: message.timestampMillis,
                direction: message.direction,
                acknowledged: message.acknowledged
            )

            threadMessages.append(correctedMessage)
            threads[effectiveThreadId] = threadMessages
            saveThreads()

            // Check if this message is for the currently open chat
            // Match by sender's deviceId since that's how we key threads
            let isCurrentThread = effectiveThreadId == currentThreadId

            logger.info("addIncomingMessage: isCurrentThread=\(isCurrentThread)")

            if isCurrentThread {
                if !uiState.messages.contains(where: { $0.id == correctedMessage.id }) {
                    uiState.messages.append(correctedMessage)
                    logger.info("addIncomingMessage: Added to UI - now have \(self.uiState.messages.count) messages")
                }
            } else {
                // Increment unread count
                unreadCounts[effectiveThreadId] = (unreadCounts[effectiveThreadId] ?? 0) + 1
                saveUnreadCounts()
                logger.info("addIncomingMessage: Not current thread, incremented unread count")
            }

            logger.debug("Added incoming message from \(message.fromDeviceId)")
        } else {
            logger.debug("Duplicate message ignored: \(message.id)")
        }
    }

    // MARK: - ACK Handling

    /// Apply an acknowledgment to outgoing messages
    public func applyAck(threadId: String, fromDeviceId: String?, timestampMillis: Int64) {
        // Update thread messages
        if var threadMessages = threads[threadId] {
            threadMessages = threadMessages.map { msg in
                if msg.direction == .outgoing && msg.timestampMillis <= timestampMillis && !msg.acknowledged {
                    return ChatMessage(
                        id: msg.id,
                        threadId: msg.threadId,
                        fromDeviceId: msg.fromDeviceId,
                        toDeviceId: msg.toDeviceId,
                        text: msg.text,
                        timestampMillis: msg.timestampMillis,
                        direction: msg.direction,
                        acknowledged: true
                    )
                }
                return msg
            }
            threads[threadId] = threadMessages
            saveThreads()

            // Update UI if current thread
            if threadId == currentThreadId {
                uiState.messages = threadMessages
            }
        }
    }

    // MARK: - Thread Operations

    /// Delete a thread
    public func deleteThread(_ threadId: String) {
        threads.removeValue(forKey: threadId)
        unreadCounts.removeValue(forKey: threadId)
        saveThreads()
        saveUnreadCounts()

        if currentThreadId == threadId {
            closeThread()
        }
    }

    /// Clear all threads
    public func clearAllThreads() {
        threads.removeAll()
        unreadCounts.removeAll()
        saveThreads()
        saveUnreadCounts()
        closeThread()
    }
}

// MARK: - ChatListener

extension ChatViewModel: ChatListener {
    public func onChatMessageReceived(message: ChatMessage) {
        DispatchQueue.main.async { [weak self] in
            self?.addIncomingMessage(message)
        }
    }

    public func onChatAckReceived(ack: ChatAck) {
        DispatchQueue.main.async { [weak self] in
            // The ack.messageId is actually the threadId in our implementation
            self?.applyAck(
                threadId: ack.messageId,
                fromDeviceId: ack.fromDeviceId,
                timestampMillis: ack.timestampMillis
            )
        }
    }
}
