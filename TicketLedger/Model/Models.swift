//
//  Models.swift
//  TicketLedger
//
//  Everything is stored locally. No account, no register, no network.
//

import SwiftUI

// MARK: - Deadline rules

/// The three windows. They differ by country and by type of fine, so the user
/// owns these numbers — the app only suggests a starting point.
struct DeadlineRules: Codable, Equatable, Hashable {
    var discountWindowDays: Int
    var appealWindowDays: Int
    var enforcementAfterDays: Int

    static let suggested = DeadlineRules(
        discountWindowDays: 20,
        appealWindowDays: 10,
        enforcementAfterDays: 70
    )

    var isValid: Bool {
        discountWindowDays >= 0 && appealWindowDays >= 0 && enforcementAfterDays > 0
    }
}

// MARK: - Vehicle

struct Vehicle: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var plate: String = ""
    var makeModel: String = ""
    var year: String = ""
    var vin: String = ""
    var owner: String = ""
    var registeredKeeper: String = ""
    var insurancePolicy: String = ""
    var purchaseDate: Date?
    var saleDate: Date?
    var photoName: String?
    var notes: String = ""
    var createdAt: Date = Date()
    /// Last local change. Drives what the sync engine has to push.
    var updatedAt: Date?
    /// The value of `updatedAt` the server has already accepted. When the two
    /// differ, this record is waiting to go up.
    var syncedAt: Date?

    var isSold: Bool { saleDate != nil }
    var displayName: String {
        let name = makeModel.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? plate.uppercased() : name
    }
}

// MARK: - Driver

enum DriverRelationship: String, Codable, CaseIterable, Identifiable {
    case myself, family, friend, employee, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .myself: "Myself"
        case .family: "Family"
        case .friend: "Friend"
        case .employee: "Employee"
        case .other: "Other"
        }
    }
}

struct Driver: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var licenceValidUntil: Date?
    var usualVehicleID: UUID?
    var relationship: DriverRelationship = .myself
    var notes: String = ""
    var createdAt: Date = Date()
    /// Last local change. Drives what the sync engine has to push.
    var updatedAt: Date?
    /// The value of `updatedAt` the server has already accepted. When the two
    /// differ, this record is waiting to go up.
    var syncedAt: Date?
}

// MARK: - Fine

enum FineStatus: String, Codable, CaseIterable, Identifiable {
    case open, underAppeal, paid, cancelled
    var id: String { rawValue }
    var title: String {
        switch self {
        case .open: "Open"
        case .underAppeal: "Under Appeal"
        case .paid: "Paid"
        case .cancelled: "Cancelled"
        }
    }
    var isClosed: Bool { self == .paid || self == .cancelled }
}

/// Buckets shown in the Fines tab. Some are stored, some come from the dates.
enum FineBucket: String, CaseIterable, Identifiable {
    case open, discountRunning, appealWindowOpen, underAppeal, paid, cancelled, enforcement
    var id: String { rawValue }
    var title: String {
        switch self {
        case .open: "Open"
        case .discountRunning: "Discount"
        case .appealWindowOpen: "Appeal Open"
        case .underAppeal: "Under Appeal"
        case .paid: "Paid"
        case .cancelled: "Cancelled"
        case .enforcement: "Enforcement"
        }
    }
}

enum AppealGround: String, Codable, CaseIterable, Identifiable {
    case notDriving, vehicleSold, signNotVisible, duplicateNotice
    case wrongVehicle, technicalError, emergency, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notDriving: "Not Driving at the Time"
        case .vehicleSold: "Vehicle Sold"
        case .signNotVisible: "Sign Not Visible"
        case .duplicateNotice: "Duplicate Notice"
        case .wrongVehicle: "Wrong Vehicle"
        case .technicalError: "Technical Error in Notice"
        case .emergency: "Emergency Circumstances"
        case .other: "Other"
        }
    }

    /// What people normally have to show for this ground. Not advice about
    /// whether the ground is good — the app never judges that.
    var usualEvidence: [EvidenceType] {
        switch self {
        case .notDriving: [.witnessContact, .correspondence, .otherDocument]
        case .vehicleSold: [.saleContract, .correspondence]
        case .signNotVisible: [.photoOfSign, .photoOfPlace, .dashcam]
        case .duplicateNotice: [.correspondence, .receipt]
        case .wrongVehicle: [.photoOfPlace, .otherDocument]
        case .technicalError: [.correspondence, .otherDocument]
        case .emergency: [.receipt, .repairInvoice, .otherDocument]
        case .other: []
        }
    }

    var evidenceHint: String? {
        switch self {
        case .vehicleSold:
            "You marked \"vehicle sold\". A sale contract with a date before the offence is the usual document here."
        case .signNotVisible:
            "You marked \"sign not visible\". A photo of the sign from the driver's position, taken at the same spot, is the usual document here."
        case .notDriving:
            "You marked \"not driving at the time\". Who was driving, and anything written down at the time, is the usual record here."
        case .duplicateNotice:
            "You marked \"duplicate notice\". The earlier notice or its payment receipt is the usual document here."
        case .wrongVehicle:
            "You marked \"wrong vehicle\". A photo showing your plate and the plate on the notice differ is the usual document here."
        case .technicalError:
            "You marked \"technical error in notice\". A photo of the notice itself with the error visible is the usual document here."
        case .emergency:
            "You marked \"emergency circumstances\". Whatever documents the event left behind — a receipt, an invoice, a report — are the usual records here."
        case .other:
            nil
        }
    }
}

