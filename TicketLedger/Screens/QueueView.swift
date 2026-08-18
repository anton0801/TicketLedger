//
//  QueueView.swift
//  TicketLedger
//
//  The main screen. Not sorted by when the notice arrived — sorted by what
//  waiting costs. A vertical scale on the left carries the deadline marks.
//

import SwiftUI

struct QueueView: View {
    @Environment(Store.self) private var store
    @State private var showWhy = false
    @State private var showAddFine = false
    @State private var path = NavigationPath()
    /// Recomputed when the app returns to the foreground, so days left stay true.
    @State private var now = Date()

    private var obligations: [Obligation] { store.obligations(now: now) }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.page.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        if store.data.fines.isEmpty && store.data.documents.isEmpty {
                            EmptyState(
                                title: "The Queue Is Empty",
                                message: "Add a fine or a document with an expiry date. The queue then orders them by what each day of delay costs — not by the date they arrived.",
                                actionTitle: "Add a Fine",
                                action: { showAddFine = true }
                            )
                        } else if obligations.isEmpty {
                            nothingUrgent
                        } else {
                            queueBody
                        }

                        DeadlineDisclaimer()
                            .padding(.top, 6)
                    }
                    .padding(.horizontal, Metric.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, Metric.contentBottomInset)
                }
                .refreshable { now = Date() }
            }
            .ledgerDestinations()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showWhy) {
                WhyThisOrderView(obligations: obligations, now: now)
            }
            .sheet(isPresented: $showAddFine) {
                FineFormView(fine: nil)
            }
            .onChange(of: store.data.fines.count) { _, _ in now = Date() }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Queue").screenTitleStyle()
                    Text(headline)
                        .font(TypeScale.caption)
                        .foregroundStyle(Theme.anchor.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                HStack(spacing: 8) {
                    toolbarButton(icon: "calendar") { path.append(Route.calendar) }
                    toolbarButton(icon: "gearshape.fill") { path.append(Route.settings) }
                }
            }

            if !obligations.isEmpty {
                HStack(spacing: 10) {
                    Button {
                        showWhy = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 12, weight: .bold))
                            Text("Why This Order")
                                .font(TypeScale.condensed(13, .bold))
                                .tracking(1)
                                .textCase(.uppercase)
                        }
                        .foregroundStyle(Theme.goldDark)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Theme.gold.opacity(0.55), lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showAddFine = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .black))
                            Text("Add Fine")
                                .font(TypeScale.condensed(13, .black))
                                .tracking(1)
                                .textCase(.uppercase)
                        }
                        .foregroundStyle(Theme.anchor)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Theme.metal)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Theme.goldDark, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toolbarButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.goldDark)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.gold.opacity(0.5), lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }

    private var headline: String {
        let losing = obligations.filter { $0.severity == .losing }.count
        if losing > 0 {
            return "\(losing) already costing you · \(obligations.count) tracked"
        }
        if let next = obligations.first?.nextClock {
            return "Next deadline \(Fmt.relativeDays(next.daysLeft)) · \(obligations.count) tracked"
        }
        return "\(obligations.count) tracked"
    }

    // MARK: Nothing urgent

    private var nothingUrgent: some View {
        EmptyState(
            title: "Nothing Urgent",
            message: nothingUrgentMessage,
            actionTitle: nil,
            action: nil
        )
    }

    private var nothingUrgentMessage: String {
        if let next = store.nextDeadline(now: now) {
            return "Nothing loses money this week. Next deadline is in \(Fmt.dayCount(next.daysLeft))."
        }
        return "Nothing loses money this week, and nothing you have entered has a date ahead of it."
    }

    // MARK: Queue

    private var queueBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.element.title) { groupIndex, group in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text(group.title)
                            .font(TypeScale.condensed(12, .black))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundStyle(group.color)
                        GoldRule(opacity: 0.3)
                    }
                    .padding(.top, groupIndex == 0 ? 4 : 20)

                    // The scale runs behind the rows of this group.
                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(Theme.gold.opacity(0.35))
                            .frame(width: 2)
                            .padding(.leading, 26)
                            .padding(.vertical, 12)

                        VStack(spacing: 14) {
                            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                QueueRow(obligation: item, index: index) {
                                    open(item)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private struct Group {
        var title: String
        var color: Color
        var items: [Obligation]
    }

    private var groups: [Group] {
        var result: [Group] = []
        let losing = obligations.filter { $0.severity == .losing }
        if !losing.isEmpty {
            result.append(Group(title: "Already Losing", color: Theme.maroon, items: losing))
        }
        let pending = obligations.filter { $0.severity != .losing }
        for band in 0...3 {
            let items = pending.filter { $0.urgencyBand == band }
            guard !items.isEmpty else { continue }
            result.append(Group(
                title: DeadlineEngine.bandTitle(band),
                color: band == 0 ? Theme.terracotta : Theme.anchor.opacity(0.55),
                items: items
            ))
        }
        let noDate = pending.filter { $0.urgencyBand == 4 }
        if !noDate.isEmpty {
            result.append(Group(title: "No Date Set", color: Theme.anchor.opacity(0.55), items: noDate))
        }
        return result
    }

    private func open(_ obligation: Obligation) {
        switch obligation.kind {
        case .fine(let id): path.append(Route.fine(id))
        case .document(let id): path.append(Route.document(id))
        }
    }
}

// MARK: - One row of the queue

struct QueueRow: View {
    @Environment(Store.self) private var store
    var obligation: Obligation
    var index: Int
    var onOpen: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            scaleCell
                .frame(width: 54)

            Button(action: onOpen) {
                TokenCard(status: obligation.statusColor) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: obligation.icon)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Theme.goldDark)
                                    Text(obligation.title)
                                        .font(TypeScale.condensed(17, .black))
                                        .tracking(0.5)
                                        .textCase(.uppercase)
                                        .foregroundStyle(Theme.anchor)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                Text(obligation.subtitle)
                                    .font(TypeScale.mono(12))
                                    .textCase(.uppercase)
                                    .foregroundStyle(Theme.anchor.opacity(0.5))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            if let clock = obligation.nextClock {
                                RingGauge(
                                    progress: clock.isExpired ? 1 : clock.progress,
                                    value: "\(max(clock.daysLeft, 0))",
                                    label: clock.kind.title,
                                    caption: clock.daysLeft == 1 ? "day" : "days",
                                    tint: ringTint(clock),
                                    diameter: 74
                                )
                            } else if obligation.severity == .losing {
                                RingGauge(
                                    progress: 1,
                                    value: "\(obligation.daysOverdue)",
                                    label: "Overdue",
                                    caption: "days",
                                    tint: Theme.maroon,
                                    diameter: 74
                                )
                            }
                        }

                        if let now = obligation.amountNow {
                            HStack(alignment: .lastTextBaseline, spacing: 8) {
                                Text(Fmt.amount(now))
                                    .font(TypeScale.number(44))
                                    .foregroundStyle(Theme.anchor)
                                Text(Fmt.currencySymbol(store.currency))
                                    .font(TypeScale.condensed(17, .bold))
                                    .foregroundStyle(Theme.anchor.opacity(0.5))
                                    .padding(.bottom, 4)
                                Spacer()
                                if let after = obligation.amountAfter, after > now {
                                    VStack(alignment: .trailing, spacing: -2) {
                                        Text("then")
                                            .font(TypeScale.condensed(10, .bold))
                                            .tracking(1)
                                            .textCase(.uppercase)
                                            .foregroundStyle(Theme.anchor.opacity(0.45))
                                        Text(Fmt.amount(after))
                                            .font(TypeScale.number(24))
                                            .foregroundStyle(Theme.terracotta)
                                    }
                                } else if obligation.unknownExtraAfter {
                                    Text("plus unknown\nenforcement costs")
                                        .font(TypeScale.condensed(11, .bold))
                                        .textCase(.uppercase)
                                        .multilineTextAlignment(.trailing)
                                        .foregroundStyle(Theme.maroon)
                                }
                            }
                        }

                        if !obligation.stateLines.isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(Array(obligation.stateLines.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.anchor.opacity(0.72))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }

                        if let price = obligation.pricePerDay, price > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "hourglass")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Each day of delay: \(Fmt.money(price, store.currency))")
                                    .font(TypeScale.condensed(12, .bold))
                                    .tracking(0.5)
                                    .textCase(.uppercase)
                            }
                            .foregroundStyle(Theme.terracotta)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .tokenAppear(index)
    }

    private func ringTint(_ clock: Clock) -> Color? {
        switch clock.kind {
        case .discount: clock.daysLeft <= 2 ? Theme.terracotta : nil
        case .appeal: Theme.terracotta
        case .enforcement: Theme.maroon
        case .documentExpiry: clock.daysLeft <= 7 ? Theme.terracotta : nil
        case .appealAnswer: Theme.gold
        }
    }

    // MARK: Scale

    private var scaleCell: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 22)
            HStack(spacing: 0) {
                VStack(alignment: .trailing, spacing: -1) {
                    Text(scaleTop)
                        .font(TypeScale.condensed(13, .black))
                        .foregroundStyle(obligation.statusColor)
                    Text(scaleBottom)
                        .font(TypeScale.condensed(9, .bold))
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.anchor.opacity(0.4))
                }
                .frame(width: 34, alignment: .trailing)
                // Tick mark on the scale line.
                Rectangle()
                    .fill(obligation.statusColor)
                    .frame(width: 12, height: 2)
            }
            Spacer(minLength: 0)
        }
    }

    private var scaleTop: String {
        if let clock = obligation.nextClock { return Fmt.shortDate(clock.deadline) }
        if obligation.severity == .losing { return "PAST" }
        return "—"
    }

    private var scaleBottom: String {
        if let clock = obligation.nextClock {
            if clock.daysLeft == 0 { return "today" }
            return "d-\(clock.daysLeft)"
        }
        if obligation.severity == .losing { return "due" }
        return ""
    }
}

