//
//  LocationsView.swift
//  TicketLedger
//
//  Where fines keep happening. The useful conclusion is rarely bad luck — it is
//  a particular street.
//

import SwiftUI

struct LocationsView: View {
    @Environment(Store.self) private var store
    @State private var now = Date()

    private var stats: [Store.LocationStat] { store.locationStats() }
    private var repeats: [Store.LocationStat] { stats.filter { $0.count >= 2 } }

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Locations").screenTitleStyle()
                        Text("\(stats.count) place(s) recorded")
                            .font(TypeScale.caption)
                            .foregroundStyle(Theme.anchor.opacity(0.55))
                    }

                    if stats.isEmpty {
                        EmptyState(
                            title: "No Places Yet",
                            message: "Fill in the location on your fines, written the same way each time. After a few records this section shows where you keep getting caught.",
                            actionTitle: nil,
                            action: nil
                        )
                    } else {
                        if !repeats.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader("Repeat Spots", trailing: "\(repeats.count)")
                                GoldRule()
                                ForEach(Array(repeats.enumerated()), id: \.element.id) { index, stat in
                                    NavigationLink(value: Route.location(stat.key)) {
                                        repeatToken(stat)
                                    }
                                    .buttonStyle(.plain)
                                    .tokenAppear(index)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("All Places")
                            GoldRule()
                            VStack(spacing: 0) {
                                ForEach(stats) { stat in
                                    NavigationLink(value: Route.location(stat.key)) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(stat.display)
                                                    .font(TypeScale.body)
                                                    .foregroundStyle(Theme.anchor)
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.leading)
                                                Text(stat.types.prefix(2).joined(separator: ", "))
                                                    .font(TypeScale.caption)
                                                    .foregroundStyle(Theme.anchor.opacity(0.5))
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 0) {
                                                Text("\(stat.count)")
                                                    .font(TypeScale.number(22))
                                                    .foregroundStyle(stat.count >= 3 ? Theme.terracotta : Theme.anchor)
                                                Text(stat.count == 1 ? "fine" : "fines")
                                                    .font(TypeScale.condensed(10, .bold))
                                                    .tracking(1)
                                                    .textCase(.uppercase)
                                                    .foregroundStyle(Theme.anchor.opacity(0.45))
                                            }
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(Theme.anchor.opacity(0.3))
                                        }
                                        .padding(.vertical, 11)
                                    }
                                    .buttonStyle(.plain)
                                    if stat.id != stats.last?.id { GoldRule(opacity: 0.2) }
                                }
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
    }

    private func repeatToken(_ item: Store.LocationStat) -> some View {
        TokenCard(status: item.count >= 4 ? Theme.maroon : Theme.terracotta) {
            VStack(alignment: .leading, spacing: 10) {
                Text(item.display)
                    .font(TypeScale.condensed(19, .black))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.anchor)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                Text(sentence(item))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.anchor.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                GoldRule(opacity: 0.25)

                HStack(spacing: 0) {
                    statCell(value: "\(item.count)", label: "Times fined")
                    statCell(value: Fmt.amount(item.totalPaid), label: "Total paid")
                    statCell(value: Fmt.amount(item.totalAmount), label: "Total issued")
                }
            }
        }
    }

    /// "Four fines at the same street in eight months, all for parking. Total 210."
    private func sentence(_ item: Store.LocationStat) -> String {
        let fines = store.data.fines.filter {
            $0.location.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == item.key
        }
        guard let earliest = fines.map(\.dateOfOffence).min(),
              let latest = fines.map(\.dateOfOffence).max() else { return "" }
        let months = max(1, (Fmt.cal.dateComponents([.month], from: earliest, to: latest).month ?? 0) + 1)
        let sameType = item.types.count == 1
        let typePart = sameType ? ", all for \(item.types[0].lowercased())" : ", of \(item.types.count) different kinds"
        let monthPart = months == 1 ? "within a month" : "in \(months) months"
        return "\(item.count) fines at this place \(monthPart)\(typePart). Total paid \(Fmt.money(item.totalPaid, store.currency))."
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: -1) {
            Text(value)
                .font(TypeScale.number(24))
                .foregroundStyle(Theme.anchor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(TypeScale.condensed(10, .bold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.anchor.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Detail

struct LocationDetailView: View {
    @Environment(Store.self) private var store
    var locationKey: String
    @State private var now = Date()

    private var fines: [Fine] {
        store.data.fines
            .filter { $0.location.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == locationKey }
            .sorted { $0.dateOfOffence > $1.dateOfOffence }
    }

    private var display: String {
        fines.first?.location ?? locationKey
    }

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(display).screenTitleStyle()
                        Text("\(fines.count) fine(s) recorded here")
                            .font(TypeScale.caption)
                            .foregroundStyle(Theme.anchor.opacity(0.55))
                    }
                    .padding(.top, 4)

                    if fines.isEmpty {
                        EmptyState(
                            title: "Nothing Here Anymore",
                            message: "No fines carry this location now.",
                            actionTitle: nil,
                            action: nil
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader("Totals")
                            GoldRule()
                            VStack(spacing: 0) {
                                DetailRow(label: "Total Issued", value: Fmt.money(fines.reduce(0) { $0 + $1.amount }, store.currency))
                                DetailRow(
                                    label: "Total Paid",
                                    value: Fmt.money(fines.reduce(0) { $0 + store.totalPaid(forFine: $1.id) }, store.currency)
                                )
                                DetailRow(label: "First", value: Fmt.date(fines.map(\.dateOfOffence).min() ?? Date()))
                                DetailRow(label: "Latest", value: Fmt.date(fines.map(\.dateOfOffence).max() ?? Date()))
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("The Fines")
                            GoldRule()
                            ForEach(fines) { fine in
                                NavigationLink(value: Route.fine(fine.id)) {
                                    FineToken(fine: fine, now: now) {}
                                        .allowsHitTesting(false)
                                }
                                .buttonStyle(.plain)
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
    }
}
