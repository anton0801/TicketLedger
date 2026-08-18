//
//  APIClient.swift
//  TicketLedger
//
//  The only place that talks to the network. It holds the token pair, renews an
//  expired access token exactly once per burst of traffic, and hands back typed
//  errors so screens never have to read a status code.
//

import Foundation

struct TokenPair: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresIn: Int
    var refreshExpiresIn: Int
    /// When the access token stops being usable, worked out on arrival.
    var expiresAt: Date = .distantPast

    enum CodingKeys: String, CodingKey {
        case accessToken, refreshToken, expiresIn, refreshExpiresIn
    }

    /// Used when a pair is restored from the keychain, where only the two
    /// tokens were kept: the expiry is rediscovered by the first refresh.
    init(accessToken: String, refreshToken: String, expiresIn: Int = 3600, refreshExpiresIn: Int = 2592000) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.refreshExpiresIn = refreshExpiresIn
        self.expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        expiresIn = try container.decodeIfPresent(Int.self, forKey: .expiresIn) ?? 3600
        refreshExpiresIn = try container.decodeIfPresent(Int.self, forKey: .refreshExpiresIn) ?? 2592000
        expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
    }
}

actor APIClient {
    static let shared = APIClient()

    private let keychainAccess = "accessToken"
    private let keychainRefresh = "refreshToken"

    private var tokens: TokenPair?
    private var refreshInFlight: Task<TokenPair, Error>?
    /// Called when the server says the session is gone for good.
    private var onSessionLost: (@Sendable () async -> Void)?

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = APIConfiguration.requestTimeout
        configuration.waitsForConnectivity = false
        // Nothing about a request or its answer may be written to a shared cache.
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration)
    }()

    // MARK: Session lifetime

    func setSessionLostHandler(_ handler: @escaping @Sendable () async -> Void) {
        onSessionLost = handler
    }

    func restoreTokens() -> Bool {
        guard let access = KeychainStore.string(keychainAccess),
              let refresh = KeychainStore.string(keychainRefresh) else {
            return false
        }
        // The stored access token may already be stale; the first 401 renews it.
        tokens = TokenPair(accessToken: access, refreshToken: refresh)
        return true
    }

    func store(_ pair: TokenPair) {
        tokens = pair
        KeychainStore.save(pair.accessToken, for: keychainAccess)
        KeychainStore.save(pair.refreshToken, for: keychainRefresh)
    }

    func clearTokens() {
        tokens = nil
        refreshInFlight?.cancel()
        refreshInFlight = nil
        KeychainStore.delete(keychainAccess)
        KeychainStore.delete(keychainRefresh)
    }

    var hasSession: Bool { tokens != nil }

    // MARK: Endpoints

    func register(email: String, password: String, displayName: String) async throws -> AuthResponse {
        let response: AuthResponse = try await send(
            "POST", "/v1/auth/register",
            body: [
                "email": email,
                "password": password,
                "displayName": displayName,
                "deviceName": APIConfiguration.deviceName,
            ],
            authenticated: false
        )
        store(response.tokens)
        return response
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let response: AuthResponse = try await send(
            "POST", "/v1/auth/login",
            body: [
                "email": email,
                "password": password,
                "deviceName": APIConfiguration.deviceName,
            ],
            authenticated: false
        )
        store(response.tokens)
        return response
    }

    func logout() async {
        // A failure here does not matter: the local tokens go either way, and
        // the server drops them when they expire.
        _ = try? await sendVoid("POST", "/v1/auth/logout")
        clearTokens()
    }

    func logoutEverywhere() async throws {
        try await sendVoid("POST", "/v1/auth/logout-all")
        clearTokens()
    }

    func profile() async throws -> APIUser {
        let response: UserResponse = try await send("GET", "/v1/me")
        return response.user
    }

    func updateProfile(displayName: String?, email: String?, currentPassword: String?) async throws -> APIUser {
        var body: [String: Any] = [:]
        if let displayName { body["displayName"] = displayName }
        if let email { body["email"] = email }
        if let currentPassword { body["currentPassword"] = currentPassword }
        let response: UserResponse = try await send("PATCH", "/v1/me", body: body)
        return response.user
    }

    func changePassword(current: String, next: String) async throws {
        try await sendVoid("POST", "/v1/me/password", body: [
            "currentPassword": current,
            "newPassword": next,
        ])
    }

    func sessions() async throws -> [APISession] {
        let response: SessionsResponse = try await send("GET", "/v1/me/sessions")
        return response.sessions
    }

    func revokeSession(id: String) async throws {
        try await sendVoid("DELETE", "/v1/me/sessions/\(id)")
    }

    func deleteAccount(password: String) async throws {
        try await sendVoid("DELETE", "/v1/me", body: ["password": password, "confirm": "DELETE"])
        clearTokens()
    }

    func pull(cursor: Int) async throws -> SyncPullResponse {
        try await send("GET", "/v1/sync?cursor=\(cursor)")
    }

    func push(_ payload: SyncPushRequest) async throws -> SyncPushResponse {
        try await send("POST", "/v1/sync", encodable: payload)
    }

    func health() async throws -> Bool {
        let _: HealthResponse = try await send("GET", "/v1/health", authenticated: false)
        return true
    }

    // MARK: Transport

    private func send<T: Decodable>(
        _ method: String,
        _ path: String,
        body: [String: Any]? = nil,
        encodable: (any Encodable)? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        let data = try await perform(method, path, body: body, encodable: encodable, authenticated: authenticated)
        if data.isEmpty, let empty = EmptyResponse() as? T {
            return empty
        }
        do {
            return try APICoding.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func sendVoid(
        _ method: String,
        _ path: String,
        body: [String: Any]? = nil
    ) async throws {
        _ = try await perform(method, path, body: body, encodable: nil, authenticated: true)
    }

    private func perform(
        _ method: String,
        _ path: String,
        body: [String: Any]?,
        encodable: (any Encodable)?,
        authenticated: Bool,
        isRetry: Bool = false
    ) async throws -> Data {
        guard let url = URL(string: path, relativeTo: APIConfiguration.baseURL) else {
            throw APIError.server("The server address is not usable.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let encodable {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try APICoding.encoder.encode(encodable)
        } else if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        if authenticated {
            guard let token = tokens?.accessToken else {
                throw APIError.unauthorized("Sign in to continue.")
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
                 .cannotFindHost, .dataNotAllowed, .internationalRoamingOff:
                throw APIError.offline
            case .timedOut:
                throw APIError.timedOut
            default:
                throw APIError.offline
            }
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.decoding
        }

        if (200...299).contains(http.statusCode) {
            return data
        }

        // One renewal attempt, then the session is genuinely over.
        if http.statusCode == 401, authenticated, !isRetry, tokens?.refreshToken != nil {
            do {
                _ = try await renew()
                return try await perform(method, path, body: body, encodable: encodable, authenticated: authenticated, isRetry: true)
            } catch {
                clearTokens()
                await onSessionLost?()
                throw APIError.unauthorized("Your session ended. Sign in again.")
            }
        }

        throw Self.error(from: http, data: data, onUnauthorized: { [weak self] in
            guard let self else { return }
            await self.handleSessionLoss()
        })
    }

    private func handleSessionLoss() async {
        clearTokens()
        await onSessionLost?()
    }

    /// Renewal is shared: if several requests hit a 401 together, they all wait
    /// on one rotation instead of racing and burning each other's refresh token.
    private func renew() async throws -> TokenPair {
        if let existing = refreshInFlight {
            return try await existing.value
        }
        guard let refreshToken = tokens?.refreshToken else {
            throw APIError.unauthorized("Sign in to continue.")
        }

        let task = Task<TokenPair, Error> {
            let response: TokensResponse = try await self.send(
                "POST", "/v1/auth/refresh",
                body: ["refreshToken": refreshToken],
                authenticated: false
            )
            return response.tokens
        }
        refreshInFlight = task

        defer { refreshInFlight = nil }
        let pair = try await task.value
        store(pair)
        return pair
    }

    private static func error(
        from response: HTTPURLResponse,
        data: Data,
        onUnauthorized: @escaping @Sendable () async -> Void
    ) -> APIError {
        let envelope = try? APICoding.decoder.decode(APIErrorEnvelope.self, from: data)
        let message = envelope?.error.message ?? "Something went wrong."

        switch response.statusCode {
        case 401:
            Task { await onUnauthorized() }
            return .unauthorized(message)
        case 403:
            return .forbidden(message)
        case 404:
            return .notFound
        case 409:
            return .conflict(message)
        case 422:
            return .validation(fields: envelope?.error.details?.compactMapValues { $0 } ?? [:], message: message)
        case 429:
            let header = response.value(forHTTPHeaderField: "Retry-After")
            return .rateLimited(retryAfter: Int(header ?? "") ?? 60, message: message)
        case 500...599:
            return .server("The server had a problem. Try again shortly.")
        default:
            return .server(message)
        }
    }
}

// MARK: - Coding

enum APICoding {
    /// The API speaks ISO-8601 in UTC, with or without fractional seconds.
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            if let date = fractional.date(from: raw) ?? plain.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unreadable date \(raw)")
            )
        }
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(fractional.string(from: date))
        }
        return encoder
    }()

    static func iso(_ date: Date) -> String { fractional.string(from: date) }

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
