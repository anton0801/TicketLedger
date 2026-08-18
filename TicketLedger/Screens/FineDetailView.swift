//
//  FineDetailView.swift
//  TicketLedger
//
//  Three clocks, and the money scale under them. Everything shown here is
//  counted from dates and amounts the user entered.
//

import SwiftUI

struct FineDetailView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var fineID: UUID

    @State private var showEdit = false
    @State private var showDecision = false
    @State private var showPayment = false
    @State private var showEvidence = false
    @State private var showAppeal = false
    @State private var showDeleteConfirm = false
    @State private var paidSheen: CGFloat = 0
    @State private var now = Date()

    private var fine: Fine? { store.fine(fineID) }

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()

            if let fine {
                content(fine)
            } else {
                // The record was deleted while this screen was open.
                VStack(spacing: 16) {
                    EmptyState(
                        title: "This Fine Is Gone",
                        message: "The record was removed. Nothing else was changed.",
                        actionTitle: "Back to the list",
                        action: { dismiss() }
                    )
                }
                .padding(Metric.screenPadding)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if fine != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showEdit = true
                        } label: {
                            Label("Edit Fine", systemImage: "square.and.pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Fine", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.goldDark)
                    }
                }
            }
        }
        .toolbarBackground(Theme.page, for: .navigationBar)
        .sheet(isPresented: $showEdit) {
            if let fine { FineFormView(fine: fine) }
        }
        .fullScreenCover(isPresented: $showDecision) {
            if let fine { PayOrAppealView(fineID: fine.id) }
        }
        .sheet(isPresented: $showPayment) {
            if let fine { PaymentFormView(fine: fine, payment: nil) }
        }
        .sheet(isPresented: $showEvidence) {
            if let fine { EvidenceView(fineID: fine.id) }
        }
        .sheet(isPresented: $showAppeal) {
            if let fine { AppealTrackingView(fineID: fine.id) }
        }
        .alert("Delete this fine?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let fine { store.deleteFine(fine) }
                dismiss()
            }
        } message: {
            Text("The notice, its evidence, its appeal record and its payments go with it. This cannot be undone.")
        }
    }

    // MARK: Content

    private func content(_ fine: Fine) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerBlock(fine)
                clocksBlock(fine)
                moneyScale(fine)
                warnings(fine)
                actions(fine)
                decisionBlock(fine)
                detailsBlock(fine)
                evidenceSummary(fine)
                appealSummary(fine)
                paymentsBlock(fine)
                DeadlineDisclaimer()
            }
            .padding(.horizontal, Metric.screenPadding)
            .padding(.bottom, Metric.contentBottomInset)
        }
        .refreshable { now = Date() }
    }

    // MARK: Header

    private func headerBlock(_ fine: Fine) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(fine.titleLine).screenTitleStyle()
                    Text(fine.noticeNumber.isEmpty ? "NO NUMBER" : fine.noticeNumber)
                        .monoStyle(15)
                        .foregroundStyle(Theme.goldDark)
                }
                Spacer()
                StatusBadge(fine: fine, now: now)
            }

            HStack(spacing: 10) {
                if !fine.vehiclePlateSnapshot.isEmpty {
                    metaChip(icon: "car.fill", text: fine.vehiclePlateSnapshot.uppercased(), mono: true)
                }
                if let driver = fine.driverNameSnapshot, !driver.isEmpty {
                    metaChip(icon: "person.fill", text: driver, mono: false)
                }
            }

            if fine.noticePhotoName != nil {
                StoredImageView(name: fine.noticePhotoName, height: 160)
            }
        }
        .padding(.top, 4)
    }

    private func metaChip(icon: String, text: String, mono: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
            Text(text)
                .font(mono ? TypeScale.mono(12) : TypeScale.condensed(13, .bold))
                .textCase(.uppercase)
        }
        .foregroundStyle(Theme.anchor.opacity(0.6))
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.gold.opacity(0.45), lineWidth: 1.5)
        )
    }

    // MARK: Three clocks

    private func clocksBlock(_ fine: Fine) -> some View {
        let clocks = DeadlineEngine.clocks(for: fine, settings: store.data.settings, now: now)
        let discount = clocks.first { $0.kind == .discount }
        let appeal = clocks.first { $0.kind == .appeal }
        let enforcement = clocks.first { $0.kind == .enforcement }
        let answer = clocks.first { $0.kind == .appealAnswer }

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Three Clocks")
            GoldRule()

            if fine.status.isClosed {
                HStack(spacing: 14) {
                    PaidStamp(text: fine.status == .paid ? "PAID" : "CLOSED")
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fine.status == .paid ? "Settled" : "No longer running")
                            .font(TypeScale.condensed(16, .black))
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.anchor)
                        if let closed = fine.closedAt {
                            Text("Closed on \(Fmt.date(closed))")
                                .font(TypeScale.caption)
                                .foregroundStyle(Theme.anchor.opacity(0.55))
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                HStack(alignment: .top, spacing: 8) {
                    clockRing(
                        clock: discount,
                        label: "Discount",
                        emptyLabel: "No discount",
                        // An expired discount turns terracotta — the money is gone.
                        expired: .filled(Theme.terracotta, "lost")
                    )
                    clockRing(
                        clock: appeal,
                        label: "Appeal",
                        emptyLabel: fine.appeal?.isSubmitted == true ? "Sent" : "Closed",
                        // A closed appeal window goes dark and is replaced by the line below.
                        expired: .dimmed("closed")
                    )
                    clockRing(
                        clock: enforcement,
                        label: "Enforcement",
                        emptyLabel: "Not set",
                        expired: .filled(Theme.maroon, "running")
                    )
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    if let discount {
                        clockNote(discount, fine: fine)
                    } else if fine.discountSaving == nil {
                        Text("No discounted amount was entered for this notice, so there is no discount clock.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.anchor.opacity(0.6))
                    }
                    if let appeal {
                        clockNote(appeal, fine: fine)
                    } else if fine.appeal?.isSubmitted == true {
                        Text("Appeal window closed — the appeal was sent on \(Fmt.date(fine.appeal?.submittedOn ?? now)).")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.anchor.opacity(0.6))
                    } else {
                        Text("Appeal window closed.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.terracotta)
                    }
                    if let enforcement { clockNote(enforcement, fine: fine) }
                    if let answer { clockNote(answer, fine: fine) }
                }
            }
        }
    }

    /// How a ring looks once its date has passed.
    private enum ExpiredStyle {
        case dimmed(String)
        case filled(Color, String)
    }

    private func clockRing(clock: Clock?, label: String, emptyLabel: String, expired: ExpiredStyle) -> some View {
        Group {
            if let clock, clock.isExpired {
                switch expired {
                case .dimmed(let caption):
                    RingGauge(
                        progress: 0,
                        value: "—",
                        label: label,
                        caption: caption,
                        tint: nil,
                        diameter: 100,
                        dimmed: true
                    )
                case .filled(let color, let caption):
                    RingGauge(
                        progress: 1,
                        value: "0",
                        label: label,
                        caption: caption,
                        tint: color,
                        diameter: 100
                    )
                }
            } else if let clock {
                RingGauge(
                    progress: clock.progress,
                    value: "\(clock.daysLeft)",
                    label: label,
                    caption: clock.daysLeft == 1 ? "day" : "days",
                    tint: ringTint(clock),
                    diameter: 100
                )
            } else {
                RingGauge(
                    progress: 0,
                    value: "—",
                    label: label,
                    caption: emptyLabel.lowercased(),
                    tint: nil,
                    diameter: 100,
                    dimmed: true
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func ringTint(_ clock: Clock) -> Color? {
        switch clock.kind {
        case .enforcement:
            // Fills with maroon as it gets close.
            return clock.daysLeft <= 14 ? Theme.maroon : nil
        case .appeal:
            return clock.daysLeft <= 3 ? Theme.terracotta : nil
        case .discount:
            return clock.daysLeft <= 2 ? Theme.terracotta : nil
        default:
            return nil
        }
    }

    private func clockNote(_ clock: Clock, fine: Fine) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(clock.isExpired ? Theme.terracotta : Theme.goldDark)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(clock.kind.title)
                    .font(TypeScale.condensed(12, .black))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.anchor.opacity(0.5))
                Text(noteText(clock, fine: fine))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.anchor.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func noteText(_ clock: Clock, fine: Fine) -> String {
        let code = store.currency
        switch clock.kind {
        case .discount:
            if clock.isExpired {
                let lost = fine.discountSaving.map { Fmt.money($0, code) } ?? "the reduction"
                return "Ran out on \(Fmt.date(clock.deadline)). \(lost) was lost by waiting."
            }
            let saving = fine.discountSaving.map { Fmt.money($0, code) } ?? "the reduction"
            return "\(Fmt.dayCount(clock.daysLeft)) left to keep \(saving). Last day is \(Fmt.date(clock.deadline))."
        case .appeal:
            if clock.isExpired { return "Closed on \(Fmt.date(clock.deadline)). Only payment remains." }
            return "\(Fmt.dayCount(clock.daysLeft)) left to contest it, until \(Fmt.date(clock.deadline)). After that only payment remains."
        case .enforcement:
            let costPart = fine.enforcementExtraCost.map { "Costs of \(Fmt.money($0, code)) are added." }
                ?? "Unknown amount added — you have not entered the figure."
            if clock.isExpired {
                return "Started \(Fmt.dayCount(-clock.daysLeft)) ago, on \(Fmt.date(clock.deadline)). \(costPart)"
            }
            return "\(Fmt.dayCount(clock.daysLeft)) until \(Fmt.date(clock.deadline)). \(costPart)"
        case .appealAnswer:
            if clock.isExpired {
                return "An answer was due on \(Fmt.date(clock.deadline)) and has not arrived. A reminder is your next step."
            }
            return "An answer is expected by \(Fmt.date(clock.deadline))."
        case .documentExpiry:
            return Fmt.date(clock.deadline)
        }
    }

    // MARK: Money scale

    private func moneyScale(_ fine: Fine) -> some View {
        let code = store.currency
        let today = DeadlineEngine.amountToday(for: fine, settings: store.data.settings, now: now)
        let discount = DeadlineEngine.discountDeadline(for: fine, settings: store.data.settings)
        let enforcement = DeadlineEngine.enforcementDate(for: fine, settings: store.data.settings)

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("What It Costs")
            GoldRule()

            VStack(spacing: 0) {
                scaleRow(
                    label: "Today",
                    value: Fmt.money(today, code),
                    color: today < fine.amount ? Theme.green : Theme.anchor,
                    big: true
                )
                if let discount, Fmt.days(from: now, to: discount) >= 0, fine.discountSaving != nil {
                    GoldRule(opacity: 0.2)
                    scaleRow(
                        label: "After \(Fmt.date(discount))",
                        value: Fmt.money(fine.amount, code),
                        color: Theme.terracotta,
                        big: false
                    )
                }
                if let enforcement {
                    GoldRule(opacity: 0.2)
                    scaleRow(
                        label: "After \(Fmt.date(enforcement))",
                        value: fine.enforcementExtraCost
                            .map { Fmt.money(fine.amount + $0, code) }
                            ?? Fmt.money(fine.amount, code),
                        color: Theme.maroon,
                        big: false,
                        note: fine.enforcementExtraCost == nil ? "plus unknown amount added" : nil
                    )
                }
            }
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.gold.opacity(0.4), lineWidth: 2)
            )

            if fine.enforcementExtraCost == nil {
                Text("The app never invents the size of enforcement costs. Add the figure from your notice to see it here.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.anchor.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func scaleRow(label: String, value: String, color: Color, big: Bool, note: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(TypeScale.condensed(13, .bold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.anchor.opacity(0.55))
            Spacer(minLength: 10)
            VStack(alignment: .trailing, spacing: 1) {
                Text(value)
                    .font(big ? TypeScale.number(34) : TypeScale.number(22))
                    .foregroundStyle(color)
                if let note {
                    Text(note)
                        .font(TypeScale.condensed(11, .bold))
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundStyle(color.opacity(0.8))
                }
            }
        }
        .padding(.vertical, big ? 12 : 10)
    }

    // MARK: Warnings

    private func warnings(_ fine: Fine) -> some View {
        VStack(spacing: 10) {
            if store.isAfterSale(fine) {
                WarningLine(
                    text: "This fine is dated after you sold the car. That is usually a reason to appeal, not to pay.",
                    color: Theme.maroon
                )
            }
            if let other = store.duplicateNotice(fine.noticeNumber, excluding: fine.id) {
                WarningLine(
                    text: "Another record carries the same notice number, dated \(Fmt.date(other.dateOfOffence)). A duplicate notice is itself a ground for appeal.",
                    color: Theme.terracotta
                )
            }
            if fine.driverID == nil, store.requiresDriver(for: fine.vehicleID) {
                WarningLine(
                    text: "More than one person drives this car and the driver is not recorded. Who was driving changes what you can argue.",
                    color: Theme.terracotta
                )
            }
        }
    }

    // MARK: Actions

    private func actions(_ fine: Fine) -> some View {
        VStack(spacing: 10) {
            if !fine.status.isClosed {
                MetalButton("Pay or Appeal", icon: "arrow.triangle.branch") { showDecision = true }
                HStack(spacing: 10) {
                    SecondaryButton("Record Payment", icon: "creditcard") { showPayment = true }
                    SecondaryButton(
                        fine.evidence.isEmpty ? "Evidence" : "Evidence · \(fine.evidence.count)",
                        icon: "paperclip"
                    ) { showEvidence = true }
                }
                SecondaryButton(
                    fine.appeal?.isSubmitted == true ? "Appeal Tracking" : "Start Appeal Record",
                    icon: "scalemass"
                ) { showAppeal = true }
            } else {
                HStack(spacing: 10) {
                    SecondaryButton(
                        fine.evidence.isEmpty ? "Evidence" : "Evidence · \(fine.evidence.count)",
                        icon: "paperclip"
                    ) { showEvidence = true }
                    SecondaryButton("Reopen", icon: "arrow.uturn.backward") {
                        var copy = fine
                        copy.status = .open
                        copy.closedAt = nil
                        store.upsert(copy)
                    }
                }
            }
        }
    }

    // MARK: Decision

    @ViewBuilder
    private func decisionBlock(_ fine: Fine) -> some View {
        if let decision = fine.decision {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("Decision")
                GoldRule()
                TokenCard(status: decision.kind == .appeal ? Theme.gold : Theme.green, showsHoles: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(decision.kind.title)
                            .font(TypeScale.condensed(16, .black))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.anchor)
                        Text("On \(Fmt.date(decision.date))")
                            .font(TypeScale.caption)
                            .foregroundStyle(Theme.anchor.opacity(0.55))
                        if !decision.reason.isEmpty {
                            Text(decision.reason)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.anchor.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    // MARK: Details

    private func detailsBlock(_ fine: Fine) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("The Record")
            GoldRule()
            VStack(spacing: 0) {
                DetailRow(label: "Date of Offence", value: Fmt.date(fine.dateOfOffence))
                DetailRow(label: "Date Received", value: Fmt.date(fine.dateReceived))
                DetailRow(label: "Amount", value: Fmt.money(fine.amount, store.currency))
                if let discounted = fine.discountedAmount {
                    DetailRow(label: "Discounted", value: Fmt.money(discounted, store.currency))
                }
                if !fine.article.isEmpty {
                    DetailRow(label: "Article", value: fine.article, mono: true)
                }
                if !fine.location.isEmpty {
                    DetailRow(label: "Location", value: fine.location)
                }
                if !fine.issuingAuthority.isEmpty {
                    DetailRow(label: "Authority", value: fine.issuingAuthority)
                }
                DetailRow(
                    label: "Vehicle",
                    value: fine.vehiclePlateSnapshot.isEmpty ? "Not recorded" : "\(fine.vehiclePlateSnapshot.uppercased()) \(fine.vehicleModelSnapshot)",
                    mono: true
                )
                DetailRow(label: "Driver", value: fine.driverNameSnapshot ?? "Not recorded")
                if let rules = fine.rulesOverride {
                    DetailRow(
                        label: "Windows",
                        value: "\(rules.discountWindowDays)/\(rules.appealWindowDays)/\(rules.enforcementAfterDays) days, set for this notice"
                    )
                }
                if !fine.notes.isEmpty {
                    DetailRow(label: "Notes", value: fine.notes)
                }
            }
        }
    }

    // MARK: Evidence & appeal summaries

    @ViewBuilder
    private func evidenceSummary(_ fine: Fine) -> some View {
        if !fine.evidence.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("Evidence", trailing: "\(fine.evidence.count)")
                GoldRule()
                VStack(spacing: 0) {
                    ForEach(fine.evidence) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.type.icon)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.goldDark)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.type.title)
                                    .font(TypeScale.condensed(14, .bold))
                                    .textCase(.uppercase)
                                    .foregroundStyle(Theme.anchor)
                                if !item.description.isEmpty {
                                    Text(item.description)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.anchor.opacity(0.7))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer()
                            if item.fileName != nil {
                                Image(systemName: "paperclip")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.green)
                            }
                        }
                        .padding(.vertical, 9)
                        if item.id != fine.evidence.last?.id { GoldRule(opacity: 0.2) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func appealSummary(_ fine: Fine) -> some View {
        if let appeal = fine.appeal, appeal.isSubmitted {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("Appeal")
                GoldRule()
                VStack(spacing: 0) {
                    DetailRow(label: "Submitted", value: Fmt.date(appeal.submittedOn ?? Date()))
                    DetailRow(label: "Method", value: appeal.method.title)
                    if !appeal.referenceNumber.isEmpty {
                        DetailRow(label: "Reference", value: appeal.referenceNumber, mono: true)
                    }
                    if let expected = appeal.expectedAnswerBy {
                        DetailRow(label: "Answer By", value: Fmt.date(expected))
                    }
                    if !appeal.remindersSent.isEmpty {
                        DetailRow(label: "Reminders", value: appeal.remindersSent.map(Fmt.shortDate).joined(separator: ", "))
                    }
                    if let outcome = appeal.outcome {
                        DetailRow(label: "Outcome", value: outcome.title, valueColor: outcome.color)
                    }
                    if !appeal.nextStep.isEmpty {
                        DetailRow(label: "Next Step", value: appeal.nextStep)
                    }
                }
            }
        }
    }

    // MARK: Payments

    @ViewBuilder
    private func paymentsBlock(_ fine: Fine) -> some View {
        let payments = store.payments(forFine: fine.id)
        if !payments.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("Payments", trailing: Fmt.money(payments.reduce(0) { $0 + $1.amountPaid }, store.currency))
                GoldRule()
                VStack(spacing: 12) {
                    ForEach(payments) { payment in
                        PaymentRow(payment: payment)
                    }
                }
            }
        }
    }
}

// MARK: - Status badge

struct StatusBadge: View {
    @Environment(Store.self) private var store
    var fine: Fine
    var now: Date

    var body: some View {
        let text: String
        let color: Color
        if fine.status.isClosed {
            text = fine.status.title
            color = fine.status == .paid ? Theme.green : Theme.anchor.opacity(0.5)
        } else if DeadlineEngine.inEnforcement(for: fine, settings: store.data.settings, now: now) {
            text = "Enforcement"
            color = Theme.maroon
        } else if fine.status == .underAppeal {
            text = "Under Appeal"
            color = Theme.gold
        } else if DeadlineEngine.discountIsRunning(for: fine, settings: store.data.settings, now: now) {
            text = "Discount"
            color = Theme.green
        } else {
            text = "Open"
            color = Theme.goldDark
        }

        return Text(text)
            .font(TypeScale.condensed(12, .black))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(color.opacity(0.5), lineWidth: 1.5)
            )
    }
}
