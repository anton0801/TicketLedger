//
//  AuthSession.swift
//  TicketLedger
//
//  Who is signed in, and everything that changes that.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class AuthSession {
    enum State: Equatable {
        /// Still deciding whether a stored session is usable.
        case restoring
        case signedOut
        case signedIn(APIUser)

        var user: APIUser? {
            if case .signedIn(let user) = self { return user }
            return nil
        }

        var isSignedIn: Bool { user != nil }
    }

    private(set) var state: State = .restoring
    /// Set when the server could not be reached while a stored session existed.
    /// The app carries on offline rather than throwing the person out.
    private(set) var workingOffline = false
    private(set) var busy = false

    private let client = APIClient.shared
    private let userDefaultsKey = "auth.cachedUser"

    // MARK: Startup

    func restore() async {
        await client.setSessionLostHandler { [weak self] in
            await self?.handleSessionLost()
        }

        guard await client.restoreTokens() else {
            state = .signedOut
            return
        }

        // A cached profile lets the app open straight into the ledger while the
        // server is checked in the background.
        if let cached = cachedUser() {
            state = .signedIn(cached)
        }

        do {
            let user = try await client.profile()
            cache(user)
            state = .signedIn(user)
            workingOffline = false
        } catch let error as APIError where error.isAuthFailure {
            await signOutLocally()
        } catch {
            // Offline, or the server is down. A stored session stays usable.
            if let cached = cachedUser() {
                state = .signedIn(cached)
                workingOffline = true
            } else {
                state = .signedOut
            }
        }
    }

    // MARK: Entry

    func register(email: String, password: String, displayName: String) async throws {
        busy = true
        defer { busy = false }
        let response = try await client.register(email: email, password: password, displayName: displayName)
        cache(response.user)
        state = .signedIn(response.user)
        workingOffline = false
    }

    func signIn(email: String, password: String) async throws {
        busy = true
        defer { busy = false }
        let response = try await client.login(email: email, password: password)
        cache(response.user)
        state = .signedIn(response.user)
        workingOffline = false
    }

    // MARK: Exit

    func signOut() async {
        busy = true
        defer { busy = false }
        await client.logout()
        await signOutLocally()
    }

    func signOutEverywhere() async throws {
        busy = true
        defer { busy = false }
        try await client.logoutEverywhere()
        await signOutLocally()
    }

    /// Clears the session on this device without calling the server.
    func signOutLocally() async {
        await client.clearTokens()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        state = .signedOut
        workingOffline = false
    }

    private func handleSessionLost() async {
        await signOutLocally()
    }

    // MARK: Account

    func refreshProfile() async throws {
        let user = try await client.profile()
        cache(user)
        state = .signedIn(user)
        workingOffline = false
    }

    func updateProfile(displayName: String?, email: String?, currentPassword: String?) async throws {
        busy = true
        defer { busy = false }
        let user = try await client.updateProfile(
            displayName: displayName,
            email: email,
            currentPassword: currentPassword
        )
        cache(user)
        state = .signedIn(user)
    }

    func changePassword(current: String, next: String) async throws {
        busy = true
        defer { busy = false }
        try await client.changePassword(current: current, next: next)
    }

    func sessions() async throws -> [APISession] {
        try await client.sessions()
    }

    func revokeSession(id: String) async throws {
        try await client.revokeSession(id: id)
    }

    /// Removes the account and everything on the server. The caller wipes the
    /// local ledger afterwards, because a deleted account must leave nothing on
    /// the device either.
    func deleteAccount(password: String) async throws {
        busy = true
        defer { busy = false }
        try await client.deleteAccount(password: password)
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        state = .signedOut
        workingOffline = false
    }

    // MARK: Cached profile

    private func cache(_ user: APIUser) {
        guard let data = try? APICoding.encoder.encode(user) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    private func cachedUser() -> APIUser? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return nil }
        return try? APICoding.decoder.decode(APIUser.self, from: data)
    }
}
