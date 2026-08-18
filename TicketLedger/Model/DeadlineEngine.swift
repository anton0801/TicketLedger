//
//  DeadlineEngine.swift
//  TicketLedger
//
//  The app does not count how much you owe. It counts dates: until when the
//  discount holds, when the appeal window shuts, when the debt goes to
//  enforcement — and orders them by what delay costs.
//
//  Every number here comes from dates and amounts the user entered. Nothing is
//  guessed, and an unknown cost stays unknown.
//

import SwiftUI

// MARK: - Clocks

enum ClockKind: String, Hashable {
    case discount, appeal, enforcement, documentExpiry, appealAnswer

    var title: String {
        switch self {
        case .discount: "Discount"
        case .appeal: "Appeal Window"
        case .enforcement: "Enforcement"
        case .documentExpiry: "Valid Until"
        case .appealAnswer: "Answer Due"
        }
    }

    /// Reads correctly mid-sentence: "the validity ends in 3 days".
    var sentenceName: String {
        switch self {
        case .discount: "discount"
        case .appeal: "appeal window"
        case .enforcement: "enforcement date"
        case .documentExpiry: "validity"
        case .appealAnswer: "answer date"
        }
    }
}

struct Clock: Identifiable, Hashable {
    var kind: ClockKind
    var deadline: Date
    var daysLeft: Int
    /// Length of the window in days, for the ring fill.
    var span: Int
    /// Money that changes on this date, when the user knows it.
    var amountAtRisk: Double?
    /// True when something is added whose size the user has not entered.
    var unknownCost: Bool = false
    /// The appeal window costs a right, not a fixed sum.
    var costsARight: Bool = false

    var id: ClockKind { kind }
    var isExpired: Bool { daysLeft < 0 }
    var isToday: Bool { daysLeft == 0 }

    /// Remaining fraction for the ring, 1 at the start of the window.
    var progress: Double {
        guard span > 0 else { return isExpired ? 0 : 1 }
        return max(0, min(1, Double(daysLeft) / Double(span)))
    }

    /// Money lost per day of delay, when it can be worked out.
    var pricePerDay: Double? {
        guard let amountAtRisk, amountAtRisk > 0, !isExpired else { return nil }
        return amountAtRisk / Double(max(daysLeft, 1))
    }
}

// MARK: - Obligation

enum ObligationKind: Hashable {
    case fine(UUID)
    case document(UUID)

    var fineID: UUID? { if case .fine(let id) = self { return id }; return nil }
    var documentID: UUID? { if case .document(let id) = self { return id }; return nil }
}

/// Severity band. The queue is built from these first, then from money.
enum Severity: Int, Comparable {
    /// Already costing: enforcement started, or a document has expired.
    case losing = 0
    /// A deadline is coming.
    case pending = 1
    /// Nothing to lose right now.
    case settled = 2

    static func < (l: Severity, r: Severity) -> Bool { l.rawValue < r.rawValue }
}

struct Obligation: Identifiable {
    var kind: ObligationKind
    var title: String
    var subtitle: String
    var plate: String
    var clocks: [Clock]
    var severity: Severity
    /// Amount due right now, as things stand today.
    var amountNow: Double?
    /// Amount after the next deadline passes.
    var amountAfter: Double?
    var unknownExtraAfter: Bool
    var statusColor: Color
    var icon: String
    /// Lines that explain the state in plain words.
    var stateLines: [String]
    var daysOverdue: Int

    var id: ObligationKind { kind }

    /// The nearest deadline still ahead.
    var nextClock: Clock? {
        clocks.filter { !$0.isExpired }.min { $0.daysLeft < $1.daysLeft }
    }

    var daysLeft: Int? { nextClock?.daysLeft }

    /// Highest known money-per-day among the live clocks.
    var pricePerDay: Double? {
        let values = clocks.compactMap(\.pricePerDay)
        return values.isEmpty ? nil : values.max()
    }

    /// 0–2 days, 3–7 days, 8–30 days, beyond.
    var urgencyBand: Int {
        guard let d = daysLeft else { return 4 }
        if d <= 2 { return 0 }
        if d <= 7 { return 1 }
        if d <= 30 { return 2 }
        return 3
    }

    var isFine: Bool { kind.fineID != nil }
}

// MARK: - Engine

enum DeadlineEngine {

    // MARK: Fine clocks

    static func rules(for fine: Fine, settings: AppSettings) -> DeadlineRules {
        fine.rulesOverride ?? settings.rules
    }

