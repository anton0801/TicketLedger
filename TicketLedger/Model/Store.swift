//
//  Store.swift
//  TicketLedger
//
//  One JSON document in Application Support. No account, no sync, no network.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class Store {

    enum LoadState: Equatable {
        case loading
        case ready
        case failed(String)
    }

    var state: LoadState = .loading
    var data = LedgerData()
    /// Surfaced in Settings when a write fails.
    var saveError: String?

    /// The settings as the server last saw them, so the engine can tell whether
    /// they need pushing without stamping them on every keystroke.
    var lastSyncedSettings: AppSettings?

    private var saveTask: Task<Void, Never>?
    private let fileName = "ledger.json"

    // MARK: Paths

    private var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TicketLedger", isDirectory: true)
    }

    private var fileURL: URL { folder.appendingPathComponent(fileName) }

    // MARK: Load & save

    func load() async {
        state = .loading
        let url = fileURL
        do {
            let loaded: LedgerData? = try await Task.detached(priority: .userInitiated) { () -> LedgerData? in
                guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                let raw = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(LedgerData.self, from: raw)
            }.value

            if let loaded {
                data = loaded
            } else {
                data = LedgerData()
            }
            state = .ready
        } catch {
            state = .failed("The ledger file could not be read. It may be from a newer version of the app, or damaged. Nothing has been deleted — you can retry, or start a fresh ledger from Settings.")
        }
    }

    func retryLoad() {
        Task { await load() }
    }

    /// Debounced write, so typing in a form does not hit the disk on each keystroke.
    func save() {
        saveTask?.cancel()
        let snapshot = data
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await self?.write(snapshot)
            NotificationScheduler.shared.reschedule(with: snapshot)
        }
    }

    /// Immediate write, used before export and when leaving destructive flows.
    func saveNow() {
        saveTask?.cancel()
        let snapshot = data
        Task { await write(snapshot) }
        NotificationScheduler.shared.reschedule(with: data)
    }

    private func write(_ snapshot: LedgerData) async {
        let url = fileURL
        let dir = folder
        let result: String? = await Task.detached(priority: .utility) { () -> String? in
            do {
                if !FileManager.default.fileExists(atPath: dir.path) {
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                }
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = .prettyPrinted
                let raw = try encoder.encode(snapshot)
                try raw.write(to: url, options: .atomic)
                return nil
            } catch {
                return error.localizedDescription
            }
        }.value
        saveError = result
    }

    // MARK: Settings

    var settings: AppSettings {
        get { data.settings }
        set {
            var stamped = newValue
            stamped.updatedAt = Date()
            data.settings = stamped
            save()
        }
    }

    var currency: String { data.settings.currencyCode }

    // MARK: Vehicles

    var vehicles: [Vehicle] { data.vehicles.sorted { $0.createdAt < $1.createdAt } }

    func vehicle(_ id: UUID?) -> Vehicle? {
        guard let id else { return nil }
        return data.vehicles.first { $0.id == id }
    }

    func upsert(_ vehicle: Vehicle) {
        var vehicle = vehicle
        vehicle.updatedAt = Date()
        if let index = data.vehicles.firstIndex(where: { $0.id == vehicle.id }) {
            data.vehicles[index] = vehicle
            // Keep the snapshots on existing fines in step with the plate.
            for i in data.fines.indices where data.fines[i].vehicleID == vehicle.id {
                data.fines[i].vehiclePlateSnapshot = vehicle.plate
                data.fines[i].vehicleModelSnapshot = vehicle.makeModel
                data.fines[i].updatedAt = Date()
            }
        } else {
            data.vehicles.append(vehicle)
        }
        save()
    }

    /// Deleting a car keeps the history: fines hold a snapshot of plate and model.
    func deleteVehicle(_ vehicle: Vehicle) {
        ImageStore.delete(vehicle.photoName)
        data.vehicles.removeAll { $0.id == vehicle.id }
        recordTombstone(.vehicles, vehicle.id)
        for i in data.fines.indices where data.fines[i].vehicleID == vehicle.id {
            data.fines[i].vehicleID = nil
        }
        for i in data.drivers.indices where data.drivers[i].usualVehicleID == vehicle.id {
            data.drivers[i].usualVehicleID = nil
        }
        // Open documents for a car that is gone have nothing left to track.
        let orphans = data.documents.filter { $0.vehicleID == vehicle.id }
        for doc in orphans { ImageStore.delete(doc.photoName) }
        for doc in orphans { recordTombstone(.documents, doc.id) }
        data.documents.removeAll { $0.vehicleID == vehicle.id }
        save()
    }

    func drivers(of vehicle: Vehicle) -> [Driver] {
        data.drivers.filter { $0.usualVehicleID == vehicle.id }
    }

    /// A driver must be recorded when more than one person uses the car.
    func requiresDriver(for vehicleID: UUID?) -> Bool {
        guard let vehicleID else { return false }
        return data.drivers.filter { $0.usualVehicleID == vehicleID }.count > 1
    }

    // MARK: Drivers

    var drivers: [Driver] { data.drivers.sorted { $0.createdAt < $1.createdAt } }

    func driver(_ id: UUID?) -> Driver? {
        guard let id else { return nil }
        return data.drivers.first { $0.id == id }
    }

    func upsert(_ driver: Driver) {
        var driver = driver
        driver.updatedAt = Date()
        if let index = data.drivers.firstIndex(where: { $0.id == driver.id }) {
            data.drivers[index] = driver
            for i in data.fines.indices where data.fines[i].driverID == driver.id {
                data.fines[i].driverNameSnapshot = driver.name
                data.fines[i].updatedAt = Date()
            }
        } else {
            data.drivers.append(driver)
        }
        save()
    }

    func deleteDriver(_ driver: Driver) {
        data.drivers.removeAll { $0.id == driver.id }
        recordTombstone(.drivers, driver.id)
        for i in data.fines.indices where data.fines[i].driverID == driver.id {
            data.fines[i].driverID = nil
        }
        for doc in data.documents where doc.personID == driver.id { recordTombstone(.documents, doc.id) }
        data.documents.removeAll { $0.personID == driver.id }
        save()
    }

    func fines(of driver: Driver) -> [Fine] {
        data.fines.filter { $0.driverID == driver.id }
    }

    // MARK: Fines

    var fines: [Fine] { data.fines.sorted { $0.dateReceived > $1.dateReceived } }

    func fine(_ id: UUID?) -> Fine? {
        guard let id else { return nil }
        return data.fines.first { $0.id == id }
    }

    func upsert(_ fine: Fine) {
        var copy = fine
        copy.updatedAt = Date()
        if let vehicle = vehicle(fine.vehicleID) {
            copy.vehiclePlateSnapshot = vehicle.plate
            copy.vehicleModelSnapshot = vehicle.makeModel
        }
        if let driver = driver(fine.driverID) {
            copy.driverNameSnapshot = driver.name
        }
        if copy.status.isClosed, copy.closedAt == nil {
            copy.closedAt = Date()
        }
        if !copy.status.isClosed {
            copy.closedAt = nil
        }
        if let index = data.fines.firstIndex(where: { $0.id == copy.id }) {
            data.fines[index] = copy
        } else {
            data.fines.append(copy)
        }
        save()
    }

    func deleteFine(_ fine: Fine) {
        ImageStore.delete(fine.noticePhotoName)
        for item in fine.evidence { ImageStore.delete(item.fileName) }
        for payment in data.payments where payment.target.fineID == fine.id {
            ImageStore.delete(payment.receiptPhotoName)
        }
        for payment in data.payments where payment.target.fineID == fine.id {
            recordTombstone(.payments, payment.id)
        }
        data.payments.removeAll { $0.target.fineID == fine.id }
        data.fines.removeAll { $0.id == fine.id }
        recordTombstone(.fines, fine.id)
        save()
    }

    /// Same notice entered twice is a real risk when adding by hand and by scan.
    func duplicateNotice(_ number: String, excluding id: UUID?) -> Fine? {
        let key = number.trimmingCharacters(in: .whitespaces).uppercased()
        guard !key.isEmpty else { return nil }
        return data.fines.first {
            $0.id != id && $0.noticeNumber.trimmingCharacters(in: .whitespaces).uppercased() == key
        }
    }

    /// A notice dated after the car was sold is worth flagging, not paying blind.
    func isAfterSale(_ fine: Fine) -> Bool {
        guard let vehicle = vehicle(fine.vehicleID), let saleDate = vehicle.saleDate else { return false }
        return Fmt.cal.startOfDay(for: fine.dateOfOffence) > Fmt.cal.startOfDay(for: saleDate)
    }

    // MARK: Documents

    var documents: [DocumentItem] { data.documents.sorted { $0.validUntil < $1.validUntil } }

    func document(_ id: UUID?) -> DocumentItem? {
        guard let id else { return nil }
        return data.documents.first { $0.id == id }
    }

    func upsert(_ document: DocumentItem) {
        var document = document
        document.updatedAt = Date()
        if let index = data.documents.firstIndex(where: { $0.id == document.id }) {
            data.documents[index] = document
        } else {
            data.documents.append(document)
        }
        save()
    }

    func deleteDocument(_ document: DocumentItem) {
        ImageStore.delete(document.photoName)
        for payment in data.payments where payment.target.documentID == document.id {
            recordTombstone(.payments, payment.id)
        }
        data.payments.removeAll { $0.target.documentID == document.id }
        data.documents.removeAll { $0.id == document.id }
        recordTombstone(.documents, document.id)
        save()
    }

    /// Records a renewal: the old dates go to history, the document carries on.
    func renew(_ document: DocumentItem, newValidUntil: Date, cost: Double?, on date: Date = Date()) {
        var record = RenewalRecord(
            documentID: document.id,
            typeSnapshot: document.type,
            subjectSnapshot: subject(for: document),
            previousValidUntil: document.validUntil,
            newValidUntil: newValidUntil,
            renewedOn: date,
            cost: cost,
            onTime: Fmt.cal.startOfDay(for: date) <= Fmt.cal.startOfDay(for: document.validUntil)
        )
        record.updatedAt = Date()
        data.renewals.append(record)
        if let index = data.documents.firstIndex(where: { $0.id == document.id }) {
            data.documents[index].updatedAt = Date()
            data.documents[index].validFrom = document.validUntil
            data.documents[index].validUntil = newValidUntil
            data.documents[index].cost = cost ?? document.cost
            data.documents[index].renewedAt = date
        }
        save()
    }

    /// The three vehicle deadlines live in Documents so the queue has one source.
    func vehicleDeadline(_ type: DocumentType, for vehicleID: UUID) -> DocumentItem? {
        data.documents.first { $0.type == type && $0.vehicleID == vehicleID }
    }

    func setVehicleDeadline(_ type: DocumentType, for vehicleID: UUID, validUntil: Date?, reference: String = "") {
        if let validUntil {
            if var existing = vehicleDeadline(type, for: vehicleID) {
                existing.validUntil = validUntil
                if !reference.isEmpty { existing.reference = reference }
                upsert(existing)
            } else {
                var item = DocumentItem()
                item.type = type
                item.vehicleID = vehicleID
                item.validUntil = validUntil
                item.reference = reference
                upsert(item)
            }
        } else if let existing = vehicleDeadline(type, for: vehicleID) {
            deleteDocument(existing)
        }
    }

    func subject(for document: DocumentItem) -> String {
        if let vehicle = vehicle(document.vehicleID) {
            return vehicle.plate.isEmpty ? vehicle.displayName : vehicle.plate.uppercased()
        }
        if let driver = driver(document.personID) {
            return driver.name
        }
        return "Unassigned"
    }

    // MARK: Payments

    var payments: [PaymentRecord] { data.payments.sorted { $0.date > $1.date } }

    func payments(forFine id: UUID) -> [PaymentRecord] {
        data.payments.filter { $0.target.fineID == id }.sorted { $0.date > $1.date }
    }

    func payments(forDocument id: UUID) -> [PaymentRecord] {
        data.payments.filter { $0.target.documentID == id }.sorted { $0.date > $1.date }
    }

    func upsert(_ payment: PaymentRecord) {
        var payment = payment
        payment.updatedAt = Date()
        if let index = data.payments.firstIndex(where: { $0.id == payment.id }) {
            data.payments[index] = payment
        } else {
            data.payments.append(payment)
        }
        save()
    }

    func deletePayment(_ payment: PaymentRecord) {
        ImageStore.delete(payment.receiptPhotoName)
        data.payments.removeAll { $0.id == payment.id }
        recordTombstone(.payments, payment.id)
        save()
    }

    var renewals: [RenewalRecord] { data.renewals.sorted { $0.renewedOn > $1.renewedOn } }

    // MARK: Obligations & queue

    func obligations(now: Date = Date()) -> [Obligation] {
        var result: [Obligation] = []
        for fine in data.fines {
            if let item = DeadlineEngine.obligation(for: fine, settings: data.settings, now: now) {
                result.append(item)
            }
        }
        for document in data.documents {
            result.append(DeadlineEngine.obligation(
                for: document,
                subject: subject(for: document),
                settings: data.settings,
                now: now
            ))
        }
        return DeadlineEngine.sort(result)
    }

    func openFineCount(now: Date = Date()) -> Int {
        data.fines.filter { !$0.status.isClosed }.count
    }

    /// Anything that loses money or validity in the next seven days.
    func urgentCount(now: Date = Date()) -> Int {
        obligations(now: now).filter { $0.severity == .losing || ($0.daysLeft ?? 99) <= 7 }.count
    }

    func nextDeadline(now: Date = Date()) -> Clock? {
        obligations(now: now)
            .compactMap(\.nextClock)
            .min { $0.daysLeft < $1.daysLeft }
    }

    // MARK: Closing a fine

    /// Records a payment and closes the fine, keeping the expected amount so the
    /// Insights section can show what inattention cost.
    func recordPayment(
        for fine: Fine,
        amount: Double,
        date: Date,
        method: PaymentMethod,
        reference: String,
        receiptPhotoName: String?,
        paidByDriverID: UUID?,
        paidByName: String,
        notes: String,
        closeFine: Bool
    ) {
        let expected = DeadlineEngine.amountToday(for: fine, settings: data.settings, now: date)
        var payment = PaymentRecord(target: .fine(fine.id))
        payment.subjectSnapshot = "\(fine.noticeNumber) · \(fine.vehiclePlateSnapshot)"
        payment.amountPaid = amount
        payment.expectedAmount = expected
        payment.date = date
        payment.method = method
        payment.reference = reference
        payment.receiptPhotoName = receiptPhotoName
        payment.paidByDriverID = paidByDriverID
        payment.paidByName = paidByName
        payment.notes = notes
        payment.updatedAt = Date()
        data.payments.append(payment)

        if closeFine, let index = data.fines.firstIndex(where: { $0.id == fine.id }) {
            data.fines[index].status = .paid
            data.fines[index].closedAt = date
            data.fines[index].updatedAt = Date()
        }
        save()
    }

    func totalPaid(forFine id: UUID) -> Double {
        data.payments.filter { $0.target.fineID == id }.reduce(0) { $0 + $1.amountPaid }
    }

    // MARK: History

    var closedFines: [Fine] {
        data.fines.filter { $0.status.isClosed }.sorted { ($0.closedAt ?? $0.createdAt) > ($1.closedAt ?? $1.createdAt) }
    }

    var closedCaseCount: Int { closedFines.count + data.renewals.count }

    // MARK: Locations

    struct LocationStat: Identifiable {
        var id: String { key }
        var key: String
        var display: String
        var count: Int
        var totalPaid: Double
        var totalAmount: Double
        var types: [String]
        var lastDate: Date
    }

    func locationStats() -> [LocationStat] {
        var buckets: [String: LocationStat] = [:]
        for fine in data.fines {
            let raw = fine.location.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { continue }
            let key = raw.lowercased()
            let paid = totalPaid(forFine: fine.id)
            if var existing = buckets[key] {
                existing.count += 1
                existing.totalPaid += paid
                existing.totalAmount += fine.amount
                if !existing.types.contains(fine.titleLine) { existing.types.append(fine.titleLine) }
                existing.lastDate = max(existing.lastDate, fine.dateOfOffence)
                buckets[key] = existing
            } else {
                buckets[key] = LocationStat(
                    key: key,
                    display: raw,
                    count: 1,
                    totalPaid: paid,
                    totalAmount: fine.amount,
                    types: [fine.titleLine],
                    lastDate: fine.dateOfOffence
                )
            }
        }
        return buckets.values.sorted {
            $0.count != $1.count ? $0.count > $1.count : $0.totalPaid > $1.totalPaid
        }
    }

    // MARK: Data management

    func clearHistory() {
        let closed = data.fines.filter { $0.status.isClosed }
        for fine in closed {
            ImageStore.delete(fine.noticePhotoName)
            for item in fine.evidence { ImageStore.delete(item.fileName) }
        }
        let closedIDs = Set(closed.map(\.id))
        for payment in data.payments where payment.target.fineID.map(closedIDs.contains) == true {
            ImageStore.delete(payment.receiptPhotoName)
        }
        data.payments.removeAll { payment in
            payment.target.fineID.map(closedIDs.contains) == true
        }
        data.fines.removeAll { $0.status.isClosed }
        data.renewals.removeAll()
        saveNow()
    }

    func deleteAllData() {
        ImageStore.deleteAll()
        data = LedgerData()
        try? FileManager.default.removeItem(at: fileURL)
        NotificationScheduler.shared.cancelAll()
        saveNow()
    }

    // MARK: Backup

    func exportBackup() throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let raw = try encoder.encode(data)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ticket-ledger-backup.json")
        try raw.write(to: url, options: .atomic)
        return url
    }

    func importBackup(from url: URL) throws {
        let raw = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let imported = try decoder.decode(LedgerData.self, from: raw)
        data = imported
        saveNow()
    }
}