// MARK: - Why this order

struct WhyThisOrderView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var obligations: [Obligation]
    var now: Date

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.page.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("The queue is not sorted by date received, and not by size of the fine. It is sorted by what each day of waiting costs.")
                            .font(TypeScale.body)
                            .foregroundStyle(Theme.anchor.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)

                        FormBlock(title: "The rule") {
                            VStack(alignment: .leading, spacing: 12) {
                                rule(1, "Already losing", "Enforcement has started, or a document has expired. These come first whatever the amount.")
                                rule(2, "How soon", "Then by deadline band: within 2 days, this week, this month, later.")
                                rule(3, "How much per day", "Inside a band, by money that moves per day of delay — the amount at risk divided by the days left.")
                                rule(4, "Unknown amounts last", "When you have not entered what a delay adds, the item sits after the ones with a known figure in the same band. The app does not invent the number.")
                            }
                        }

                        FormBlock(title: "Your queue, with the numbers") {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(obligations.enumerated()), id: \.element.id) { index, item in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(alignment: .top, spacing: 10) {
                                            Text("\(index + 1)")
                                                .font(TypeScale.number(20))
                                                .foregroundStyle(Theme.goldDark)
                                                .frame(width: 28, alignment: .leading)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(item.title)
                                                    .font(TypeScale.condensed(15, .black))
                                                    .textCase(.uppercase)
                                                    .foregroundStyle(Theme.anchor)
                                                Text(explain(item))
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(Theme.anchor.opacity(0.7))
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                        if index < obligations.count - 1 {
                                            GoldRule(opacity: 0.25).padding(.vertical, 10)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(Metric.screenPadding)
                    .padding(.bottom, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Why This Order")
                        .font(TypeScale.condensed(19, .black))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.anchor)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(TypeScale.caption)
                        .foregroundStyle(Theme.goldDark)
                }
            }
            .toolbarBackground(Theme.page, for: .navigationBar)
        }
    }

    private func rule(_ number: Int, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(TypeScale.number(22))
                .foregroundStyle(Theme.goldDark)
                .frame(width: 26, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TypeScale.condensed(14, .black))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.anchor)
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.anchor.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func explain(_ item: Obligation) -> String {
        if item.severity == .losing {
            return "Already losing: \(Fmt.dayCount(item.daysOverdue)) past the date. Sorted above everything with a date still ahead."
        }
        guard let clock = item.nextClock else {
            return "No date entered, so nothing can be worked out. It sits at the bottom."
        }
        var parts: [String] = []
        parts.append("\(DeadlineEngine.bandTitle(item.urgencyBand).lowercased()): the \(clock.kind.sentenceName) ends \(Fmt.relativeDays(clock.daysLeft)), on \(Fmt.date(clock.deadline))")
        if let risk = clock.amountAtRisk, let price = item.pricePerDay {
            parts.append("\(Fmt.money(risk, store.currency)) at risk ÷ \(Fmt.dayCount(max(clock.daysLeft, 1))) = \(Fmt.money(price, store.currency)) a day")
        } else if clock.costsARight {
            parts.append("no fixed sum — what closes is the right to contest it")
        } else if clock.unknownCost {
            parts.append("costs are added but you have not entered how much, so no per-day figure can be shown")
        } else {
            parts.append("no amount attached to this date")
        }
        return parts.joined(separator: ". ") + "."
    }
}