enum EvidenceType: String, Codable, CaseIterable, Identifiable {
    case photoOfPlace, photoOfSign, dashcam, parkingTicket, receipt
    case repairInvoice, saleContract, witnessContact, correspondence, otherDocument

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photoOfPlace: "Photo of the Place"
        case .photoOfSign: "Photo of the Sign"
        case .dashcam: "Dashcam Footage"
        case .parkingTicket: "Parking Ticket"
        case .receipt: "Receipt"
        case .repairInvoice: "Repair Invoice"
        case .saleContract: "Sale Contract"
        case .witnessContact: "Witness Contact"
        case .correspondence: "Correspondence"
        case .otherDocument: "Other Document"
        }
    }

    var icon: String {
        switch self {
        case .photoOfPlace, .photoOfSign: "camera.fill"
        case .dashcam: "video.fill"
        case .parkingTicket: "ticket.fill"
        case .receipt: "receipt.fill"
        case .repairInvoice: "wrench.and.screwdriver.fill"
        case .saleContract: "doc.plaintext.fill"
        case .witnessContact: "person.fill"
        case .correspondence: "envelope.fill"
        case .otherDocument: "doc.fill"
        }
    }
}

struct EvidenceItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var type: EvidenceType = .photoOfPlace
    var description: String = ""
    var dateTaken: Date?
    var fileName: String?
    var source: String = ""
    var notes: String = ""
    var addedAt: Date = Date()
}

enum AppealMethod: String, Codable, CaseIterable, Identifiable {
    case post, email, onlineForm, inPerson, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .post: "Post"
        case .email: "Email"
        case .onlineForm: "Online Form"
        case .inPerson: "In Person"
        case .other: "Other"
        }
    }
}

enum AppealOutcome: String, Codable, CaseIterable, Identifiable {
    case cancelled, reduced, upheld, noAnswer, withdrawn
    var id: String { rawValue }
    var title: String {
        switch self {
        case .cancelled: "Cancelled"
        case .reduced: "Reduced"
        case .upheld: "Upheld"
        case .noAnswer: "No Answer"
        case .withdrawn: "Withdrawn"
        }
    }
    var isWin: Bool { self == .cancelled || self == .reduced }
    var color: Color {
        switch self {
        case .cancelled, .reduced: Theme.green
        case .upheld: Theme.maroon
        case .noAnswer, .withdrawn: Theme.terracotta
        }
    }
}

struct AppealCase: Codable, Hashable {
    var submittedOn: Date?
    var method: AppealMethod = .email
    var referenceNumber: String = ""
    var expectedAnswerBy: Date?
    var remindersSent: [Date] = []
    var answerReceived: Date?
    var outcome: AppealOutcome?
    var reducedToAmount: Double?
    var nextStep: String = ""

    var isSubmitted: Bool { submittedOn != nil }
}

enum DecisionKind: String, Codable {
    case payment, appeal, later
    var title: String {
        switch self {
        case .payment: "Marked for payment"
        case .appeal: "Marked for appeal"
        case .later: "Decision postponed"
        }
    }
}

struct Decision: Codable, Hashable {
    var kind: DecisionKind
    var date: Date
    var reason: String
}

