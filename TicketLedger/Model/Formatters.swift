//
//  Formatters.swift
//  TicketLedger
//

import Foundation

enum Fmt {
    static let cal = Calendar.current

    // MARK: Money

    static func money(_ value: Double, _ code: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        f.maximumFractionDigits = value.rounded() == value ? 0 : 2
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    /// Bare number for the big condensed figures, where the currency sits beside it.
    static func amount(_ value: Double) -> String {
        value.rounded() == value
            ? String(format: "%.0f", value)
            : String(format: "%.2f", value)
    }

    static func currencySymbol(_ code: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        return f.currencySymbol ?? code
    }

    // MARK: Dates

    static func date(_ d: Date) -> String {
        d.formatted(.dateTime.day().month(.abbreviated).year())
    }

    static func shortDate(_ d: Date) -> String {
        d.formatted(.dateTime.day().month(.abbreviated))
    }

    static func dayMonth(_ d: Date) -> String {
        d.formatted(.dateTime.day().month(.wide))
    }

    static func monthYear(_ d: Date) -> String {
        d.formatted(.dateTime.month(.wide).year())
    }

    /// Whole days from today to the given date. Negative when it has passed.
    static func days(from now: Date, to then: Date) -> Int {
        let a = cal.startOfDay(for: now)
        let b = cal.startOfDay(for: then)
        return cal.dateComponents([.day], from: a, to: b).day ?? 0
    }

    static func addDays(_ days: Int, to date: Date) -> Date {
        cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: date)) ?? date
    }

    static func dayCount(_ n: Int) -> String {
        n == 1 ? "1 day" : "\(n) days"
    }

    /// "in 6 days", "today", "3 days ago"
    static func relativeDays(_ n: Int) -> String {
        if n == 0 { return "today" }
        if n > 0 { return "in \(dayCount(n))" }
        return "\(dayCount(-n)) ago"
    }
}
