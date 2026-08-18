//
//  SyncMapper.swift
//  TicketLedger
//
//  Field by field translation between the app's models and the API's records.
//  It is written out longhand on purpose: a mismatch here would silently lose a
//  fine, so every field is visible and reviewable rather than reflected over.
//

import Foundation

@MainActor
enum SyncMapper {

    // MARK: - Outgoing

    static func encode(_ vehicle: Vehicle) -> JSONValue {
        .object([
            "id": .string(vehicle.id.uuidString),
            "plate": .string(vehicle.plate),
            "makeModel": .string(vehicle.makeModel),
            "year": .string(vehicle.year),
            "vin": .string(vehicle.vin),
            "owner": .string(vehicle.owner),
            "registeredKeeper": .string(vehicle.registeredKeeper),
            "insurancePolicy": .string(vehicle.insurancePolicy),
            "purchaseDate": .date(vehicle.purchaseDate),
            "saleDate": .date(vehicle.saleDate),
            "photoName": vehicle.photoName.map { JSONValue.string($0) } ?? .null,
            "notes": .string(vehicle.notes),
            "createdAt": .date(vehicle.createdAt),
        ])
    }

    static func encode(_ driver: Driver) -> JSONValue {
        .object([
            "id": .string(driver.id.uuidString),
            "name": .string(driver.name),
            "licenceValidUntil": .date(driver.licenceValidUntil),
            "usualVehicleID": .uuid(driver.usualVehicleID),
            "relationship": .string(driver.relationship.rawValue),
            "notes": .string(driver.notes),
            "createdAt": .date(driver.createdAt),
        ])
    }

    static func encode(_ fine: Fine) -> JSONValue {
        .object([
            "id": .string(fine.id.uuidString),
            "noticeNumber": .string(fine.noticeNumber),
            "vehicleID": .uuid(fine.vehicleID),
            "vehiclePlateSnapshot": .string(fine.vehiclePlateSnapshot),
            "vehicleModelSnapshot": .string(fine.vehicleModelSnapshot),
            "dateOfOffence": .date(fine.dateOfOffence),
            "dateReceived": .date(fine.dateReceived),
            "amount": .number(fine.amount),
            "discountedAmount": .money(fine.discountedAmount),
            "article": .string(fine.article),
            "details": .string(fine.details),
            "location": .string(fine.location),
            "issuingAuthority": .string(fine.issuingAuthority),
            "driverID": .uuid(fine.driverID),
            "driverNameSnapshot": fine.driverNameSnapshot.map { JSONValue.string($0) } ?? .null,
            "noticePhotoName": fine.noticePhotoName.map { JSONValue.string($0) } ?? .null,
            "status": .string(fine.status.rawValue),
            "notes": .string(fine.notes),
            "rulesOverride": .encoding(fine.rulesOverride),
            "discountDeadlineOverride": .date(fine.discountDeadlineOverride),
            "appealDeadlineOverride": .date(fine.appealDeadlineOverride),
            "enforcementDateOverride": .date(fine.enforcementDateOverride),
            "enforcementExtraCost": .money(fine.enforcementExtraCost),
            "grounds": .array(fine.grounds.map { JSONValue.string($0.rawValue) }),
            "evidence": .encoding(fine.evidence),
            "appeal": .encoding(fine.appeal),
            "decision": .encoding(fine.decision),
            "closedAt": .date(fine.closedAt),
            "createdAt": .date(fine.createdAt),
        ])
    }

    static func encode(_ document: DocumentItem) -> JSONValue {
        .object([
            "id": .string(document.id.uuidString),
            "type": .string(document.type.rawValue),
            "vehicleID": .uuid(document.vehicleID),
            "personID": .uuid(document.personID),
            "reference": .string(document.reference),
            "validFrom": .date(document.validFrom),
            "validUntil": .date(document.validUntil),
            "cost": .money(document.cost),
            "reminderDays": document.reminderDays.map { JSONValue.integer($0) } ?? .null,
            "photoName": document.photoName.map { JSONValue.string($0) } ?? .null,
            "notes": .string(document.notes),
            "renewedAt": .date(document.renewedAt),
            "createdAt": .date(document.createdAt),
        ])
    }

