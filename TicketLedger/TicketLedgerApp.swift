//
//  TicketLedgerApp.swift
//  TicketLedger
//
//  Created by Anton Danilov on 13/8/26.
//

import SwiftUI

@main
struct TicketLedgerApp: App {
    @State private var store = Store()
    @State private var session = AuthSession()
    @State private var sync = SyncEngine()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(session)
                .environment(sync)
                .task {
                    sync.attach(to: store)
                    if store.state == .loading { await store.load() }
                    await session.restore()
                }
        }
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(AuthSession.self) private var session
    @Environment(SyncEngine.self) private var sync
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()

            switch store.state {
            case .loading:
                LoadingState()

            case .failed(let message):
                ScrollView {
                    VStack(spacing: 18) {
                        ErrorState(
                            title: "The ledger did not open",
                            message: message,
                            retryTitle: "Retry",
                            retry: { store.retryLoad() }
                        )
                        SecondaryButton("Start a Fresh Ledger") {
                            store.deleteAllData()
                            store.state = .ready
                        }
                    }
                    .padding(Metric.screenPadding)
                    .padding(.top, 60)
                }

            case .ready:
                accountGate
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.state)
        .animation(.easeInOut(duration: 0.3), value: session.state)
        .animation(.easeInOut(duration: 0.3), value: store.data.settings.setupDone)
        .animation(.easeInOut(duration: 0.3), value: store.data.settings.onboardingDone)
        .onChange(of: session.state) { _, state in
            guard let user = state.user else { return }
            sync.prepareForAccount(user.id, on: store)
            sync.syncNow()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, session.state.isSignedIn {
                sync.syncNow()
            }
        }
    }

    @ViewBuilder
    private var accountGate: some View {
        Group {
                switch session.state {
                case .restoring:
                    LoadingState(message: "Opening your account")

                case .signedOut:
                    AuthView()
                        .transition(.opacity)

                case .signedIn:
                    signedInContent
                        .transition(.opacity)
                }
        }
    }

    @ViewBuilder
    private var signedInContent: some View {
        if !store.data.settings.onboardingDone {
            OnboardingView()
        } else if !store.data.settings.setupDone {
            SetupView()
        } else {
            MainTabsView()
        }
    }
}