    static func discountDeadline(for fine: Fine, settings: AppSettings) -> Date? {
        guard fine.discountSaving != nil else { return nil }
        if let override = fine.discountDeadlineOverride { return Fmt.cal.startOfDay(for: override) }
        let r = rules(for: fine, settings: settings)
        guard r.discountWindowDays > 0 else { return nil }
        return Fmt.addDays(r.discountWindowDays, to: fine.dateReceived)
    }

    static func appealDeadline(for fine: Fine, settings: AppSettings) -> Date? {
        if let override = fine.appealDeadlineOverride { return Fmt.cal.startOfDay(for: override) }
        let r = rules(for: fine, settings: settings)
        guard r.appealWindowDays > 0 else { return nil }
        return Fmt.addDays(r.appealWindowDays, to: fine.dateReceived)
    }

    static func enforcementDate(for fine: Fine, settings: AppSettings) -> Date? {
        if let override = fine.enforcementDateOverride { return Fmt.cal.startOfDay(for: override) }
        let r = rules(for: fine, settings: settings)
        guard r.enforcementAfterDays > 0 else { return nil }
        return Fmt.addDays(r.enforcementAfterDays, to: fine.dateReceived)
    }

    /// All three clocks for a fine, plus the appeal answer clock when relevant.
    static func clocks(for fine: Fine, settings: AppSettings, now: Date = Date()) -> [Clock] {
        guard !fine.status.isClosed else { return [] }
        var result: [Clock] = []
        let r = rules(for: fine, settings: settings)

        if let deadline = discountDeadline(for: fine, settings: settings) {
            result.append(Clock(
                kind: .discount,
                deadline: deadline,
                daysLeft: Fmt.days(from: now, to: deadline),
                span: max(1, Fmt.days(from: fine.dateReceived, to: deadline)),
                amountAtRisk: fine.discountSaving
            ))
        }

        if let deadline = appealDeadline(for: fine, settings: settings), fine.appeal?.isSubmitted != true {
            result.append(Clock(
                kind: .appeal,
                deadline: deadline,
                daysLeft: Fmt.days(from: now, to: deadline),
                span: max(1, Fmt.days(from: fine.dateReceived, to: deadline)),
                amountAtRisk: nil,
                costsARight: true
            ))
        }

        if let deadline = enforcementDate(for: fine, settings: settings) {
            result.append(Clock(
                kind: .enforcement,
                deadline: deadline,
                daysLeft: Fmt.days(from: now, to: deadline),
                span: max(1, r.enforcementAfterDays),
                amountAtRisk: fine.enforcementExtraCost,
                unknownCost: fine.enforcementExtraCost == nil
            ))
        }

        if let appeal = fine.appeal, appeal.isSubmitted, appeal.answerReceived == nil,
           let expected = appeal.expectedAnswerBy {
            result.append(Clock(
                kind: .appealAnswer,
                deadline: Fmt.cal.startOfDay(for: expected),
                daysLeft: Fmt.days(from: now, to: expected),
                span: max(1, Fmt.days(from: appeal.submittedOn ?? now, to: expected)),
                amountAtRisk: nil
            ))
        }

        return result
    }

    /// What the fine costs today, given which windows are still open.
    static func amountToday(for fine: Fine, settings: AppSettings, now: Date = Date()) -> Double {
        if let saving = fine.discountSaving,
           let deadline = discountDeadline(for: fine, settings: settings),
           Fmt.days(from: now, to: deadline) >= 0 {
            return fine.amount - saving
        }
        return fine.amount
    }

    static func discountIsRunning(for fine: Fine, settings: AppSettings, now: Date = Date()) -> Bool {
        guard !fine.status.isClosed, fine.discountSaving != nil,
              let deadline = discountDeadline(for: fine, settings: settings) else { return false }
        return Fmt.days(from: now, to: deadline) >= 0
    }

    static func appealWindowIsOpen(for fine: Fine, settings: AppSettings, now: Date = Date()) -> Bool {
        guard !fine.status.isClosed, fine.appeal?.isSubmitted != true,
              let deadline = appealDeadline(for: fine, settings: settings) else { return false }
        return Fmt.days(from: now, to: deadline) >= 0
    }

    static func inEnforcement(for fine: Fine, settings: AppSettings, now: Date = Date()) -> Bool {
        guard !fine.status.isClosed, let deadline = enforcementDate(for: fine, settings: settings) else { return false }
        return Fmt.days(from: now, to: deadline) < 0
    }

    /// Discount that was available and is now gone, with nothing paid in time.
    static func discountWasLost(for fine: Fine, settings: AppSettings, now: Date = Date()) -> Double? {
        guard let saving = fine.discountSaving,
              let deadline = discountDeadline(for: fine, settings: settings),
              Fmt.days(from: now, to: deadline) < 0 else { return nil }
        return saving
    }

