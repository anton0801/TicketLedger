//
//  LedgerTabBar.swift
//  TicketLedger
//
//  Graphite bar across the full width. The active tab is marked by a gold notch
//  along the top of its cell; the notch travels on a 300/24 spring.
//

import SwiftUI

enum LedgerTab: Int, CaseIterable, Identifiable {
    case queue, fines, vehicles, documents, insights

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .queue: "Queue"
        case .fines: "Fines"
        case .vehicles: "Vehicles"
        case .documents: "Docs"
        case .insights: "Insights"
        }
    }

    var icon: String {
        switch self {
        case .queue: "list.number"
        case .fines: "doc.text"
        case .vehicles: "car.fill"
        case .documents: "folder.fill"
        case .insights: "chart.bar.fill"
        }
    }
}

struct LedgerTabBar: View {
    @Binding var selection: LedgerTab
    /// Badge counts per tab, shown only when non-zero.
    var badges: [LedgerTab: Int] = [:]

    @Namespace private var notch

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LedgerTab.allCases) { tab in
                Button {
                    guard tab != selection else { return }
                    withAnimation(Springs.notch) { selection = tab }
                } label: {
                    cell(tab)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: Metric.tabBarHeight)
        .background(Theme.anchor)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.gold.opacity(0.25)).frame(height: 1)
        }
    }

    @ViewBuilder
    private func cell(_ tab: LedgerTab) -> some View {
        let active = tab == selection
        VStack(spacing: 5) {
            ZStack(alignment: .top) {
                // The 5px notch sits along the top edge of the active cell.
                Rectangle()
                    .fill(Theme.gold)
                    .frame(height: 5)
                    .opacity(active ? 1 : 0)
                    .matchedGeometryEffect(id: active ? "notch" : "notch-\(tab.rawValue)", in: notch, isSource: active)
            }
            .frame(height: 5)

            ZStack(alignment: .topTrailing) {
                Image(systemName: tab.icon)
                    .font(.system(size: 19, weight: active ? .bold : .regular))
                if let count = badges[tab], count > 0 {
                    Text(count > 99 ? "99+" : "\(count)")
                        .font(TypeScale.mono(9))
                        .foregroundStyle(Theme.anchor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule(style: .continuous).fill(Theme.goldLight))
                        .offset(x: 14, y: -7)
                }
            }
            .frame(height: 24)

            Text(tab.title)
                .font(TypeScale.condensed(10, .bold))
                .tracking(1)
                .textCase(.uppercase)
        }
        .foregroundStyle(active ? Theme.gold : Theme.page.opacity(0.45))
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack {
        Spacer()
        LedgerTabBar(selection: .constant(.queue), badges: [.fines: 3])
    }
    .background(Theme.page)
}