struct Fine: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var noticeNumber: String = ""
    var vehicleID: UUID?
    /// Snapshots so history survives the vehicle being deleted.
    var vehiclePlateSnapshot: String = ""
    var vehicleModelSnapshot: String = ""
    var dateOfOffence: Date = Date()
    var dateReceived: Date = Date()
    var amount: Double = 0
    var discountedAmount: Double?
    var article: String = ""
    var details: String = ""
    var location: String = ""
    var issuingAuthority: String = ""
    var driverID: UUID?
    var driverNameSnapshot: String?
    var noticePhotoName: String?
    var status: FineStatus = .open
    var notes: String = ""

    /// Windows for this notice. Nil means "use the rules from Settings".
    var rulesOverride: DeadlineRules?
    /// Dates printed on the notice, when the user has them. These win.
    var discountDeadlineOverride: Date?
    var appealDeadlineOverride: Date?
    var enforcementDateOverride: Date?
    /// Extra costs added at enforcement. Nil means the user does not know it —
    /// the app never invents a number.
    var enforcementExtraCost: Double?

    var grounds: [AppealGround] = []
    var evidence: [EvidenceItem] = []
    var appeal: AppealCase?
    var decision: Decision?

    var closedAt: Date?
    var createdAt: Date = Date()
    /// Last local change. Drives what the sync engine has to push.
    var updatedAt: Date?
    /// The value of `updatedAt` the server has already accepted. When the two
    /// differ, this record is waiting to go up.
    var syncedAt: Date?

    var discountSaving: Double? {
        guard let discountedAmount, discountedAmount < amount else { return nil }
        return amount - discountedAmount
    }

    var titleLine: String {
        let a = article.trimmingCharacters(in: .whitespaces)
        let d = details.trimmingCharacters(in: .whitespaces)
        if !d.isEmpty { return d }
        if !a.isEmpty { return a }
        return "Fine"
    }
}

// MARK: - Documents

enum DocumentType: String, Codable, CaseIterable, Identifiable {
    case insurance, technicalInspection, roadTax, drivingLicence
    case registrationCertificate, powerOfAttorney, parkingPermit, emissionsSticker

    var id: String { rawValue }

    var title: String {
        switch self {
        case .insurance: "Insurance"
        case .technicalInspection: "Technical Inspection"
        case .roadTax: "Road Tax"
        case .drivingLicence: "Driving Licence"
        case .registrationCertificate: "Registration Certificate"
        case .powerOfAttorney: "Power of Attorney"
        case .parkingPermit: "Parking Permit"
        case .emissionsSticker: "Emissions Sticker"
        }
    }

    var shortTitle: String {
        switch self {
        case .insurance: "Insurance"
        case .technicalInspection: "Inspection"
        case .roadTax: "Road Tax"
        case .drivingLicence: "Licence"
        case .registrationCertificate: "Registration"
        case .powerOfAttorney: "Power of Attorney"
        case .parkingPermit: "Parking Permit"
        case .emissionsSticker: "Emissions"
        }
    }

    var icon: String {
        switch self {
        case .insurance: "shield.lefthalf.filled"
        case .technicalInspection: "wrench.and.screwdriver.fill"
        case .roadTax: "building.columns.fill"
        case .drivingLicence: "person.text.rectangle.fill"
        case .registrationCertificate: "doc.text.fill"
        case .powerOfAttorney: "signature"
        case .parkingPermit: "parkingsign"
        case .emissionsSticker: "leaf.fill"
        }
    }

    /// Belongs to a person rather than a car.
    var isPersonal: Bool { self == .drivingLicence }

    /// Driving on an expired one of these is the expensive kind of late.
    var expiryIsSerious: Bool {
        self == .insurance || self == .technicalInspection || self == .roadTax
    }
}

struct DocumentItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var type: DocumentType = .insurance
    var vehicleID: UUID?
    var personID: UUID?
    var reference: String = ""
    var validFrom: Date?
    var validUntil: Date = Date()
    var cost: Double?
    var reminderDays: Int? = 30
    var photoName: String?
    var notes: String = ""
    var createdAt: Date = Date()
    /// Last local change. Drives what the sync engine has to push.
    var updatedAt: Date?
    /// The value of `updatedAt` the server has already accepted. When the two
    /// differ, this record is waiting to go up.
    var syncedAt: Date?

    /// Set when the user records a renewal, so it stops nagging.
    var renewedAt: Date?
}

struct RenewalRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var documentID: UUID
    var typeSnapshot: DocumentType
    var subjectSnapshot: String
    var previousValidUntil: Date
    var newValidUntil: Date
    var renewedOn: Date
    var cost: Double?
    /// Renewed on or before the old expiry date.
    var onTime: Bool
    /// Last local change. Drives what the sync engine has to push.
    var updatedAt: Date?
    /// The value of `updatedAt` the server has already accepted. When the two
    /// differ, this record is waiting to go up.
    var syncedAt: Date?
}

// MARK: - Payments

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case card, bankTransfer, cash, onlinePortal, atPostOffice, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .card: "Card"
        case .bankTransfer: "Bank Transfer"
        case .cash: "Cash"
        case .onlinePortal: "Online Portal"
        case .atPostOffice: "At Post Office"
        case .other: "Other"
        }
    }
}

