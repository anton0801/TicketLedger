//
//  APIModels.swift
//  TicketLedger
//
//  What crosses the wire. Kept apart from the app's own models so a change on
//  the server cannot quietly reshape the local ledger.
//

import Foundation

// MARK: - Envelopes

struct EmptyResponse: Decodable {}

struct APIErrorEnvelope: Decodable {
    struct Body: Decodable {
        var code: String
        var message: String
        var details: [String: String?]?
    }
    var error: Body
}

struct HealthResponse: Decodable {
    var status: String
}

struct AuthResponse: Decodable {
    var user: APIUser
    var tokens: TokenPair
}

struct TokensResponse: Decodable {
    var tokens: TokenPair
}

struct UserResponse: Decodable {
    var user: APIUser
}

struct SessionsResponse: Decodable {
    var sessions: [APISession]
}

// MARK: - Account

struct APIUser: Codable, Equatable, Identifiable {
    var id: String
    var email: String
    var displayName: String
    var createdAt: Date?
    var lastLoginAt: Date?
}

struct APISession: Decodable, Identifiable, Equatable {
    var id: String
    var deviceName: String
    var createdAt: Date?
    var lastUsedAt: Date?
    var expiresAt: Date?
    var current: Bool
}

// MARK: - Sync

/// One record as the server stores it. The body is deliberately untyped: the
/// mapping to and from the app's models lives in SyncEngine, in one place.
struct SyncRecord: Decodable {
    var id: UUID
    var updatedAt: Date?
    var deletedAt: Date?
    var rev: Int
    var raw: [String: JSONValue]

    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        var values: [String: JSONValue] = [:]
        for key in container.allKeys {
            values[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        raw = values

        guard let idString = values["id"]?.stringValue, let parsed = UUID(uuidString: idString) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "record without an id"))
        }
        id = parsed
        rev = values["rev"]?.intValue ?? 0
        updatedAt = values["updatedAt"]?.dateValue
        deletedAt = values["deletedAt"]?.dateValue
    }
}

struct SyncPullResponse: Decodable {
    var cursor: Int
    var hasMore: Bool
    var collections: [String: [SyncRecord]]
    var settings: APISettings?
}

struct SyncPushRequest: Encodable {
    var changes: [String: [JSONValue]]
    var settings: APISettings?
}

struct SyncPushResponse: Decodable {
    struct Applied: Decodable {
        var collection: String
        var id: String
        var deleted: Bool?
    }
    struct Failed: Decodable {
        var collection: String
        var id: String?
        var error: String
    }
    var cursor: Int
    var applied: [Applied]
    var failed: [Failed]
}

struct APISettings: Codable, Equatable {
    var displayName: String?
    var country: String?
    var currencyCode: String?
    var discountWindowDays: Int?
    var appealWindowDays: Int?
    var enforcementAfterDays: Int?
    var notificationsEnabled: Bool?
    var notificationPrefs: NotificationPrefs?
    var onboardingDone: Bool?
    var setupDone: Bool?
    var rev: Int?
    var updatedAt: Date?
}

// MARK: - A small JSON value

/// Enough of a JSON model to carry records both ways without a type per field.
enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case integer(Int)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    // MARK: Readers

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .integer(let value): value
        case .number(let value): Int(value)
        default: nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .number(let value): value
        case .integer(let value): Double(value)
        default: nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let value): value
        case .integer(let value): value != 0
        default: nil
        }
    }

    var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    var uuidValue: UUID? {
        stringValue.flatMap { UUID(uuidString: $0) }
    }

    var dateValue: Date? {
        guard let raw = stringValue else { return nil }
        return JSONValue.fractional.date(from: raw) ?? JSONValue.plain.date(from: raw)
    }

    // MARK: Writers

    static func date(_ value: Date?) -> JSONValue {
        guard let value else { return .null }
        return .string(fractional.string(from: value))
    }

    static func uuid(_ value: UUID?) -> JSONValue {
        guard let value else { return .null }
        return .string(value.uuidString)
    }

    static func text(_ value: String) -> JSONValue { .string(value) }

    static func money(_ value: Double?) -> JSONValue {
        guard let value else { return .null }
        return .number(value)
    }

    /// Re-encodes any Codable value into this tree, used for nested structures
    /// such as evidence and appeal records.
    static func encoding<T: Encodable>(_ value: T?) -> JSONValue {
        guard let value else { return .null }
        guard let data = try? APICoding.encoder.encode(value),
              let decoded = try? APICoding.decoder.decode(JSONValue.self, from: data) else {
            return .null
        }
        return decoded
    }

    /// Decodes a nested structure back into a model type.
    func decoded<T: Decodable>(_ type: T.Type) -> T? {
        guard self != .null,
              let data = try? APICoding.encoder.encode(self) else { return nil }
        return try? APICoding.decoder.decode(type, from: data)
    }

    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
