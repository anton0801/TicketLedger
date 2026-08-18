//
//  DeadlineCalendarView.swift
//  TicketLedger
//
//  Every deadline on one sheet: discounts, appeals, enforcement, renewals.
//  Days with several marks get a gold frame.
//

import SwiftUI

struct DeadlineCalendarView: View {
    @Environment(Store.self) private var store

    @State private var month = Fmt.cal.startOfDay(for: Date())
    @State private var selectedDay: Date?
    @State private var now = Date()

    /// One entry per deadline falling on a day.
    private struct Mark: Identifiable {
        var id = UUID()
        var date: Date
        var title: String
        var subtitle: String
        var color: Color
        var route: Route
    }

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Calendar").screenTitleStyle()
                        Text("\(marks.count) deadline(s) tracked")
                            .font(TypeScale.caption)
                            .foregroundStyle(Theme.anchor.opacity(0.55))
                    }

                    monthHeader
                    grid
                    legend

                    if let selectedDay {
                        dayList(selectedDay)
                    } else if marks.isEmpty {
                        EmptyState(
                            title: "No Dates Yet",
                            message: "Add a fine or a document and its deadlines appear here.",
                            actionTitle: nil,
                            action: nil
                        )
                    } else {
                        upcomingList
                    }

                    DeadlineDisclaimer()
                }
                .padding(.horizontal, Metric.screenPadding)
                .padding(.bottom, Metric.contentBottomInset)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.page, for: .navigationBar)
    }

    // MARK: Month header

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                monthArrow("chevron.left")
            }
            .buttonStyle(.plain)

            Spacer()
            Text(Fmt.monthYear(month))
                .font(TypeScale.condensed(20, .black))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.anchor)
            Spacer()

            Button {
                shiftMonth(1)
            } label: {
                monthArrow("chevron.right")
            }
            .buttonStyle(.plain)
        }
    }

    private func monthArrow(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Theme.goldDark)
            .frame(width: 40, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.gold.opacity(0.5), lineWidth: 2)
            )
    }

    private func shiftMonth(_ delta: Int) {
        if let next = Fmt.cal.date(byAdding: .month, value: delta, to: month) {
            withAnimation(.easeInOut(duration: 0.2)) {
                month = next
                selectedDay = nil
            }
        }
    }

    // MARK: Grid

    private var grid: some View {
        let days = monthDays
        let weekdaySymbols = orderedWeekdaySymbols

        return VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(TypeScale.condensed(10, .bold))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.anchor.opacity(0.4))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Metric.tokenRadius, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metric.tokenRadius, style: .continuous)
                .strokeBorder(Theme.gold.opacity(0.4), lineWidth: 2)
        )
    }

    private func dayCell(_ day: Date) -> some View {
        let dayMarks = marks.filter { Fmt.cal.isDate($0.date, inSameDayAs: day) }
        let isToday = Fmt.cal.isDate(day, inSameDayAs: now)
        let isSelected = selectedDay.map { Fmt.cal.isDate($0, inSameDayAs: day) } ?? false
        let multiple = dayMarks.count > 1

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDay = isSelected ? nil : day
            }
        } label: {
            VStack(spacing: 3) {
                Text("\(Fmt.cal.component(.day, from: day))")
                    .font(TypeScale.number(15))
                    .foregroundStyle(dayMarks.isEmpty ? Theme.anchor.opacity(0.55) : Theme.anchor)
                HStack(spacing: 2) {
                    ForEach(dayMarks.prefix(3)) { mark in
                        Circle().fill(mark.color).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(cellFill(dayMarks: dayMarks, isSelected: isSelected))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        multiple ? AnyShapeStyle(Theme.metal) : AnyShapeStyle(isToday ? Theme.anchor.opacity(0.5) : Color.clear),
                        lineWidth: multiple ? 2 : 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func cellFill(dayMarks: [Mark], isSelected: Bool) -> Color {
        if isSelected { return Theme.gold.opacity(0.28) }
        guard let first = dayMarks.first else { return .clear }
        return first.color.opacity(0.1)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(Theme.green, "Discount")
            legendItem(Theme.terracotta, "Appeal")
            legendItem(Theme.maroon, "Enforcement")
            legendItem(Theme.goldDark, "Document")
        }
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(TypeScale.condensed(10, .bold))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.anchor.opacity(0.5))
        }
    }

    // MARK: Lists

    private func dayList(_ day: Date) -> some View {
        let dayMarks = marks.filter { Fmt.cal.isDate($0.date, inSameDayAs: day) }
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(Fmt.date(day), trailing: dayMarks.isEmpty ? nil : "\(dayMarks.count)")
            GoldRule()
            if dayMarks.isEmpty {
                Text("Nothing falls on this day.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.anchor.opacity(0.6))
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(dayMarks) { mark in
                        markRow(mark)
                        if mark.id != dayMarks.last?.id { GoldRule(opacity: 0.2) }
                    }
                }
            }
        }
    }

    private var upcomingList: some View {
        let upcoming = marks
            .filter { Fmt.days(from: now, to: $0.date) >= 0 }
            .sorted { $0.date < $1.date }
            .prefix(8)

        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Next Up")
            GoldRule()
            if upcoming.isEmpty {
                Text("Every date you have entered is in the past.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.anchor.opacity(0.6))
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(upcoming) { mark in
                        markRow(mark)
                        if mark.id != upcoming.last?.id { GoldRule(opacity: 0.2) }
                    }
                }
            }
        }
    }

    private func markRow(_ mark: Mark) -> some View {
        NavigationLink(value: mark.route) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(mark.color)
                    .frame(width: 4, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mark.title)
                        .font(TypeScale.condensed(15, .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.anchor)
                        .lineLimit(1)
                    Text(mark.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.anchor.opacity(0.6))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(Fmt.shortDate(mark.date))
                        .font(TypeScale.mono(12))
                        .foregroundStyle(Theme.anchor.opacity(0.6))
                    Text(Fmt.relativeDays(Fmt.days(from: now, to: mark.date)))
                        .font(TypeScale.condensed(10, .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(mark.color)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.anchor.opacity(0.3))
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: Data

    private var marks: [Mark] {
        var result: [Mark] = []

        for fine in store.data.fines where !fine.status.isClosed {
            let plate = fine.vehiclePlateSnapshot.uppercased()
            let label = fine.noticeNumber.isEmpty ? fine.titleLine : fine.noticeNumber
            for clock in DeadlineEngine.clocks(for: fine, settings: store.data.settings, now: now) {
                let color: Color
                let title: String
                switch clock.kind {
                case .discount:
                    color = Theme.green
                    title = "Discount ends"
                case .appeal:
                    color = Theme.terracotta
                    title = "Appeal closes"
                case .enforcement:
                    color = Theme.maroon
                    title = "Enforcement"
                case .appealAnswer:
                    color = Theme.gold
                    title = "Answer due"
                case .documentExpiry:
                    continue
                }
                result.append(Mark(
                    date: clock.deadline,
                    title: title,
                    subtitle: "\(label)\(plate.isEmpty ? "" : " · \(plate)")",
                    color: color,
                    route: .fine(fine.id)
                ))
            }
        }

        for document in store.data.documents {
            result.append(Mark(
                date: Fmt.cal.startOfDay(for: document.validUntil),
                title: document.type.shortTitle,
                subtitle: "\(store.subject(for: document)) · valid until",
                color: Theme.goldDark,
                route: .document(document.id)
            ))
        }

        return result
    }

    private var monthDays: [Date?] {
        guard let interval = Fmt.cal.dateInterval(of: .month, for: month),
              let firstWeekday = Fmt.cal.dateComponents([.weekday], from: interval.start).weekday else { return [] }
        let leading = (firstWeekday - Fmt.cal.firstWeekday + 7) % 7
        let dayCount = Fmt.cal.range(of: .day, in: .month, for: month)?.count ?? 30
        var days: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            days.append(Fmt.cal.date(byAdding: .day, value: offset, to: interval.start))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = Fmt.cal.veryShortStandaloneWeekdaySymbols
        let start = Fmt.cal.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }
}
