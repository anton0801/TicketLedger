//
//  PayOrAppealView.swift
//  TicketLedger
//
//  The dark screen. It helps decide without deciding, and it states the trap
//  people learn too late: in many places appealing costs you the discount.
//

import SwiftUI

struct PayOrAppealView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var fineID: UUID

    @State private var grounds: Set<AppealGround> = []
    @State private var reason = ""
    @State private var showGroundsError = false
    @State private var appeared = false
    @State private var saving = false
    @State private var now = Date()

    private var fine: Fine? { store.fine(fineID) }

    var body: some View {
        ZStack {
            // The motif never leaves a block, so the dark page itself stays plain;
            // inside the tokens the guilloche is brighter than on the cream screens.
            Theme.anchor.ignoresSafeArea()

            if let fine {
                content(fine)
                    .opacity(appeared ? 1 : 0)
            } else {
                EmptyState(
                    title: "This Fine Is Gone",
                    message: "The record was removed while this screen was open.",
                    actionTitle: "Close",
                    action: { dismiss() }
                )
                .padding(Metric.screenPadding)
            }
        }
        .onAppear {
            // 0.4s fade into the dark screen.
            withAnimation(Springs.darkFade) { appeared = true }
            if let fine {
                grounds = Set(fine.grounds)
                reason = fine.decision?.reason ?? ""
            }
        }
    }

    private func content(_ fine: Fine) -> some View {
        VStack(spacing: 0) {
            header(fine)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    columns(fine)
                    localRuleWarning
                    groundsBlock(fine)
                    evidenceBlock(fine)
                    reasonBlock
                    buttons(fine)
                    DeadlineDisclaimer(dark: true)
                }
                .padding(.horizontal, Metric.screenPadding)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: Header

    private func header(_ fine: Fine) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pay or Appeal").screenTitleStyle(dark: true)
                    Text(fine.noticeNumber.isEmpty ? "NO NUMBER" : fine.noticeNumber)
                        .font(TypeScale.mono(13))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.gold)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.page.opacity(0.7))
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Theme.gold.opacity(0.4), lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Metric.screenPadding)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    // MARK: Two columns

    private func columns(_ fine: Fine) -> some View {
        let code = store.currency
        let today = DeadlineEngine.amountToday(for: fine, settings: store.data.settings, now: now)
        let appealClock = DeadlineEngine.clocks(for: fine, settings: store.data.settings, now: now)
            .first { $0.kind == .appeal }
        let discountClock = DeadlineEngine.clocks(for: fine, settings: store.data.settings, now: now)
            .first { $0.kind == .discount }

        return HStack(alignment: .top, spacing: 12) {
            // Pay
            TokenCard(status: Theme.green, dark: true, showsHoles: false) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Pay")
                        .font(TypeScale.condensed(20, .black))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.page)
                    HStack(alignment: .lastTextBaseline, spacing: 5) {
                        Text(Fmt.amount(today))
                            .font(TypeScale.number(38))
                            .foregroundStyle(Theme.page)
                        Text(Fmt.currencySymbol(code))
                            .font(TypeScale.condensed(13, .bold))
                            .foregroundStyle(Theme.page.opacity(0.5))
                    }
                    GoldRule(opacity: 0.3)
                    if let discountClock, !discountClock.isExpired {
                        darkLine("This price holds", "\(Fmt.dayCount(discountClock.daysLeft)), until \(Fmt.date(discountClock.deadline))")
                        darkLine("After that", Fmt.money(fine.amount, code))
                    } else {
                        darkLine("This price holds", "no reduction is running on this notice")
                    }
                    darkLine("Closes", "finally, with a receipt to keep")
                }
            }

            // Appeal
            TokenCard(status: Theme.gold, dark: true, showsHoles: false) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Appeal")
                        .font(TypeScale.condensed(20, .black))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.page)
                    HStack(alignment: .lastTextBaseline, spacing: 5) {
                        Text(appealClock.map { $0.isExpired ? "0" : "\($0.daysLeft)" } ?? "—")
                            .font(TypeScale.number(38))
                            .foregroundStyle(appealClock?.isExpired == false ? Theme.page : Theme.terracotta)
                        Text(appealClock?.isExpired == false ? "days left" : "closed")
                            .font(TypeScale.condensed(13, .bold))
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.page.opacity(0.5))
                    }
                    GoldRule(opacity: 0.3)
                    if let saving = fine.discountSaving, discountClock?.isExpired == false {
                        darkLine("At stake", "the \(Fmt.money(saving, code)) reduction, if the appeal fails")
                    } else {
                        darkLine("At stake", "the full \(Fmt.money(fine.amount, code)), if the appeal fails")
                    }
                    darkLine("Grounds marked", grounds.isEmpty ? "none yet" : "\(grounds.count)")
                    darkLine("Evidence", fine.evidence.isEmpty ? "nothing collected" : "\(fine.evidence.count) item(s)")
                }
            }
        }
    }

    private func darkLine(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(TypeScale.condensed(10, .bold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.gold.opacity(0.8))
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Theme.page.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: The mechanic people learn late

    private var localRuleWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.terracotta)
            Text("In many places, appealing means losing the discount. If the appeal fails you pay the full amount. This app does not know your local rule — check it before you decide.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.page.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.terracotta.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.terracotta.opacity(0.5), lineWidth: 2)
        )
    }

    // MARK: Grounds

    private func groundsBlock(_ fine: Fine) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Grounds", dark: true)
            GoldRule(opacity: 0.4)
            Text("Pick what applies. The app records them and never rates how strong they are.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.page.opacity(0.6))

            FlowChips(
                items: AppealGround.allCases,
                selected: grounds,
                title: { $0.title },
                dark: true
            ) { ground in
                if grounds.contains(ground) { grounds.remove(ground) } else { grounds.insert(ground) }
                showGroundsError = false
                persistGrounds(fine)
            }

            if showGroundsError {
                Text("Mark at least one ground before recording an appeal decision.")
                    .font(TypeScale.caption)
                    .foregroundStyle(Theme.terracotta)
            }
        }
    }

    // MARK: Evidence hints

    @ViewBuilder
    private func evidenceBlock(_ fine: Fine) -> some View {
        let hints = grounds.compactMap(\.evidenceHint)
        let missing = missingEvidenceTypes(fine)
        if !hints.isEmpty || !missing.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("What Is Usually Needed", dark: true)
                GoldRule(opacity: 0.4)
                ForEach(hints, id: \.self) { hint in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.gold)
                            .padding(.top, 2)
                        Text(hint)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.page.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !missing.isEmpty {
                    Text("Not collected yet: \(missing.map(\.title).joined(separator: ", ")).")
                        .font(TypeScale.caption)
                        .foregroundStyle(Theme.terracotta)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func missingEvidenceTypes(_ fine: Fine) -> [EvidenceType] {
        let held = Set(fine.evidence.map(\.type))
        var wanted: [EvidenceType] = []
        for ground in grounds {
            for type in ground.usualEvidence where !held.contains(type) && !wanted.contains(type) {
                wanted.append(type)
            }
        }
        return wanted
    }

    // MARK: Reason

    private var reasonBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Why", dark: true)
            GoldRule(opacity: 0.4)
            LedgerTextArea(
                label: "Reason for this decision",
                text: $reason,
                hint: "Saved with the date. In six months this is what tells you why you chose it.",
                dark: true
            )
        }
    }

    // MARK: Buttons

    private func buttons(_ fine: Fine) -> some View {
        VStack(spacing: 10) {
            MetalButton("Mark for Payment", icon: "creditcard.fill", enabled: !saving) {
                record(.payment, on: fine)
            }
            Button {
                guard !grounds.isEmpty else { showGroundsError = true; return }
                record(.appeal, on: fine)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "scalemass.fill").font(.system(size: 15, weight: .bold))
                    Text("Mark for Appeal")
                        .font(TypeScale.condensed(16, .black))
                        .tracking(1)
                        .textCase(.uppercase)
                }
                .foregroundStyle(Theme.gold)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: Metric.buttonRadius, style: .continuous)
                        .strokeBorder(Theme.gold, lineWidth: 2.5)
                )
            }
            .buttonStyle(.plain)

            Button("Decide Later") {
                record(.later, on: fine)
            }
            .font(TypeScale.condensed(15, .bold))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(Theme.page.opacity(0.6))
            .frame(height: 44)
        }
    }

    // MARK: Saving

    private func persistGrounds(_ fine: Fine) {
        var copy = fine
        copy.grounds = Array(grounds)
        store.upsert(copy)
    }

    private func record(_ kind: DecisionKind, on fine: Fine) {
        guard !saving else { return }
        saving = true
        var copy = fine
        copy.grounds = Array(grounds)
        copy.decision = Decision(
            kind: kind,
            date: Date(),
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        if kind == .appeal, copy.status == .open {
            copy.status = .underAppeal
        }
        if kind == .payment, copy.status == .underAppeal {
            copy.status = .open
        }
        store.upsert(copy)
        dismiss()
    }
}

// MARK: - Wrapping chip group

struct FlowChips<Item: Hashable>: View {
    var items: [Item]
    var selected: Set<Item>
    var title: (Item) -> String
    var dark: Bool = false
    var onTap: (Item) -> Void

    var body: some View {
        // Two-column flow keeps long ground names readable.
        let columns = [GridItem(.adaptive(minimum: 150), spacing: 8)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let isOn = selected.contains(item)
                Button {
                    onTap(item)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 12, weight: .bold))
                        Text(title(item))
                            .font(TypeScale.condensed(13, isOn ? .black : .bold))
                            .tracking(0.5)
                            .textCase(.uppercase)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(isOn ? Theme.anchor : (dark ? Theme.gold : Theme.goldDark))
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: Metric.chipHeight)
                    .background(
                        Group {
                            if isOn {
                                RoundedRectangle(cornerRadius: Metric.buttonRadius, style: .continuous)
                                    .fill(Theme.metal)
                            } else {
                                RoundedRectangle(cornerRadius: Metric.buttonRadius, style: .continuous)
                                    .strokeBorder(Theme.gold.opacity(0.4), lineWidth: 2)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
