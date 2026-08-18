//
//  NotificationScheduler.swift
//  TicketLedger
//
//  Local reminders only. The discount reminder fires three times — a week out,
//  three days out, and on the last day — because the last day is when people
//  pay, and the other two are so there is still a choice.
//

import Foundation
import UserNotifications

@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler()
    private init() {}

    private let center = UNUserNotificationCenter.current()
    /// Reminders fire at 9am local time on the day they are due.
    private let hour = 9

    func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { continuation.resume(returning: $0.authorizationStatus) }
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    /// Rebuilt from scratch on every data change — simpler and always accurate.
    func reschedule(with data: LedgerData) {
        guard data.settings.notificationsEnabled else {
            cancelAll()
            return
        }
        let prefs = data.settings.notificationPrefs
        let currency = data.settings.currencyCode
        cancelAll()

        var requests: [UNNotificationRequest] = []
        let now = Date()

        for fine in data.fines where !fine.status.isClosed {
            let plate = fine.vehiclePlateSnapshot.isEmpty ? "your vehicle" : fine.vehiclePlateSnapshot.uppercased()

            if prefs.discountEnding,
               let deadline = DeadlineEngine.discountDeadline(for: fine, settings: data.settings),
               let discounted = fine.discountedAmount {
                for offset in [7, 3, 0] {
                    let fireDay = Fmt.addDays(-offset, to: deadline)
                    let title = offset == 0 ? "Discount ends today" : "Discount ends in \(Fmt.dayCount(offset))"
                    let body = "\(plate) · \(fine.noticeNumber): \(Fmt.money(discounted, currency)) until \(Fmt.date(deadline)), then \(Fmt.money(fine.amount, currency))."
                    if let request = request(id: "discount-\(fine.id)-\(offset)", title: title, body: body, on: fireDay, after: now) {
                        requests.append(request)
                    }
                }
            }

            if prefs.appealWindowClosing,
               fine.appeal?.isSubmitted != true,
               let deadline = DeadlineEngine.appealDeadline(for: fine, settings: data.settings) {
                for offset in [3, 0] {
                    let fireDay = Fmt.addDays(-offset, to: deadline)
                    let title = offset == 0 ? "Appeal window closes today" : "Appeal window closing"
                    let body = "\(plate) · \(fine.noticeNumber): after \(Fmt.date(deadline)) only payment remains."
                    if let request = request(id: "appeal-\(fine.id)-\(offset)", title: title, body: body, on: fireDay, after: now) {
                        requests.append(request)
                    }
                }
            }

            if prefs.enforcementApproaching,
               let deadline = DeadlineEngine.enforcementDate(for: fine, settings: data.settings) {
                for offset in [7, 1] {
                    let fireDay = Fmt.addDays(-offset, to: deadline)
                    let costPart = fine.enforcementExtraCost
                        .map { "Costs of \(Fmt.money($0, currency)) are added on top." }
                        ?? "Costs are added on top."
                    let body = "\(plate) · \(fine.noticeNumber) goes to enforcement on \(Fmt.date(deadline)). \(costPart)"
                    if let request = request(id: "enforce-\(fine.id)-\(offset)", title: "Enforcement approaching", body: body, on: fireDay, after: now) {
                        requests.append(request)
                    }
                }
            }

            if prefs.appealAnswerOverdue,
               let appeal = fine.appeal, appeal.isSubmitted, appeal.answerReceived == nil,
               let expected = appeal.expectedAnswerBy {
                let fireDay = Fmt.addDays(1, to: expected)
                let body = "No answer yet on \(fine.noticeNumber). It was expected by \(Fmt.date(expected)). A reminder to them is your next step."
                if let request = request(id: "answer-\(fine.id)", title: "Appeal answer overdue", body: body, on: fireDay, after: now) {
                    requests.append(request)
                }
            }

            if prefs.paymentNotRecorded, fine.decision?.kind == .payment {
                let paid = data.payments.contains { $0.target.fineID == fine.id }
                if !paid, let decided = fine.decision?.date {
                    let fireDay = Fmt.addDays(3, to: decided)
                    let body = "You marked \(fine.noticeNumber) for payment on \(Fmt.date(decided)) and no payment is recorded yet."
                    if let request = request(id: "unrecorded-\(fine.id)", title: "Payment not recorded", body: body, on: fireDay, after: now) {
                        requests.append(request)
                    }
                }
            }
        }

        if prefs.documentExpiring {
            for document in data.documents {
                let subject: String = {
                    if let vehicle = data.vehicles.first(where: { $0.id == document.vehicleID }) {
                        return vehicle.plate.isEmpty ? vehicle.makeModel : vehicle.plate.uppercased()
                    }
                    if let driver = data.drivers.first(where: { $0.id == document.personID }) {
                        return driver.name
                    }
                    return "Your record"
                }()
                let lead = document.reminderDays ?? 30
                for offset in Set([lead, 7, 1]).sorted(by: >) {
                    let fireDay = Fmt.addDays(-offset, to: document.validUntil)
                    let body = "\(subject): \(document.type.title) is valid until \(Fmt.date(document.validUntil))."
                    if let request = request(id: "doc-\(document.id)-\(offset)", title: "Document expiring", body: body, on: fireDay, after: now) {
                        requests.append(request)
                    }
                }
            }
        }

        for request in requests {
            center.add(request)
        }
    }

    private func request(id: String, title: String, body: String, on day: Date, after now: Date) -> UNNotificationRequest? {
        var components = Fmt.cal.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        guard let fireDate = Fmt.cal.date(from: components), fireDate > now else { return nil }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Fmt.cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false
        )
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    func pendingCount() async -> Int {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { continuation.resume(returning: $0.count) }
        }
    }
}