    static func encode(_ payment: PaymentRecord) -> JSONValue {
        let kind: String
        let target: UUID?
        switch payment.target {
        case .fine(let id):
            kind = "fine"
            target = id
        case .document(let id):
            kind = "document"
            target = id
        }
        return .object([
            "id": .string(payment.id.uuidString),
            "targetKind": .string(kind),
            "targetID": .uuid(target),
            "subjectSnapshot": .string(payment.subjectSnapshot),
            "amountPaid": .number(payment.amountPaid),
            "expectedAmount": .money(payment.expectedAmount),
            "date": .date(payment.date),
            "method": .string(payment.method.rawValue),
            "reference": .string(payment.reference),
            "receiptPhotoName": payment.receiptPhotoName.map { JSONValue.string($0) } ?? .null,
            "paidByDriverID": .uuid(payment.paidByDriverID),
            "paidByName": .string(payment.paidByName),
            "notes": .string(payment.notes),
            "createdAt": .date(payment.date),
        ])
    }

    static func encode(_ renewal: RenewalRecord) -> JSONValue {
        .object([
            "id": .string(renewal.id.uuidString),
            "documentID": .string(renewal.documentID.uuidString),
            "typeSnapshot": .string(renewal.typeSnapshot.rawValue),
            "subjectSnapshot": .string(renewal.subjectSnapshot),
            "previousValidUntil": .date(renewal.previousValidUntil),
            "newValidUntil": .date(renewal.newValidUntil),
            "renewedOn": .date(renewal.renewedOn),
            "cost": .money(renewal.cost),
            "onTime": .bool(renewal.onTime),
            "createdAt": .date(renewal.renewedOn),
        ])
    }

    static func settings(from settings: AppSettings) -> APISettings {
        APISettings(
            displayName: settings.displayName,
            country: settings.country,
            currencyCode: settings.currencyCode,
            discountWindowDays: settings.rules.discountWindowDays,
            appealWindowDays: settings.rules.appealWindowDays,
            enforcementAfterDays: settings.rules.enforcementAfterDays,
            notificationsEnabled: settings.notificationsEnabled,
            notificationPrefs: settings.notificationPrefs,
            onboardingDone: settings.onboardingDone,
            setupDone: settings.setupDone
        )
    }

    // MARK: - Incoming

