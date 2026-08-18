//
//  SyncEngine.swift
//  TicketLedger
//
//  The ledger on the device stays the source of truth for everything the screens
//  read. This engine keeps it level with the server:
//
//    push  everything changed since the last successful push, deletions included
//    pull  everything the server has above the revision this device holds
//
//  Records are matched by the id the app already generated, so the same record
//  is never created twice. Where both sides changed a record, the later
//  `updatedAt` wins — stated plainly rather than hidden, because a fine edited
//  on two phones has to resolve somehow.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class SyncEngine {
    enum Status: Equatable {
        case idle
        case syncing
        case offline
        case failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var lastSyncedAt: Date?
    /// Records the server refused, kept so the person can be told rather than
    /// left wondering why one fine never appears on the other device.
    private(set) var rejected: [String] = []

    private let client = APIClient.shared
    private var store: Store?
    private var runningTask: Task<Void, Never>?

    func attach(to store: Store) {
        self.store = store
        lastSyncedAt = store.data.lastSyncedAt
    }

    var hasPendingChanges: Bool {
        guard let store else { return false }
        return !changedRecords(in: store).isEmpty || !store.data.tombstones.isEmpty
    }

    /// Exposed so a screen can say what is waiting without guessing.
    var pendingCount: Int {
        guard let store else { return 0 }
        return changedRecords(in: store).values.reduce(0) { $0 + $1.count } + store.data.tombstones.count
    }

    // MARK: Entry points

    /// Runs a push then a pull. Safe to call often: a second call while one is
    /// running is ignored rather than queued.
    func syncNow() {
        guard runningTask == nil else { return }
        runningTask = Task { [weak self] in
            await self?.run()
            self?.runningTask = nil
        }
    }

    func syncAndWait() async {
        if let runningTask {
            await runningTask.value
            return
        }
        await run()
    }

    /// Called when an account signs in. A ledger belonging to someone else is
    /// cleared first: two people on one device must never see each other's data.
    func prepareForAccount(_ accountID: String, on store: Store) {
        if let existing = store.data.accountID, existing != accountID {
            store.resetForNewAccount()
        }
        store.data.accountID = accountID
        store.saveNow()
    }

    private func run() async {
        guard let store else { return }
        guard await client.hasSession else { return }

        status = .syncing
        rejected = []

        do {
            // Pull first: a device that has just signed in has to learn what the
            // account already holds before it offers anything of its own.
            try await pull(store)
            try await push(store)
            store.data.lastSyncedAt = Date()
            lastSyncedAt = store.data.lastSyncedAt
            store.saveNow()
            status = .idle
        } catch let error as APIError {
            switch error {
            case .offline, .timedOut:
                status = .offline
            case .unauthorized:
                // AuthSession is told by the client; nothing to do here.
                status = .failed("Session ended.")
            default:
                status = .failed(error.localizedDescription)
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: Push

    private func push(_ store: Store) async throws {
        var changes: [String: [JSONValue]] = [:]

        for (collection, records) in changedRecords(in: store) {
            changes[collection.rawValue] = records
        }

        // Deletions travel as an id plus the moment they happened.
        for tombstone in store.data.tombstones {
            var payload: [String: JSONValue] = [
                "id": .string(tombstone.id.uuidString),
                "deletedAt": .date(tombstone.deletedAt),
            ]
            payload["updatedAt"] = .date(tombstone.deletedAt)
            changes[tombstone.collection.rawValue, default: []].append(.object(payload))
        }

        let settingsChanged = !store.data.settings.matches(lastPushedSettings(store))
        guard !changes.isEmpty || settingsChanged else { return }
        if settingsChanged { store.lastSyncedSettings = store.data.settings }

        let request = SyncPushRequest(
            changes: changes,
            settings: settingsChanged ? SyncMapper.settings(from: store.data.settings) : nil
        )
        let response = try await client.push(request)

        // The cursor is only ever moved by a pull. A push answers with the
        // server's newest revision, and adopting it here would make the device
        // skip every change it has not actually seen.
        store.data.lastPushedAt = Date()
        store.markSynced(response.applied)
        // Only the deletions the server confirmed are dropped.
        let confirmed = Set(response.applied.compactMap { $0.deleted == true ? $0.id.uppercased() : nil })
        store.data.tombstones.removeAll { confirmed.contains($0.id.uuidString.uppercased()) }

        rejected = response.failed.map { failure in
            "\(failure.collection): \(failure.error)"
        }
    }

    /// Everything the server has not confirmed in its current shape.
    private func changedRecords(in store: Store) -> [SyncCollection: [JSONValue]] {
        var result: [SyncCollection: [JSONValue]] = [:]

        func changed<T>(_ items: [T], _ stamps: (T) -> (Date?, Date?)) -> [T] {
            items.filter { item in
                let (updated, synced) = stamps(item)
                guard let updated else { return true }
                guard let synced else { return true }
                return updated != synced
            }
        }

        let vehicles = changed(store.data.vehicles) { ($0.updatedAt, $0.syncedAt) }.map(SyncMapper.encode)
        if !vehicles.isEmpty { result[.vehicles] = vehicles }

        let drivers = changed(store.data.drivers) { ($0.updatedAt, $0.syncedAt) }.map(SyncMapper.encode)
        if !drivers.isEmpty { result[.drivers] = drivers }

        let fines = changed(store.data.fines) { ($0.updatedAt, $0.syncedAt) }.map(SyncMapper.encode)
        if !fines.isEmpty { result[.fines] = fines }

        let documents = changed(store.data.documents) { ($0.updatedAt, $0.syncedAt) }.map(SyncMapper.encode)
        if !documents.isEmpty { result[.documents] = documents }

        let payments = changed(store.data.payments) { ($0.updatedAt, $0.syncedAt) }.map(SyncMapper.encode)
        if !payments.isEmpty { result[.payments] = payments }

        let renewals = changed(store.data.renewals) { ($0.updatedAt, $0.syncedAt) }.map(SyncMapper.encode)
        if !renewals.isEmpty { result[.renewals] = renewals }

        return result
    }

    /// After the pull, `lastSyncedSettings` holds what the server has. Only a
    /// genuine local difference is worth sending back.
    private func lastPushedSettings(_ store: Store) -> AppSettings? {
        store.lastSyncedSettings
    }

    // MARK: Pull

    private func pull(_ store: Store) async throws {
        var cursor = store.data.syncCursor
        var guardCount = 0
        // A device that has never pulled starts from nothing and takes the lot.

        repeat {
            let response = try await client.pull(cursor: cursor)
            apply(response, to: store)
            cursor = response.cursor
            store.data.syncCursor = cursor
            guardCount += 1
            if !response.hasMore { break }
        } while guardCount < 20
    }

    private func apply(_ response: SyncPullResponse, to store: Store) {
        for (name, records) in response.collections {
            guard let collection = SyncCollection(rawValue: name) else { continue }
            for record in records {
                if record.deletedAt != nil {
                    store.applyRemoteDeletion(collection: collection, id: record.id)
                    continue
                }
                SyncMapper.merge(record, collection: collection, into: store)
            }
        }

        if let remote = response.settings {
            SyncMapper.applySettings(remote, to: store)
        }
    }
}