    static func buckets(for fine: Fine, settings: AppSettings, now: Date = Date()) -> Set<FineBucket> {
        var set: Set<FineBucket> = []
        switch fine.status {
        case .paid: set.insert(.paid)
        case .cancelled: set.insert(.cancelled)
        case .underAppeal: set.insert(.underAppeal)
        case .open: set.insert(.open)
        }
        if !fine.status.isClosed {
            if discountIsRunning(for: fine, settings: settings, now: now) { set.insert(.discountRunning) }
            if appealWindowIsOpen(for: fine, settings: settings, now: now) { set.insert(.appealWindowOpen) }
            if inEnforcement(for: fine, settings: settings, now: now) { set.insert(.enforcement) }
        }
        return set
    }

    // MARK: Document clocks

    static func clock(for document: DocumentItem, now: Date = Date()) -> Clock {
        let deadline = Fmt.cal.startOfDay(for: document.validUntil)
        // A yearly document would leave the ring almost full until the last week,
        // so the ring counts down over its final 90 days instead of the whole term.
        let span: Int = {
            let full: Int
            if let from = document.validFrom {
                full = max(1, Fmt.days(from: from, to: deadline))
            } else {
                full = max(1, document.reminderDays ?? 30)
            }
            return min(full, 90)
        }()
        return Clock(
            kind: .documentExpiry,
            deadline: deadline,
            daysLeft: Fmt.days(from: now, to: deadline),
            span: span,
            amountAtRisk: nil,
            unknownCost: false
        )
    }

    // MARK: Building obligations

    static func obligation(
        for fine: Fine,
        settings: AppSettings,
        now: Date = Date()
    ) -> Obligation? {
        guard !fine.status.isClosed else { return nil }
        let clocks = clocks(for: fine, settings: settings, now: now)
        let enforcementActive = inEnforcement(for: fine, settings: settings, now: now)
        let today = amountToday(for: fine, settings: settings, now: now)

        let severity: Severity = enforcementActive ? .losing : (clocks.contains { !$0.isExpired } ? .pending : .losing)

        var next = clocks.filter { !$0.isExpired }.min { $0.daysLeft < $1.daysLeft }
        if enforcementActive { next = nil }

        var after: Double? = nil
        var unknownExtra = false
        if let next {
            switch next.kind {
            case .discount:
                after = fine.amount
            case .enforcement:
                after = fine.amount
                unknownExtra = fine.enforcementExtraCost == nil
                if let extra = fine.enforcementExtraCost { after = fine.amount + extra }
            case .appeal, .appealAnswer, .documentExpiry:
                after = nil
            }
        } else if enforcementActive {
            unknownExtra = fine.enforcementExtraCost == nil
            after = fine.enforcementExtraCost.map { fine.amount + $0 }
        }

        let color: Color = {
            if enforcementActive { return Theme.maroon }
            if let next, next.daysLeft <= 3 { return Theme.terracotta }
            if fine.status == .underAppeal { return Theme.gold }
            return Theme.goldDark
        }()

        let overdue: Int = {
            guard enforcementActive, let d = enforcementDate(for: fine, settings: settings) else { return 0 }
            return -Fmt.days(from: now, to: d)
        }()

        return Obligation(
            kind: .fine(fine.id),
            title: fine.titleLine,
            subtitle: fine.noticeNumber.isEmpty ? "No notice number" : fine.noticeNumber,
            plate: fine.vehiclePlateSnapshot,
            clocks: clocks,
            severity: severity,
            amountNow: today,
            amountAfter: after,
            unknownExtraAfter: unknownExtra,
            statusColor: color,
            icon: fine.status == .underAppeal ? "scalemass.fill" : "doc.text.fill",
            stateLines: stateLines(for: fine, settings: settings, now: now),
            daysOverdue: overdue
        )
    }