    /// Applies one remote record, keeping the local copy when it is newer.
    static func merge(_ record: SyncRecord, collection: SyncCollection, into store: Store) {
        let raw = record.raw
        let remoteStamp = record.updatedAt ?? .distantPast

        switch collection {
        case .vehicles:
            if let local = store.vehicle(record.id), (local.updatedAt ?? .distantPast) > remoteStamp { return }
            var item = store.vehicle(record.id) ?? Vehicle(id: record.id)
            item.id = record.id
            item.plate = raw["plate"]?.stringValue ?? item.plate
            item.makeModel = raw["makeModel"]?.stringValue ?? item.makeModel
            item.year = raw["year"]?.stringValue ?? item.year
            item.vin = raw["vin"]?.stringValue ?? item.vin
            item.owner = raw["owner"]?.stringValue ?? item.owner
            item.registeredKeeper = raw["registeredKeeper"]?.stringValue ?? item.registeredKeeper
            item.insurancePolicy = raw["insurancePolicy"]?.stringValue ?? item.insurancePolicy
            item.purchaseDate = raw["purchaseDate"]?.dateValue
            item.saleDate = raw["saleDate"]?.dateValue
            item.photoName = raw["photoName"]?.stringValue
            item.notes = raw["notes"]?.stringValue ?? item.notes
            item.createdAt = raw["createdAt"]?.dateValue ?? item.createdAt
            item.updatedAt = remoteStamp
            item.syncedAt = remoteStamp
            store.applyRemote(item)

        case .drivers:
            if let local = store.driver(record.id), (local.updatedAt ?? .distantPast) > remoteStamp { return }
            var item = store.driver(record.id) ?? Driver(id: record.id)
            item.id = record.id
            item.name = raw["name"]?.stringValue ?? item.name
            item.licenceValidUntil = raw["licenceValidUntil"]?.dateValue
            item.usualVehicleID = raw["usualVehicleID"]?.uuidValue
            item.relationship = raw["relationship"]?.stringValue
                .flatMap(DriverRelationship.init(rawValue:)) ?? item.relationship
            item.notes = raw["notes"]?.stringValue ?? item.notes
            item.createdAt = raw["createdAt"]?.dateValue ?? item.createdAt
            item.updatedAt = remoteStamp
            item.syncedAt = remoteStamp
            store.applyRemote(item)

        case .fines:
            if let local = store.fine(record.id), (local.updatedAt ?? .distantPast) > remoteStamp { return }
            var item = store.fine(record.id) ?? Fine(id: record.id)
            item.id = record.id
            item.noticeNumber = raw["noticeNumber"]?.stringValue ?? item.noticeNumber
            item.vehicleID = raw["vehicleID"]?.uuidValue
            item.vehiclePlateSnapshot = raw["vehiclePlateSnapshot"]?.stringValue ?? item.vehiclePlateSnapshot
            item.vehicleModelSnapshot = raw["vehicleModelSnapshot"]?.stringValue ?? item.vehicleModelSnapshot
            item.dateOfOffence = raw["dateOfOffence"]?.dateValue ?? item.dateOfOffence
            item.dateReceived = raw["dateReceived"]?.dateValue ?? item.dateReceived
            item.amount = raw["amount"]?.doubleValue ?? item.amount
            item.discountedAmount = raw["discountedAmount"]?.doubleValue
            item.article = raw["article"]?.stringValue ?? item.article
            item.details = raw["details"]?.stringValue ?? item.details
            item.location = raw["location"]?.stringValue ?? item.location
            item.issuingAuthority = raw["issuingAuthority"]?.stringValue ?? item.issuingAuthority
            item.driverID = raw["driverID"]?.uuidValue
            item.driverNameSnapshot = raw["driverNameSnapshot"]?.stringValue
            item.noticePhotoName = raw["noticePhotoName"]?.stringValue
            item.status = raw["status"]?.stringValue.flatMap(FineStatus.init(rawValue:)) ?? item.status
            item.notes = raw["notes"]?.stringValue ?? item.notes
            item.rulesOverride = raw["rulesOverride"]?.decoded(DeadlineRules.self)
            item.discountDeadlineOverride = raw["discountDeadlineOverride"]?.dateValue
            item.appealDeadlineOverride = raw["appealDeadlineOverride"]?.dateValue
            item.enforcementDateOverride = raw["enforcementDateOverride"]?.dateValue
            item.enforcementExtraCost = raw["enforcementExtraCost"]?.doubleValue
            item.grounds = (raw["grounds"]?.arrayValue ?? [])
                .compactMap { $0.stringValue.flatMap(AppealGround.init(rawValue:)) }
            item.evidence = raw["evidence"]?.decoded([EvidenceItem].self) ?? []
            item.appeal = raw["appeal"]?.decoded(AppealCase.self)
            item.decision = raw["decision"]?.decoded(Decision.self)
            item.closedAt = raw["closedAt"]?.dateValue
            item.createdAt = raw["createdAt"]?.dateValue ?? item.createdAt
            item.updatedAt = remoteStamp
            item.syncedAt = remoteStamp
            store.applyRemote(item)

        case .documents:
            if let local = store.document(record.id), (local.updatedAt ?? .distantPast) > remoteStamp { return }
            var item = store.document(record.id) ?? DocumentItem(id: record.id)
            item.id = record.id
            item.type = raw["type"]?.stringValue.flatMap(DocumentType.init(rawValue:)) ?? item.type
            item.vehicleID = raw["vehicleID"]?.uuidValue
            item.personID = raw["personID"]?.uuidValue
            item.reference = raw["reference"]?.stringValue ?? item.reference
            item.validFrom = raw["validFrom"]?.dateValue
            item.validUntil = raw["validUntil"]?.dateValue ?? item.validUntil
            item.cost = raw["cost"]?.doubleValue
            item.reminderDays = raw["reminderDays"]?.intValue
            item.photoName = raw["photoName"]?.stringValue
            item.notes = raw["notes"]?.stringValue ?? item.notes
            item.renewedAt = raw["renewedAt"]?.dateValue
            item.createdAt = raw["createdAt"]?.dateValue ?? item.createdAt
            item.updatedAt = remoteStamp
            item.syncedAt = remoteStamp
            store.applyRemote(item)

        case .payments:
            if let local = store.payment(record.id), (local.updatedAt ?? .distantPast) > remoteStamp { return }
            guard let targetID = raw["targetID"]?.uuidValue,
                  let kind = raw["targetKind"]?.stringValue else { return }
            var item = store.payment(record.id) ?? PaymentRecord(target: .fine(targetID))
            item.id = record.id
            item.target = kind == "document" ? .document(targetID) : .fine(targetID)
            item.subjectSnapshot = raw["subjectSnapshot"]?.stringValue ?? item.subjectSnapshot
            item.amountPaid = raw["amountPaid"]?.doubleValue ?? item.amountPaid
            item.expectedAmount = raw["expectedAmount"]?.doubleValue
            item.date = raw["date"]?.dateValue ?? item.date
            item.method = raw["method"]?.stringValue.flatMap(PaymentMethod.init(rawValue:)) ?? item.method
            item.reference = raw["reference"]?.stringValue ?? item.reference
            item.receiptPhotoName = raw["receiptPhotoName"]?.stringValue
            item.paidByDriverID = raw["paidByDriverID"]?.uuidValue
            item.paidByName = raw["paidByName"]?.stringValue ?? item.paidByName
            item.notes = raw["notes"]?.stringValue ?? item.notes
            item.updatedAt = remoteStamp
            item.syncedAt = remoteStamp
            store.applyRemote(item)

        case .renewals:
            if let local = store.renewal(record.id), (local.updatedAt ?? .distantPast) > remoteStamp { return }
            guard let documentID = raw["documentID"]?.uuidValue,
                  let type = raw["typeSnapshot"]?.stringValue.flatMap(DocumentType.init(rawValue:)) else { return }
            var item = store.renewal(record.id) ?? RenewalRecord(
                documentID: documentID,
                typeSnapshot: type,
                subjectSnapshot: "",
                previousValidUntil: Date(),
                newValidUntil: Date(),
                renewedOn: Date(),
                onTime: false
            )
            item.id = record.id
            item.documentID = documentID
            item.typeSnapshot = type
            item.subjectSnapshot = raw["subjectSnapshot"]?.stringValue ?? item.subjectSnapshot
            item.previousValidUntil = raw["previousValidUntil"]?.dateValue ?? item.previousValidUntil
            item.newValidUntil = raw["newValidUntil"]?.dateValue ?? item.newValidUntil
            item.renewedOn = raw["renewedOn"]?.dateValue ?? item.renewedOn
            item.cost = raw["cost"]?.doubleValue
            item.onTime = raw["onTime"]?.boolValue ?? item.onTime
            item.updatedAt = remoteStamp
            item.syncedAt = remoteStamp
            store.applyRemote(item)
        }
    }

    static func applySettings(_ remote: APISettings, to store: Store) {
        // Same rule as for records: the later change wins. Without this, a
        // device that set its currency before its first sync would have it
        // replaced by whatever the server was created with.
        let localStamp = store.data.settings.updatedAt
        if let localStamp, let remoteStamp = remote.updatedAt, localStamp > remoteStamp {
            return
        }
        var settings = store.data.settings
        if let value = remote.displayName { settings.displayName = value }
        if let value = remote.country { settings.country = value }
        if let value = remote.currencyCode, !value.isEmpty { settings.currencyCode = value }
        if let value = remote.discountWindowDays { settings.rules.discountWindowDays = value }
        if let value = remote.appealWindowDays { settings.rules.appealWindowDays = value }
        if let value = remote.enforcementAfterDays { settings.rules.enforcementAfterDays = value }
        if let value = remote.notificationPrefs { settings.notificationPrefs = value }
        if let value = remote.onboardingDone, value { settings.onboardingDone = true }
        if let value = remote.setupDone, value { settings.setupDone = true }
        settings.updatedAt = remote.updatedAt ?? settings.updatedAt
        // Notification permission belongs to the device, not to the account, so
        // it is deliberately not copied down from the server.
        store.applyRemoteSettings(settings)
    }
}
