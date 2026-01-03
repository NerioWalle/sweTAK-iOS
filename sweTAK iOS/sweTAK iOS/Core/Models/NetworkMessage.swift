import Foundation

// MARK: - Message Type

/// Network message types matching Android protocol
public enum MessageType: String, Codable {
    case position = "position"
    case pin = "pin"
    case pinDelete = "pin_delete"
    case pinRequest = "pin_request"
    case profile = "profile"
    case hello = "hello"
    case chat = "chat"
    case chatAck = "chat_ack"
    case order = "order"
    case orderAck = "order_ack"
    case report = "report"
    case reportAck = "report_ack"
    case methane = "methane"
    case methaneAck = "methane_ack"
    case medevac = "medevac"
    case medevacAck = "medevac_ack"
    case linkedForm = "linked_form"
    case photo = "photo"
}

// MARK: - Network Message Envelope

/// Envelope for all network messages with security fields
public struct NetworkMessage: Codable {
    public let type: MessageType
    public let deviceId: String
    public let timestamp: Int64
    public let payload: [String: Any]

    // Security fields (optional)
    public var signature: String?
    public var publicKey: String?
    public var encrypted: Bool
    public var encryptedPayload: String?

    private enum CodingKeys: String, CodingKey {
        case type, deviceId, timestamp, payload, signature, publicKey, encrypted, encryptedPayload
    }

    public init(
        type: MessageType,
        deviceId: String,
        timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        payload: [String: Any],
        signature: String? = nil,
        publicKey: String? = nil,
        encrypted: Bool = false,
        encryptedPayload: String? = nil
    ) {
        self.type = type
        self.deviceId = deviceId
        self.timestamp = timestamp
        self.payload = payload
        self.signature = signature
        self.publicKey = publicKey
        self.encrypted = encrypted
        self.encryptedPayload = encryptedPayload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(MessageType.self, forKey: .type)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        timestamp = try container.decode(Int64.self, forKey: .timestamp)
        signature = try container.decodeIfPresent(String.self, forKey: .signature)
        publicKey = try container.decodeIfPresent(String.self, forKey: .publicKey)
        encrypted = try container.decodeIfPresent(Bool.self, forKey: .encrypted) ?? false
        encryptedPayload = try container.decodeIfPresent(String.self, forKey: .encryptedPayload)

        // Decode payload as generic dictionary
        if let payloadData = try? container.decode([String: AnyCodable].self, forKey: .payload) {
            payload = payloadData.mapValues { $0.value }
        } else {
            payload = [:]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(signature, forKey: .signature)
        try container.encodeIfPresent(publicKey, forKey: .publicKey)
        try container.encode(encrypted, forKey: .encrypted)
        try container.encodeIfPresent(encryptedPayload, forKey: .encryptedPayload)

        // Encode payload as generic dictionary
        let codablePayload = payload.mapValues { AnyCodable($0) }
        try container.encode(codablePayload, forKey: .payload)
    }

    /// Convert to JSON data for network transmission
    public func toJSONData() throws -> Data {
        var json: [String: Any] = [
            "type": type.rawValue,
            "deviceId": deviceId,
            "timestamp": timestamp,
            "payload": payload
        ]
        if let signature = signature { json["signature"] = signature }
        if let publicKey = publicKey { json["publicKey"] = publicKey }
        if encrypted { json["encrypted"] = true }
        if let encryptedPayload = encryptedPayload { json["encryptedPayload"] = encryptedPayload }

        return try JSONSerialization.data(withJSONObject: json, options: [])
    }

    /// Parse from JSON data
    public static func fromJSONData(_ data: Data) throws -> NetworkMessage {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let typeString = json["type"] as? String,
              let type = MessageType(rawValue: typeString),
              let deviceId = json["deviceId"] as? String else {
            throw NetworkMessageError.invalidFormat
        }

        let timestamp = json["timestamp"] as? Int64 ?? Int64(Date().timeIntervalSince1970 * 1000)
        let payload = json["payload"] as? [String: Any] ?? [:]

        return NetworkMessage(
            type: type,
            deviceId: deviceId,
            timestamp: timestamp,
            payload: payload,
            signature: json["signature"] as? String,
            publicKey: json["publicKey"] as? String,
            encrypted: json["encrypted"] as? Bool ?? false,
            encryptedPayload: json["encryptedPayload"] as? String
        )
    }
}

public enum NetworkMessageError: Error {
    case invalidFormat
    case missingRequiredField(String)
    case invalidPayload
}

// MARK: - AnyCodable Helper

/// Helper for encoding/decoding arbitrary values
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let int64 = try? container.decode(Int64.self) {
            value = int64
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let int64 as Int64:
            try container.encode(int64)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
