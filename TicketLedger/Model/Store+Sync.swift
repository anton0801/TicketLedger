//
//  Store+Sync.swift
//  TicketLedger
//
//  What the sync engine is allowed to do to the ledger. Remote writes come
//  through here rather than through the normal upsert methods, because a record
//  arriving from the server must not be stamped as a fresh local change — that
//  would push it straight back and loop forever.
//

import SwiftUI

extension Store {

    // MARK: Lookups by id

    func payment(_ id: UUID) -> PaymentRecord? {
        data.payments.first { $0.id == id }
    }

    func renewal(_ id: UUID) -> RenewalRecord? {
        data.renewals.first { $0.id == id }
    }

    /// Marks the records the server accepted, so they stop counting as pending.
    /// Matching on the exact `updatedAt` matters: a record edited again while the
    /// push was in flight has to stay dirty.
    func markSynced(_ applied: [SyncPushResponse.Applied]) {
        for entry in applied where entry.deleted != true {
            guard let id = UUID(uuidString: entry.id),
                  let collection = SyncCollection(rawValue: entry.collection) else { continue }
            switch collection {
            case .vehicles:
                if let i = data.vehicles.firstIndex(where: { $0.id == id }) {
                    data.vehicles[i].syncedAt = data.vehicles[i].updatedAt
                }
            case .drivers:
                if let i = data.drivers.firstIndex(where: { $0.id == id }) {
                    data.drivers[i].syncedAt = data.drivers[i].updatedAt
                }
            case .fines:
                if let i = data.fines.firstIndex(where: { $0.id == id }) {
                    data.fines[i].syncedAt = data.fines[i].updatedAt
                }
            case .documents:
                if let i = data.documents.firstIndex(where: { $0.id == id }) {
                    data.documents[i].syncedAt = data.documents[i].updatedAt
                }
            case .payments:
                if let i = data.payments.firstIndex(where: { $0.id == id }) {
                    data.payments[i].syncedAt = data.payments[i].updatedAt
                }
            case .renewals:
                if let i = data.renewals.firstIndex(where: { $0.id == id }) {
                    data.renewals[i].syncedAt = data.renewals[i].updatedAt
                }
            }
        }
    }

    // MARK: Tombstones

    /// Remembers a deletion until the server has confirmed it.
    func recordTombstone(_ collection: SyncCollection, _ id: UUID) {
        data.tombstones.removeAll { $0.id == id && $0.collection == collection }
        data.tombstones.append(Tombstone(id: id, collection: collection, deletedAt: Date()))
    }

    // MARK: Remote writes

    func applyRemote(_ vehicle: Vehicle) {
        if let index = data.vehicles.firstIndex(where: { $0.id == vehicle.id }) {
            data.vehicles[index] = vehicle
        } else {
            data.vehicles.append(vehicle)
        }
    }

    func applyRemote(_ driver: Driver) {
        if let index = data.drivers.firstIndex(where: { $0.id == driver.id }) {
            data.drivers[index] = driver
        } else {
            data.drivers.append(driver)
        }
    }

    func applyRemote(_ fine: Fine) {
        if let index = data.fines.firstIndex(where: { $0.id == fine.id }) {
            data.fines[index] = fine
        } else {
            data.fines.append(fine)
        }
    }

    func applyRemote(_ document: DocumentItem) {
        if let index = data.documents.firstIndex(where: { $0.id == document.id }) {
            data.documents[index] = document
        } else {
            data.documents.append(document)
        }
    }

    func applyRemote(_ payment: PaymentRecord) {
        if let index = data.payments.firstIndex(where: { $0.id == payment.id }) {
            data.payments[index] = payment
        } else {
            data.payments.append(payment)
        }
    }

    func applyRemote(_ renewal: RenewalRecord) {
        if let index = data.renewals.firstIndex(where: { $0.id == renewal.id }) {
            data.renewals[index] = renewal
        } else {
            data.renewals.append(renewal)
        }
    }

    func applyRemoteSettings(_ settings: AppSettings) {
        data.settings = settings
        lastSyncedSettings = settings
    }

    /// A deletion that happened on another device.
    func applyRemoteDeletion(collection: SyncCollection, id: UUID) {
        switch collection {
        case .vehicles:
            if let vehicle = data.vehicles.first(where: { $0.id == id }) {
                ImageStore.delete(vehicle.photoName)
            }
            data.vehicles.removeAll { $0.id == id }
        case .drivers:
            data.drivers.removeAll { $0.id == id }
        case .fines:
            if let fine = data.fines.first(where: { $0.id == id }) {
                ImageStore.delete(fine.noticePhotoName)
                for item in fine.evidence { ImageStore.delete(item.fileName) }
            }
            data.fines.removeAll { $0.id == id }
        case .documents:
            if let document = data.documents.first(where: { $0.id == id }) {
                ImageStore.delete(document.photoName)
            }
            data.documents.removeAll { $0.id == id }
        case .payments:
            if let payment = data.payments.first(where: { $0.id == id }) {
                ImageStore.delete(payment.receiptPhotoName)
            }
            data.payments.removeAll { $0.id == id }
        case .renewals:
            data.renewals.removeAll { $0.id == id }
        }
        // The server already knows: this device does not have to tell it again.
        data.tombstones.removeAll { $0.id == id && $0.collection == collection }
    }

    // MARK: Account changes

    /// Signing in as a different person starts from an empty ledger. Nothing of
    /// the previous account is left on the device to leak into the new one.
    func resetForNewAccount() {
        ImageStore.deleteAll()
        let keptSettings = AppSettings(
            displayName: "",
            country: data.settings.country,
            currencyCode: data.settings.currencyCode,
            rules: data.settings.rules,
            notificationsEnabled: false,
            notificationPrefs: NotificationPrefs(),
            onboardingDone: data.settings.onboardingDone,
            setupDone: false
        )
        data = LedgerData()
        data.settings = keptSettings
        lastSyncedSettings = nil
        NotificationScheduler.shared.cancelAll()
    }

    /// Everything on this device goes: used after the account itself is deleted.
    func wipeForSignOut() {
        ImageStore.deleteAll()
        data = LedgerData()
        lastSyncedSettings = nil
        NotificationScheduler.shared.cancelAll()
        saveNow()
    }
}
