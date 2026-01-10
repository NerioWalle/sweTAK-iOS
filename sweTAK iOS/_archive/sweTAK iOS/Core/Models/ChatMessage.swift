import Foundation

// MARK: - Chat Direction

public enum ChatDirection: String, Codable {
    case outgoing = "OUTGOING"
    case incoming = "INCOMING"
}

// MARK: - Chat Message

public struct ChatMessage: Codable, Identifiable, Equatable {
    public let id: String
    public let threadId: String
    public let fromDeviceId: String
    public let toDeviceId: String
    public let text: String
    public let timestampMillis: Int64
    public let direction: ChatDirection
    public var acknowledged: Bool

    public init(
        id: String = UUID().uuidString,
        threadId: String,
        fromDeviceId: String,
        toDeviceId: String,
        text: String,
        timestampMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        direction: ChatDirection,
        acknowledged: Bool = false
    ) {
        self.id = id
        self.threadId = threadId
        self.fromDeviceId = fromDeviceId
        self.toDeviceId = toDeviceId
        self.text = text
        self.timestampMillis = timestampMillis
        self.direction = direction
        self.acknowledged = acknowledged
    }
}

// MARK: - Chat Thread

public struct ChatThread: Codable, Identifiable, Equatable {
    public let id: String
    public let participantDeviceId: String
    public var participantCallsign: String?
    public var participantNickname: String?
    public var lastMessageText: String?
    public var lastMessageTimestamp: Int64?
    public var unreadCount: Int

    public init(
        id: String,
        participantDeviceId: String,
        participantCallsign: String? = nil,
        participantNickname: String? = nil,
        lastMessageText: String? = nil,
        lastMessageTimestamp: Int64? = nil,
        unreadCount: Int = 0
    ) {
        self.id = id
        self.participantDeviceId = participantDeviceId
        self.participantCallsign = participantCallsign
        self.participantNickname = participantNickname
        self.lastMessageText = lastMessageText
        self.lastMessageTimestamp = lastMessageTimestamp
        self.unreadCount = unreadCount
    }
}

// MARK: - Chat ACK

public struct ChatAck: Codable, Equatable {
    public let messageId: String
    public let fromDeviceId: String
    public let toDeviceId: String
    public let timestampMillis: Int64

    public init(
        messageId: String,
        fromDeviceId: String,
        toDeviceId: String,
        timestampMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.messageId = messageId
        self.fromDeviceId = fromDeviceId
        self.toDeviceId = toDeviceId
        self.timestampMillis = timestampMillis
    }
}

// MARK: - Incoming Chat Notification

/// Simple in-app notification for incoming direct chat
public struct IncomingChatNotification: Equatable {
    public let threadId: String
    public let fromDeviceId: String?
    public let textPreview: String
    public let callsign: String
    public let nickname: String?

    public init(
        threadId: String,
        fromDeviceId: String?,
        textPreview: String,
        callsign: String,
        nickname: String?
    ) {
        self.threadId = threadId
        self.fromDeviceId = fromDeviceId
        self.textPreview = textPreview
        self.callsign = callsign
        self.nickname = nickname
    }

    /// Display name for the notification
    public var displayName: String {
        if let nickname = nickname, !nickname.isEmpty {
            return "\(callsign) (\(nickname))"
        }
        return callsign
    }
}
