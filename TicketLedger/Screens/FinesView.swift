//
//  FinesView.swift
//  TicketLedger
//

import SwiftUI

struct FinesView: View {
    @Environment(Store.self) private var store
    @State private var path = NavigationPath()
    @State private var bucket: FineBucket? = nil
    @State private var search = ""
    @State private var showAdd = false
    @State private var showScan = false
    @State private var now = Date()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.page.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        addRow
                        searchField
                        bucketChips

                        if store.data.fines.isEmpty {
                            EmptyState(
                                title: "No Fines Yet",
                                message: "Photograph a notice or type it in. The app then works out the three deadlines and where it belongs in the queue.",
                                actionTitle: "Add by Hand",
                                action: { showAdd = true }
                            )
                        } else if filtered.isEmpty {
                            EmptyState(
                                title: "Nothing Here",
                                message: emptyFilterMessage,
                                actionTitle: "Clear Filters",
                                action: { bucket = nil; search = "" }
                            )
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(Array(filtered.enumerated()), id: \.element.id) { index, fine in
                                    FineToken(fine: fine, now: now) {
                                        path.append(Route.fine(fine.id))
                                    }
                                    .tokenAppear(index)
                                }
                            }
                        }

                        DeadlineDisclaimer().padding(.top, 4)
                    }
                    .padding(.horizontal, Metric.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, Metric.contentBottomInset)
                }
                .refreshable { now = Date() }
            }
            .ledgerDestinations()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAdd) { FineFormView(fine: nil) }
            .sheet(isPresented: $showScan) { ScanNoticeView() }
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Fines").screenTitleStyle()
                Text("\(store.data.fines.count) recorded · \(store.data.fines.filter { !$0.status.isClosed }.count) open")
                    .font(TypeScale.caption)
                    .foregroundStyle(Theme.anchor.opacity(0.55))
            }
            Spacer()
            Button {
                path.append(Route.payments)
            } label: {
                Image(systemName: "creditcard.fill")
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
    }

    private var addRow: some View {
        HStack(spacing: 10) {
            MetalButton("Scan Notice", icon: "camera.viewfinder") { showScan = true }
            SecondaryButton("Add by Hand", icon: "square.and.pencil") { showAdd = true }
        }
        .frame(height: Metric.buttonHeight)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.anchor.opacity(0.4))
            TextField("Notice number, plate, place", text: $search)
                .font(TypeScale.body)
                .tint(Theme.goldDark)
                .autocorrectionDisabled()
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.anchor.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.gold.opacity(0.45), lineWidth: 1.5)
        )
    }

    private var bucketChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "All", selected: bucket == nil, count: store.data.fines.count) {
                    bucket = nil
                }
                ForEach(FineBucket.allCases) { item in
                    let count = count(for: item)
                    Chip(title: item.title, selected: bucket == item, count: count) {
                        bucket = bucket == item ? nil : item
                    }
                    .opacity(count == 0 && bucket != item ? 0.5 : 1)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var emptyFilterMessage: String {
        if let bucket {
            return "No fines are in \"\(bucket.title)\" right now."
        }
        return "Nothing matches \"\(search)\"."
    }

    // MARK: Filtering

    private func count(for item: FineBucket) -> Int {
        store.data.fines.filter {
            DeadlineEngine.buckets(for: $0, settings: store.data.settings, now: now).contains(item)
        }.count
    }

    private var filtered: [Fine] {
        var list = store.fines
        if let bucket {
            list = list.filter {
                DeadlineEngine.buckets(for: $0, settings: store.data.settings, now: now).contains(bucket)
            }
        }
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.noticeNumber.lowercased().contains(query)
                || $0.vehiclePlateSnapshot.lowercased().contains(query)
                || $0.location.lowercased().contains(query)
                || $0.details.lowercased().contains(query)
                || $0.article.lowercased().contains(query)
                || ($0.driverNameSnapshot ?? "").lowercased().contains(query)
            }
        }
        return list
    }
}

// MARK: - Compact fine token

struct FineToken: View {
    @Environment(Store.self) private var store
    var fine: Fine
    var now: Date
    var onOpen: () -> Void

    /// Settling a fine: the token shifts right, a highlight runs across the
    /// metal over half a second, and the stamp drops in.
    @State private var settleShift: CGFloat = 0
    @State private var settleSheen: CGFloat = 0
    @State private var stampIn = false

    private var clocks: [Clock] {
        DeadlineEngine.clocks(for: fine, settings: store.data.settings, now: now)
    }

    private var next: Clock? {
        clocks.filter { !$0.isExpired }.min { $0.daysLeft < $1.daysLeft }
    }