    static func obligation(
        for document: DocumentItem,
        subject: String,
        settings: AppSettings,
        now: Date = Date()
    ) -> Obligation {
        let clock = clock(for: document, now: now)
        let expired = clock.isExpired
        let severity: Severity = expired ? .losing : .pending
        let color: Color = {
            if expired { return document.type.expiryIsSerious ? Theme.maroon : Theme.terracotta }
            if clock.daysLeft <= 7 { return Theme.terracotta }
            return Theme.goldDark
        }()

        var lines: [String] = []
        if expired {
            lines.append("Expired \(Fmt.dayCount(-clock.daysLeft)) ago, on \(Fmt.date(clock.deadline)).")
            if document.type.expiryIsSerious {
                lines.append("Driving on an expired \(document.type.title.lowercased()) is usually the expensive kind of late.")
            }
        } else if clock.daysLeft == 0 {
            lines.append("Valid until today, \(Fmt.date(clock.deadline)).")
        } else {
            lines.append("Valid for \(Fmt.dayCount(clock.daysLeft)) more, until \(Fmt.date(clock.deadline)).")
        }
        if let cost = document.cost, cost > 0 {
            lines.append("Last renewal cost \(Fmt.money(cost, settings.currencyCode)).")
        }

        return Obligation(
            kind: .document(document.id),
            title: document.type.title,
            subtitle: subject,
            plate: subject,
            clocks: [clock],
            severity: severity,
            amountNow: nil,
            amountAfter: nil,
            unknownExtraAfter: false,
            statusColor: color,
            icon: document.type.icon,
            stateLines: lines,
            daysOverdue: expired ? -clock.daysLeft : 0
        )
    }

    /// The plain sentences shown under a fine token.
    static func stateLines(for fine: Fine, settings: AppSettings, now: Date = Date()) -> [String] {
        var lines: [String] = []
        let code = settings.currencyCode
        let clocks = clocks(for: fine, settings: settings, now: now)

        if let discount = clocks.first(where: { $0.kind == .discount }),
           let discounted = fine.discountedAmount {
            if discount.isExpired {
                lines.append("The discount ran out on \(Fmt.date(discount.deadline)). It is \(Fmt.money(fine.amount, code)) now — \(Fmt.money(fine.amount - discounted, code)) more than it was.")
            } else if discount.isToday {
                lines.append("Today is the last day at \(Fmt.money(discounted, code)). Tomorrow it is \(Fmt.money(fine.amount, code)).")
            } else {
                lines.append("Pay within \(Fmt.dayCount(discount.daysLeft)) and it stays \(Fmt.money(discounted, code)). After that it is \(Fmt.money(fine.amount, code)).")
            }
        }

        if let appeal = clocks.first(where: { $0.kind == .appeal }) {
            if appeal.isExpired {
                lines.append("Appeal window closed on \(Fmt.date(appeal.deadline)). Only payment remains.")
            } else if appeal.isToday {
                lines.append("Appeal window closes today. After that only payment remains.")
            } else {
                lines.append("Appeal window closes in \(Fmt.dayCount(appeal.daysLeft)). After that only payment remains.")
            }
        } else if let appeal = fine.appeal, appeal.isSubmitted {
            lines.append("Appeal sent on \(Fmt.date(appeal.submittedOn ?? now)) by \(appeal.method.title.lowercased()).")
        }

        if let enforcement = clocks.first(where: { $0.kind == .enforcement }) {
            let costPart = fine.enforcementExtraCost.map { "Costs of \(Fmt.money($0, code)) are added on top." }
                ?? "Costs are added on top — you have not entered how much."
            if enforcement.isExpired {
                lines.append("Enforcement started \(Fmt.dayCount(-enforcement.daysLeft)) ago. \(costPart)")
            } else {
                lines.append("Enforcement in \(Fmt.dayCount(enforcement.daysLeft)). \(costPart)")
            }
        }

        if let answer = clocks.first(where: { $0.kind == .appealAnswer }) {
            if answer.isExpired {
                lines.append("The answer was due \(Fmt.dayCount(-answer.daysLeft)) ago and has not arrived.")
            } else {
                lines.append("An answer is expected within \(Fmt.dayCount(answer.daysLeft)).")
            }
        }

        return lines
    }

    // MARK: The queue

    /// Ordered by what delay costs: first what is already losing money, then by
    /// how soon in bands, and inside a band by money moved per day of delay.
    static func sort(_ items: [Obligation]) -> [Obligation] {
        items.sorted { a, b in
            if a.severity != b.severity { return a.severity < b.severity }
            if a.severity == .losing {
                if a.daysOverdue != b.daysOverdue { return a.daysOverdue > b.daysOverdue }
                return (a.amountNow ?? 0) > (b.amountNow ?? 0)
            }
            if a.urgencyBand != b.urgencyBand { return a.urgencyBand < b.urgencyBand }
            let pa = a.pricePerDay ?? -1
            let pb = b.pricePerDay ?? -1
            if abs(pa - pb) > 0.001 { return pa > pb }
            let da = a.daysLeft ?? Int.max
            let db = b.daysLeft ?? Int.max
            if da != db { return da < db }
            return a.title < b.title
        }
    }

    static func bandTitle(_ band: Int) -> String {
        switch band {
        case 0: "Within 2 days"
        case 1: "This week"
        case 2: "This month"
        default: "Later"
        }
    }
}
