//
//  HistoryView.swift
//  TicketLedger
//
//  Closed cases, kept whole: dates, decisions, evidence, outcome, amounts.
//  Read-only — history is not edited after the fact.
//

import SwiftUI

struct HistoryView: View {
    @Environment(Store.self) private var store

    @State private var search = ""
    @State private var vehicleFilter: UUID?
    @State private var driverFilter: UUID?
    @State private var outcomeFilter: HistoryOutcome?
    @State private var openCase: Fine?

    enum HistoryOutcome: String, CaseIterable, Identifiable {
        case paid, cancelled, appealWon, appealLost
        var id: String { rawValue }
        var title: String {
            switch self {
            case .paid: "Paid"
            case .cancelled: "Cancelled"
            case .appealWon: "Appeal Won"
            case .appealLost: "Appeal Lost"
            }
        }
    }

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("History").screenTitleStyle()
                        Text("\(store.closedFines.count) closed fine(s) · \(store.renewals.count) renewal(s)")
                            .font(TypeScale.caption)
                            .foregroundStyle(Theme.anchor.opacity(0.55))
                    }

                    if store.closedFines.isEmpty && store.renewals.isEmpty {
                        EmptyState(
                            title: "Nothing Closed Yet",
                            message: "Paid, cancelled and renewed records land here in full — with the decision, the evidence and the outcome kept.",
                            actionTitle: nil,
                            action: nil
                        )
                    } else {
                        searchField
                        filters

                        if filtered.isEmpty && store.renewals.isEmpty {
                            EmptyState(
                                title: "No Matches",
                                message: "Nothing in history matches these filters.",
                                actionTitle: "Clear Filters",
                                action: clearFilters
                            )
                        } else {
                            if !filtered.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionHeader("Closed Fines", trailing: "\(filtered.count)")
                                    GoldRule()
                                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, fine in
                                        Button {
                                            openCase = fine
                                        } label: {
                                            HistoryToken(fine: fine)
                                        }
                                        .buttonStyle(.plain)
                                        .tokenAppear(index)
                                    }
                                }
                            }

                            if !store.renewals.isEmpty && vehicleFilter == nil && driverFilter == nil && outcomeFilter == nil {
                                renewalsBlock
                            }
                        }
                    }
                }
                .padding(.horizontal, Metric.screenPadding)
                .padding(.bottom, Metric.contentBottomInset)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.page, for: .navigationBar)
        .sheet(item: $openCase) { fine in
            HistoryCaseView(fine: fine)
        }
    }

    // MARK: Filters

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.anchor.opacity(0.4))
            TextField("Search closed cases", text: $search)
                .font(TypeScale.body)
                .tint(Theme.goldDark)
                .autocorrectionDisabled()
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.anchor.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.card))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.gold.opacity(0.45), lineWidth: 1.5)
        )
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(title: "All Outcomes", selected: outcomeFilter == nil, count: nil) { outcomeFilter = nil }
                    ForEach(HistoryOutcome.allCases) { outcome in
                        Chip(title: outcome.title, selected: outcomeFilter == outcome, count: nil) {
                            outcomeFilter = outcomeFilter == outcome ? nil : outcome
                        }
                    }
                }
            }
            if !store.vehicles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Chip(title: "All Vehicles", selected: vehicleFilter == nil, count: nil) { vehicleFilter = nil }
                        ForEach(store.vehicles) { vehicle in
                            Chip(title: vehicle.plate.uppercased(), selected: vehicleFilter == vehicle.id, count: nil) {
                                vehicleFilter = vehicleFilter == vehicle.id ? nil : vehicle.id
                            }
                        }
                    }
                }
            }
            if store.drivers.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Chip(title: "All Drivers", selected: driverFilter == nil, count: nil) { driverFilter = nil }
                        ForEach(store.drivers) { driver in
                            Chip(title: driver.name, selected: driverFilter == driver.id, count: nil) {
                                driverFilter = driverFilter == driver.id ? nil : driver.id
                            }
                        }
                    }
                }
            }
        }
    }

    private func clearFilters() {
        search = ""
        vehicleFilter = nil
        driverFilter = nil
        outcomeFilter = nil
    }

    private var filtered: [Fine] {
        var list = store.closedFines
        if let vehicleFilter { list = list.filter { $0.vehicleID == vehicleFilter } }
        if let driverFilter { list = list.filter { $0.driverID == driverFilter } }
        if let outcomeFilter {
            list = list.filter { fine in
                switch outcomeFilter {
                case .paid: return fine.status == .paid
                case .cancelled: return fine.status == .cancelled
                case .appealWon: return fine.appeal?.outcome?.isWin == true
                case .appealLost: return fine.appeal?.outcome == .upheld
                }
            }
        }
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.noticeNumber.lowercased().contains(query)
                || $0.vehiclePlateSnapshot.lowercased().contains(query)
                || $0.location.lowercased().contains(query)
                || $0.details.lowercased().contains(query)
                || ($0.driverNameSnapshot ?? "").lowercased().contains(query)
            }
        }
        return list
    }

    private var renewalsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Renewals", trailing: "\(store.renewals.count)")
            GoldRule()
            VStack(spacing: 0) {
                ForEach(store.renewals) { record in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(record.typeSnapshot.title) · \(record.subjectSnapshot)")
                                .font(TypeScale.condensed(14, .bold))
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.anchor)
                            Text("Renewed \(Fmt.date(record.renewedOn)) · valid to \(Fmt.date(record.newValidUntil))")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.anchor.opacity(0.55))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            if let cost = record.cost {
                                Text(Fmt.money(cost, store.currency))
                                    .font(TypeScale.number(16))
                                    .foregroundStyle(Theme.anchor.opacity(0.7))
                            }
                            Text(record.onTime ? "On time" : "Late")
                                .font(TypeScale.condensed(10, .black))
                                .tracking(1)
                                .textCase(.uppercase)
                                .foregroundStyle(record.onTime ? Theme.green : Theme.terracotta)
                        }
                    }
                    .padding(.vertical, 10)
                    if record.id != store.renewals.last?.id { GoldRule(opacity: 0.2) }
                }
            }
        }
    }
}