    private var statusColor: Color {
        switch fine.status {
        case .paid: return Theme.green
        case .cancelled: return Theme.anchor.opacity(0.3)
        case .underAppeal: return Theme.gold
        case .open:
            if DeadlineEngine.inEnforcement(for: fine, settings: store.data.settings, now: now) { return Theme.maroon }
            if let next, next.daysLeft <= 3 { return Theme.terracotta }
            return Theme.goldDark
        }
    }

    var body: some View {
        Button(action: onOpen) {
            TokenCard(status: statusColor, sheen: settleSheen) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fine.titleLine)
                                .font(TypeScale.condensed(17, .black))
                                .tracking(0.5)
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.anchor)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            HStack(spacing: 8) {
                                Text(fine.noticeNumber.isEmpty ? "NO NUMBER" : fine.noticeNumber)
                                    .font(TypeScale.mono(12))
                                    .textCase(.uppercase)
                                    .foregroundStyle(Theme.anchor.opacity(0.5))
                                if !fine.vehiclePlateSnapshot.isEmpty {
                                    Text("·").foregroundStyle(Theme.anchor.opacity(0.3))
                                    Text(fine.vehiclePlateSnapshot)
                                        .font(TypeScale.mono(12))
                                        .textCase(.uppercase)
                                        .foregroundStyle(Theme.anchor.opacity(0.5))
                                }
                            }
                            .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        if fine.status == .paid {
                            PaidStamp()
                                .scaleEffect(stampIn ? 0.6 : 0.3)
                                .opacity(stampIn ? 1 : 0)
                                .frame(width: 90, height: 44)
                                .onAppear { stampIn = true }
                        } else if fine.status == .cancelled {
                            PaidStamp(text: "CLOSED")
                                .scaleEffect(0.55)
                                .frame(width: 100, height: 44)
                        } else if let next {
                            RingGauge(
                                progress: next.progress,
                                value: "\(max(next.daysLeft, 0))",
                                label: next.kind.title,
                                caption: next.daysLeft == 1 ? "day" : "days",
                                tint: ringTint(next),
                                diameter: 66
                            )
                        }
                    }

                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(Fmt.amount(displayAmount))
                            .font(TypeScale.number(34))
                            .foregroundStyle(fine.status.isClosed ? Theme.anchor.opacity(0.45) : Theme.anchor)
                        Text(Fmt.currencySymbol(store.currency))
                            .font(TypeScale.condensed(14, .bold))
                            .foregroundStyle(Theme.anchor.opacity(0.45))
                        Spacer()
                        Text(Fmt.date(fine.dateOfOffence))
                            .font(TypeScale.condensed(12, .bold))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.anchor.opacity(0.45))
                    }

                    if !statusLine.isEmpty {
                        Text(statusLine)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.anchor.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }

                    if store.isAfterSale(fine) {
                        WarningLine(text: "This fine is dated after you sold the car. That is usually a reason to appeal, not to pay.")
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .offset(x: settleShift)
        .onChange(of: fine.status) { previous, current in
            guard current == .paid, previous != .paid else { return }
            stampIn = false
            withAnimation(.easeOut(duration: 0.18)) { settleShift = 26 }
            withAnimation(Springs.paidSheen) { settleSheen = 0.3 }
            withAnimation(Springs.token.delay(0.18)) { settleShift = 0 }
            withAnimation(Springs.token.delay(0.24)) { stampIn = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.2)) { settleSheen = 0 }
            }
        }
    }

    /// Metal by default; a colour only once the date is genuinely close.
    private func ringTint(_ clock: Clock) -> Color? {
        switch clock.kind {
        case .enforcement: clock.daysLeft <= 14 ? Theme.maroon : nil
        case .appeal: clock.daysLeft <= 3 ? Theme.terracotta : nil
        case .discount, .documentExpiry: clock.daysLeft <= 2 ? Theme.terracotta : nil
        case .appealAnswer: Theme.gold
        }
    }

    private var displayAmount: Double {
        if fine.status == .paid {
            let paid = store.totalPaid(forFine: fine.id)
            return paid > 0 ? paid : fine.amount
        }
        return DeadlineEngine.amountToday(for: fine, settings: store.data.settings, now: now)
    }

    private var statusLine: String {
        switch fine.status {
        case .paid:
            if let closed = fine.closedAt { return "Paid on \(Fmt.date(closed))." }
            return "Paid."
        case .cancelled:
            if let outcome = fine.appeal?.outcome { return "Closed: appeal \(outcome.title.lowercased())." }
            return "Cancelled."
        case .underAppeal, .open:
            return DeadlineEngine.stateLines(for: fine, settings: store.data.settings, now: now).first ?? ""
        }
    }
}

// MARK: - Warning line

struct WarningLine: View {
    var text: String
    var color: Color = Theme.terracotta
    var icon: String = "exclamationmark.triangle.fill"

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(color)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(color.opacity(0.35), lineWidth: 1.5)
        )
    }
}
