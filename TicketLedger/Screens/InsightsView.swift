//
//  InsightsView.swift
//  TicketLedger
//
//  Two figures matter most: what was lost only because dates were missed, and
//  what delay cost on top of the fines themselves.
//

import SwiftUI

struct InsightsView: View {
    @Environment(Store.self) private var store
    @State private var path = NavigationPath()
    @State private var now = Date()

    private var summary: InsightSummary {
        InsightSummary(store: store, now: now)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.page.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header

                        if store.closedCaseCount < 5 {
                            notEnoughYet
                        } else {
                            headlineNumbers
                            discountBlock
                            delayBlock
                            appealBlock
                            byLocation
                            byDriver
                            byType
                            documentsBlock
                        }

                        navigationBlock
                    }
                    .padding(.horizontal, Metric.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, Metric.contentBottomInset)
                }
                .refreshable { now = Date() }
            }
            .ledgerDestinations()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Insights").screenTitleStyle()
            Text("\(store.closedCaseCount) closed case(s) counted")
                .font(TypeScale.caption)
                .foregroundStyle(Theme.anchor.opacity(0.55))
        }
    }

    private var notEnoughYet: some View {
        EmptyState(
            title: "More Records Needed",
            message: "Close at least five cases to see where the money actually goes. \(store.closedCaseCount) of 5 so far — a paid fine, a cancelled one or a recorded renewal each count as one.",
            actionTitle: nil,
            action: nil
        )
    }

    // MARK: Headline

    private var headlineNumbers: some View {
        VStack(spacing: 14) {
            bigStat(
                title: "Discounts Lost",
                value: Fmt.money(summary.discountsLost, store.currency),
                caption: summary.discountsLost > 0
                    ? "Money that went only because a date passed. This is the figure the app exists for."
                    : "Nothing lost to a missed discount date. That is the whole point.",
                color: summary.discountsLost > 0 ? Theme.terracotta : Theme.green
            )
            bigStat(
                title: "Cost of Delay",
                value: Fmt.money(summary.costOfDelay, store.currency),
                caption: "Lost discounts plus enforcement costs you recorded — separate from the fines themselves.",
                color: summary.costOfDelay > 0 ? Theme.maroon : Theme.green
            )
        }
    }

    private func bigStat(title: String, value: String, caption: String, color: Color) -> some View {
        TokenCard(status: color) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .sectionTitleStyle()
                Text(value)
                    .font(TypeScale.number(52))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(caption)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.anchor.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Blocks

    private var discountBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Discounts")
            GoldRule()
            VStack(spacing: 0) {
                DetailRow(label: "Captured", value: Fmt.money(summary.discountsCaptured, store.currency), valueColor: Theme.green)
                DetailRow(label: "Lost", value: Fmt.money(summary.discountsLost, store.currency), valueColor: Theme.terracotta)
                DetailRow(label: "Caught in Time", value: "\(summary.discountsCapturedCount) of \(summary.discountOpportunities)")
            }
            if summary.discountOpportunities > 0 {
                CompareBar(
                    left: summary.discountsCaptured,
                    right: summary.discountsLost,
                    leftLabel: "Captured",
                    rightLabel: "Lost",
                    leftColor: Theme.green,
                    rightColor: Theme.terracotta
                )
            }
        }
    }

    private var delayBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Money")
            GoldRule()
            VStack(spacing: 0) {
                DetailRow(label: "Total Paid", value: Fmt.money(summary.totalPaid, store.currency))
                DetailRow(label: "Total Issued", value: Fmt.money(summary.totalIssued, store.currency))
                DetailRow(
                    label: "Overpaid",
                    value: Fmt.money(summary.overpaid, store.currency),
                    valueColor: summary.overpaid > 0 ? Theme.terracotta : nil
                )
                DetailRow(
                    label: "Enforcement",
                    value: summary.enforcementCostsKnown
                        ? Fmt.money(summary.enforcementCosts, store.currency)
                        : "Unknown amount added"
                )
            }
        }
    }

    private var appealBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Appeals")
            GoldRule()
            if summary.appealsTotal == 0 {
                Text("No appeal has been recorded yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.anchor.opacity(0.6))
            } else {
                VStack(spacing: 0) {
                    DetailRow(label: "Won", value: "\(summary.appealsWon)", valueColor: Theme.green)
                    DetailRow(label: "Lost", value: "\(summary.appealsLost)", valueColor: Theme.maroon)
                    DetailRow(label: "Waiting", value: "\(summary.appealsWaiting)")
                    if summary.appealsWon + summary.appealsLost > 0 {
                        DetailRow(
                            label: "Of Those Answered",
                            value: "\(Int((Double(summary.appealsWon) / Double(summary.appealsWon + summary.appealsLost) * 100).rounded()))% went your way"
                        )
                    }
                }
                CompareBar(
                    left: Double(summary.appealsWon),
                    right: Double(summary.appealsLost),
                    leftLabel: "Won",
                    rightLabel: "Lost",
                    leftColor: Theme.green,
                    rightColor: Theme.maroon
                )
            }
        }
    }

    private var byLocation: some View {
        let stats = store.locationStats().prefix(5)
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Fines by Location")
            GoldRule()
            if stats.isEmpty {
                Text("No locations recorded on your fines yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.anchor.opacity(0.6))
            } else {
                VStack(spacing: 8) {
                    ForEach(stats) { item in
                        RankBar(
                            label: item.display,
                            value: Double(item.count),
                            maxValue: Double(stats.first?.count ?? 1),
                            trailing: "\(item.count) · \(Fmt.money(item.totalPaid, store.currency))",
                            color: item.count >= 3 ? Theme.terracotta : Theme.goldDark
                        )
                    }
                }
                SecondaryButton("All Locations", icon: "mappin.and.ellipse") {
                    path.append(Route.locations)
                }
            }
        }
    }

    private var byDriver: some View {
        let items = summary.byDriver
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Fines by Driver")
            GoldRule()
            if items.isEmpty {
                Text("No fines have a driver recorded.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.anchor.opacity(0.6))
            } else {
                VStack(spacing: 8) {
                    ForEach(items, id: \.name) { item in
                        RankBar(
                            label: item.name,
                            value: item.amount,
                            maxValue: items.map(\.amount).max() ?? 1,
                            trailing: "\(item.count) · \(Fmt.money(item.amount, store.currency))",
                            color: Theme.goldDark
                        )
                    }
                }
            }
        }
    }

    private var byType: some View {
        let items = summary.byType
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Fines by Type")
            GoldRule()
            if items.isEmpty {
                Text("No descriptions recorded yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.anchor.opacity(0.6))
            } else {
                VStack(spacing: 8) {
                    ForEach(items, id: \.name) { item in
                        RankBar(
                            label: item.name,
                            value: item.amount,
                            maxValue: items.map(\.amount).max() ?? 1,
                            trailing: "\(item.count) · \(Fmt.money(item.amount, store.currency))",
                            color: Theme.gold
                        )
                    }
                }
            }
        }
    }

    private var documentsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Documents Renewed on Time")
            GoldRule()
            if store.renewals.isEmpty {
                Text("No renewals recorded yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.anchor.opacity(0.6))
            } else {
                VStack(spacing: 0) {
                    DetailRow(label: "On Time", value: "\(summary.renewalsOnTime)", valueColor: Theme.green)
                    DetailRow(label: "Late", value: "\(summary.renewalsLate)", valueColor: Theme.terracotta)
                    DetailRow(label: "Spent on Renewals", value: Fmt.money(summary.renewalSpend, store.currency))
                }
            }
        }
    }

    private var navigationBlock: some View {
        VStack(spacing: 10) {
            SecondaryButton("History", icon: "clock.arrow.circlepath") { path.append(Route.history) }
            SecondaryButton("Payments", icon: "creditcard") { path.append(Route.payments) }
            SecondaryButton("Repeat Spots", icon: "mappin.and.ellipse") { path.append(Route.locations) }
            SecondaryButton("Calendar", icon: "calendar") { path.append(Route.calendar) }
            SecondaryButton("Settings", icon: "gearshape") { path.append(Route.settings) }
        }
        .padding(.top, 4)
    }
}