enum PaymentTarget: Codable, Hashable {
    case fine(UUID)
    case document(UUID)

    var fineID: UUID? { if case .fine(let id) = self { return id }; return nil }
    var documentID: UUID? { if case .document(let id) = self { return id }; return nil }
}

struct PaymentRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var target: PaymentTarget
    /// What the record is about, kept for history after deletions.
    var subjectSnapshot: String = ""
    var amountPaid: Double = 0
    var expectedAmount: Double?
    var date: Date = Date()
    var method: PaymentMethod = .card
    var reference: String = ""
    var receiptPhotoName: String?
    var paidByDriverID: UUID?
    var paidByName: String = ""
    var notes: String = ""
    /// Last local change. Drives what the sync engine has to push.
    var updatedAt: Date?
    /// The value of `updatedAt` the server has already accepted. When the two
    /// differ, this record is waiting to go up.
    var syncedAt: Date?

    /// Difference between what was paid and what was due at that moment.
    var discrepancy: Double? {
        guard let expectedAmount else { return nil }
        let delta = amountPaid - expectedAmount
        return abs(delta) < 0.005 ? nil : delta
    }
}

// MARK: - Notification preferences

struct NotificationPrefs: Codable, Equatable {
    var discountEnding = true
    var appealWindowClosing = true
    var enforcementApproaching = true
    var documentExpiring = true
    var appealAnswerOverdue = true
    var paymentNotRecorded = true
}

// MARK: - Settings

struct AppSettings: Codable, Equatable {
    var displayName: String = ""
    var country: String = ""
    var currencyCode: String = Locale.current.currency?.identifier ?? "EUR"
    var rules: DeadlineRules = .suggested
    var notificationsEnabled = false
    var notificationPrefs = NotificationPrefs()
    var onboardingDone = false
    var setupDone = false
    /// When these settings last changed on a device. Without it a first sync
    /// would let the server's defaults overwrite a choice just made here.
    var updatedAt: Date?

    /// Equality for sync purposes: the timestamp itself is not a difference.
    func matches(_ other: AppSettings?) -> Bool {
        guard var other else { return false }
        var mine = self
        mine.updatedAt = nil
        other.updatedAt = nil
        return mine == other
    }
}

// MARK: - Sync bookkeeping

/// Which collection a record belonged to. The names match the API paths.
enum SyncCollection: String, Codable, CaseIterable {
    case vehicles, drivers, fines, documents, payments, renewals
}

/// A record deleted on this device. Kept until the server has been told, so a
/// deletion made offline is not undone by the next pull.
struct Tombstone: Identifiable, Codable, Hashable {
    var id: UUID
    var collection: SyncCollection
    var deletedAt: Date
}

// MARK: - Whole document

struct LedgerData: Codable {
    var settings = AppSettings()
    var vehicles: [Vehicle] = []
    var drivers: [Driver] = []
    var fines: [Fine] = []
    var documents: [DocumentItem] = []
    var payments: [PaymentRecord] = []
    var renewals: [RenewalRecord] = []
    var schemaVersion = 1

    // MARK: Sync state

    /// Deletions this device has not pushed yet.
    var tombstones: [Tombstone] = []
    /// The server revision this device has already seen.
    var syncCursor: Int = 0
    /// Everything changed after this moment still has to go up.
    var lastPushedAt: Date?
    var lastSyncedAt: Date?
    /// Which account this ledger belongs to. Signing in as someone else must
    /// never merge one person's records into another person's device.
    var accountID: String?

    init() {}

    /// Written by hand so a ledger saved before syncing existed still opens:
    /// the new keys simply fall back to their defaults.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        vehicles = try container.decodeIfPresent([Vehicle].self, forKey: .vehicles) ?? []
        drivers = try container.decodeIfPresent([Driver].self, forKey: .drivers) ?? []
        fines = try container.decodeIfPresent([Fine].self, forKey: .fines) ?? []
        documents = try container.decodeIfPresent([DocumentItem].self, forKey: .documents) ?? []
        payments = try container.decodeIfPresent([PaymentRecord].self, forKey: .payments) ?? []
        renewals = try container.decodeIfPresent([RenewalRecord].self, forKey: .renewals) ?? []
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        tombstones = try container.decodeIfPresent([Tombstone].self, forKey: .tombstones) ?? []
        syncCursor = try container.decodeIfPresent(Int.self, forKey: .syncCursor) ?? 0
        lastPushedAt = try container.decodeIfPresent(Date.self, forKey: .lastPushedAt)
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        accountID = try container.decodeIfPresent(String.self, forKey: .accountID)
    }
}