// MARK: - Token

struct HistoryToken: View {
    @Environment(Store.self) private var store
    var fine: Fine

    var body: some View {
        TokenCard(status: fine.status == .paid ? Theme.green : Theme.anchor.opacity(0.35)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(fine.titleLine)
                            .font(TypeScale.condensed(16, .black))
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.anchor)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text("\(fine.noticeNumber) · \(fine.vehiclePlateSnapshot.uppercased())")
                            .font(TypeScale.mono(11))
                            .foregroundStyle(Theme.anchor.opacity(0.5))
                            .lineLimit(1)
                    }
                    Spacer()
                    PaidStamp(text: fine.status == .paid ? "PAID" : "CLOSED")
                        .scaleEffect(0.55)
                        .frame(width: 96, height: 40)
                }
                HStack {
                    Text(Fmt.money(store.totalPaid(forFine: fine.id), store.currency))
                        .font(TypeScale.number(22))
                        .foregroundStyle(Theme.anchor.opacity(0.75))
                    Spacer()
                    if let closed = fine.closedAt {
                        Text(Fmt.date(closed))
                            .font(TypeScale.condensed(12, .bold))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.anchor.opacity(0.45))
                    }
                }
                if let outcome = fine.appeal?.outcome {
                    Text("Appeal: \(outcome.title.lowercased())")
                        .font(TypeScale.caption)
                        .foregroundStyle(outcome.color)
                }
            }
        }
    }
}

// MARK: - Case view (read only)