// MARK: - Summary maths

struct InsightSummary {
    var totalPaid: Double = 0
    var totalIssued: Double = 0
    var overpaid: Double = 0
    var discountsCaptured: Double = 0
    var discountsLost: Double = 0
    var discountsCapturedCount = 0
    var discountOpportunities = 0
    var enforcementCosts: Double = 0
    var enforcementCostsKnown = false
    var appealsWon = 0
    var appealsLost = 0
    var appealsWaiting = 0
    var appealsTotal = 0
    var renewalsOnTime = 0
    var renewalsLate = 0
    var renewalSpend: Double = 0
    var byDriver: [(name: String, count: Int, amount: Double)] = []
    var byType: [(name: String, count: Int, amount: Double)] = []

    var costOfDelay: Double { discountsLost + enforcementCosts }

    @MainActor
    init(store: Store, now: Date) {
        let settings = store.data.settings

        for payment in store.data.payments {
            totalPaid += payment.amountPaid
            if let delta = payment.discrepancy, delta > 0 { overpaid += delta }
        }

        var driverTotals: [String: (Int, Double)] = [:]
        var typeTotals: [String: (Int, Double)] = [:]

        for fine in store.data.fines {
            totalIssued += fine.amount

            if let saving = fine.discountSaving {
                discountOpportunities += 1
                let deadline = DeadlineEngine.discountDeadline(for: fine, settings: settings)
                let paidInTime = store.data.payments
                    .filter { $0.target.fineID == fine.id }
                    .contains { payment in
                        guard let deadline else { return false }
                        return Fmt.days(from: payment.date, to: deadline) >= 0
                    }
                if paidInTime {
                    discountsCaptured += saving
                    discountsCapturedCount += 1
                } else if let deadline, Fmt.days(from: now, to: deadline) < 0 {
                    // The window shut. Only count it as lost once something was
                    // paid late, or the fine is closed — an open fine may still
                    // be argued down.
                    let paidLate = store.data.payments.contains { $0.target.fineID == fine.id }
                    if paidLate || fine.status == .paid {
                        discountsLost += saving
                    }
                }
            }

            if let extra = fine.enforcementExtraCost,
               DeadlineEngine.inEnforcement(for: fine, settings: settings, now: now) || fine.status == .paid {
                if DeadlineEngine.enforcementDate(for: fine, settings: settings)
                    .map({ Fmt.days(from: now, to: $0) < 0 }) == true {
                    enforcementCosts += extra
                    enforcementCostsKnown = true
                }
            }

            if let appeal = fine.appeal, appeal.isSubmitted {
                appealsTotal += 1
                switch appeal.outcome {
                case .some(let outcome) where outcome.isWin: appealsWon += 1
                case .some(.upheld): appealsLost += 1
                case .some(.withdrawn): appealsLost += 1
                default: appealsWaiting += 1
                }
            }

            let driverName = fine.driverNameSnapshot ?? "Not recorded"
            let driverEntry = driverTotals[driverName] ?? (0, 0)
            driverTotals[driverName] = (driverEntry.0 + 1, driverEntry.1 + fine.amount)

            let typeName = fine.titleLine
            let typeEntry = typeTotals[typeName] ?? (0, 0)
            typeTotals[typeName] = (typeEntry.0 + 1, typeEntry.1 + fine.amount)
        }

        for record in store.data.renewals {
            if record.onTime { renewalsOnTime += 1 } else { renewalsLate += 1 }
            renewalSpend += record.cost ?? 0
        }

        byDriver = driverTotals
            .map { (name: $0.key, count: $0.value.0, amount: $0.value.1) }
            .sorted { $0.amount > $1.amount }
            .prefix(5)
            .map { $0 }

        byType = typeTotals
            .map { (name: $0.key, count: $0.value.0, amount: $0.value.1) }
            .sorted { $0.amount > $1.amount }
            .prefix(5)
            .map { $0 }
    }
}

// MARK: - Bars

struct CompareBar: View {
    var left: Double
    var right: Double
    var leftLabel: String
    var rightLabel: String
    var leftColor: Color
    var rightColor: Color

    var body: some View {
        let total = max(left + right, 0.0001)
        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(leftColor)
                        .frame(width: max(0, geo.size.width * (left / total) - 1))
                    Rectangle()
                        .fill(rightColor)
                }
            }
            .frame(height: 12)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            HStack {
                label(leftLabel, color: leftColor)
                Spacer()
                label(rightLabel, color: rightColor)
            }
        }
        .padding(.top, 4)
    }

    private func label(_ text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(TypeScale.condensed(10, .bold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.anchor.opacity(0.5))
        }
    }
}

struct RankBar: View {
    var label: String
    var value: Double
    var maxValue: Double
    var trailing: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(TypeScale.condensed(13, .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.anchor)
                    .lineLimit(1)
                Spacer()
                Text(trailing)
                    .font(TypeScale.mono(11))
                    .foregroundStyle(Theme.anchor.opacity(0.55))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.anchor.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: max(4, geo.size.width * (maxValue > 0 ? value / maxValue : 0)))
                }
            }
            .frame(height: 10)
        }
    }
}
