//
//  MainTabsView.swift
//  TicketLedger
//

import SwiftUI

/// One route type, so every stack can push the same destinations.
enum Route: Hashable {
    case fine(UUID)
    case vehicle(UUID)
    case driver(UUID)
    case document(UUID)
    case location(String)
    case drivers
    case payments
    case locations
    case calendar
    case history
    case settings
    case account
}

extension View {
    /// Installs every push destination on a navigation stack.
    func ledgerDestinations() -> some View {
        self.navigationDestination(for: Route.self) { route in
            switch route {
            case .fine(let id): FineDetailView(fineID: id)
            case .vehicle(let id): VehicleDetailView(vehicleID: id)
            case .driver(let id): DriverDetailView(driverID: id)
            case .document(let id): DocumentDetailView(documentID: id)
            case .location(let key): LocationDetailView(locationKey: key)
            case .drivers: DriversView()
            case .payments: PaymentsView()
            case .locations: LocationsView()
            case .calendar: DeadlineCalendarView()
            case .history: HistoryView()
            case .settings: SettingsView()
            case .account: AccountView()
            }
        }
    }
}

struct MainTabsView: View {
    @Environment(Store.self) private var store
    @State private var tab: LedgerTab = .queue

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $tab) {
                QueueView()
                    .tag(LedgerTab.queue)
                    .toolbar(.hidden, for: .tabBar)
                FinesView()
                    .tag(LedgerTab.fines)
                    .toolbar(.hidden, for: .tabBar)
                VehiclesView()
                    .tag(LedgerTab.vehicles)
                    .toolbar(.hidden, for: .tabBar)
                DocumentsView()
                    .tag(LedgerTab.documents)
                    .toolbar(.hidden, for: .tabBar)
                InsightsView()
                    .tag(LedgerTab.insights)
                    .toolbar(.hidden, for: .tabBar)
            }

            LedgerTabBar(selection: $tab, badges: badges)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var badges: [LedgerTab: Int] {
        let urgent = store.urgentCount()
        return urgent > 0 ? [.queue: urgent] : [:]
    }
}