struct HistoryCaseView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var fine: Fine

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.page.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Read-only record. History is kept as it was closed.")
                            .font(TypeScale.caption)
                            .foregroundStyle(Theme.anchor.opacity(0.5))

                        VStack(alignment: .leading, spacing: 6) {
                            Text(fine.titleLine).screenTitleStyle()
                            Text(fine.noticeNumber).monoStyle().foregroundStyle(Theme.goldDark)
                        }

                        block("The Case") {
                            DetailRow(label: "Status", value: fine.status.title)
                            DetailRow(label: "Vehicle", value: "\(fine.vehiclePlateSnapshot.uppercased()) \(fine.vehicleModelSnapshot)", mono: true)
                            DetailRow(label: "Driver", value: fine.driverNameSnapshot ?? "Not recorded")
                            DetailRow(label: "Offence", value: Fmt.date(fine.dateOfOffence))
                            DetailRow(label: "Received", value: Fmt.date(fine.dateReceived))
                            if let closed = fine.closedAt {
                                DetailRow(label: "Closed", value: Fmt.date(closed))
                            }
                            DetailRow(label: "Amount", value: Fmt.money(fine.amount, store.currency))
                            if let discounted = fine.discountedAmount {
                                DetailRow(label: "Discounted", value: Fmt.money(discounted, store.currency))
                            }
                            if !fine.location.isEmpty {
                                DetailRow(label: "Location", value: fine.location)
                            }
                        }

                        if let decision = fine.decision {
                            block("Decision") {
                                DetailRow(label: "What", value: decision.kind.title)
                                DetailRow(label: "When", value: Fmt.date(decision.date))
                                if !decision.reason.isEmpty {
                                    DetailRow(label: "Why", value: decision.reason)
                                }
                            }
                        }

                        if !fine.grounds.isEmpty {
                            block("Grounds") {
                                ForEach(fine.grounds) { ground in
                                    DetailRow(label: "Ground", value: ground.title)
                                }
                            }
                        }

                        if let appeal = fine.appeal, appeal.isSubmitted {
                            block("Appeal") {
                                DetailRow(label: "Submitted", value: Fmt.date(appeal.submittedOn ?? Date()))
                                DetailRow(label: "Method", value: appeal.method.title)
                                if !appeal.referenceNumber.isEmpty {
                                    DetailRow(label: "Reference", value: appeal.referenceNumber, mono: true)
                                }
                                if let received = appeal.answerReceived {
                                    DetailRow(label: "Answered", value: Fmt.date(received))
                                }
                                if let outcome = appeal.outcome {
                                    DetailRow(label: "Outcome", value: outcome.title, valueColor: outcome.color)
                                }
                                if !appeal.remindersSent.isEmpty {
                                    DetailRow(label: "Reminders", value: appeal.remindersSent.map(Fmt.shortDate).joined(separator: ", "))
                                }
                            }
                        }

                        if !fine.evidence.isEmpty {
                            block("Evidence") {
                                ForEach(fine.evidence) { item in
                                    VStack(alignment: .leading, spacing: 6) {
                                        DetailRow(label: item.type.title, value: item.description.isEmpty ? "No description" : item.description)
                                        if item.fileName != nil {
                                            StoredImageView(name: item.fileName, height: 140)
                                        }
                                    }
                                }
                            }
                        }

                        let payments = store.payments(forFine: fine.id)
                        if !payments.isEmpty {
                            block("Payments") {
                                ForEach(payments) { payment in
                                    PaymentRow(payment: payment)
                                }
                            }
                        }

                        if !fine.notes.isEmpty {
                            block("Notes") {
                                Text(fine.notes)
                                    .font(TypeScale.body)
                                    .foregroundStyle(Theme.anchor.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(Metric.screenPadding)
                    .padding(.bottom, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Open Case")
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

    @ViewBuilder
    private func block<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title)
            GoldRule()
            VStack(alignment: .leading, spacing: 0) { content() }
        }
    }
}
