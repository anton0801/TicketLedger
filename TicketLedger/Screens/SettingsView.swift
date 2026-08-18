//
//  SettingsView.swift
//  TicketLedger
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(AuthSession.self) private var session
    @Environment(SyncEngine.self) private var sync

    @State private var displayName = ""
    @State private var country = ""
    @State private var currency = "EUR"
    @State private var rules = DeadlineRules.suggested
    @State private var notificationsOn = false
    @State private var prefs = NotificationPrefs()
    @State private var showNotificationExplainer = false
    @State private var notificationDenied = false
    @State private var pendingCount = 0

    @State private var shareItems: [Any] = []
    @State private var showShare = false
    @State private var showImport = false
    @State private var importError: String?
    @State private var importedSummary: String?
    @State private var exportError: String?

    @State private var showClearHistory = false
    @State private var showDeleteAll = false
    @State private var showAbout = false
    @State private var loaded = false

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Settings").screenTitleStyle()

                    if let saveError = store.saveError {
                        ErrorState(
                            title: "Changes are not being saved",
                            message: "The ledger file could not be written: \(saveError)",
                            retryTitle: "Try Again",
                            retry: { store.saveNow() }
                        )
                    }

                    accountBlock
                    profileBlock
                    rulesBlock
                    notificationsBlock
                    dataBlock
                    aboutBlock
                }
                .padding(.horizontal, Metric.screenPadding)
                .padding(.bottom, Metric.contentBottomInset)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.page, for: .navigationBar)
        .onAppear(perform: load)
        .task { await refreshNotificationState() }
        .sheet(isPresented: $showShare) { ShareSheet(items: shareItems) }
        .sheet(isPresented: $showImport) {
            JSONImportPicker { url in
                do {
                    try store.importBackup(from: url)
                    importedSummary = "Imported \(store.data.fines.count) fine(s), \(store.data.vehicles.count) vehicle(s) and \(store.data.documents.count) document(s)."
                    load()
                } catch {
                    importError = "That file could not be read as a Ticket Ledger backup. Nothing was changed."
                }
            }
        }
        .sheet(isPresented: $showAbout) { AboutView() }
        .alert("Clear closed history?", isPresented: $showClearHistory) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { store.clearHistory() }
        } message: {
            Text("Paid and cancelled fines, their evidence, their payments and every renewal record are removed. Open fines, vehicles and documents stay.")
        }
        .alert("Delete all app data?", isPresented: $showDeleteAll) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                store.deleteAllData()
                load()
            }
        } message: {
            Text("Every vehicle, driver, fine, document, payment and photo is deleted from this device. There is no copy anywhere else. This cannot be undone.")
        }
    }

    // MARK: Account

    private var accountBlock: some View {
        FormBlock(
            title: "Account",
            footnote: "Your records live on your own server and on this device. Photos never leave the phone."
        ) {
            NavigationLink(value: Route.account) {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.goldDark)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.state.user?.email ?? "Not signed in")
                            .font(TypeScale.body)
                            .foregroundStyle(Theme.anchor)
                            .lineLimit(1)
                        Text(syncSummary)
                            .font(TypeScale.caption)
                            .foregroundStyle(Theme.anchor.opacity(0.5))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.anchor.opacity(0.3))
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            SecondaryButton("Sync Now", icon: "arrow.triangle.2.circlepath") { sync.syncNow() }
        }
    }

    private var syncSummary: String {
        switch sync.status {
        case .syncing: return "Syncing now"
        case .offline: return "Offline — changes are kept on this device"
        case .failed(let reason): return reason
        case .idle:
            if sync.hasPendingChanges { return "Waiting to sync" }
            if let last = sync.lastSyncedAt {
                return "Synced \(last.formatted(date: .abbreviated, time: .shortened))"
            }
            return "Not synced yet"
        }
    }

    // MARK: Profile

    private var profileBlock: some View {
        FormBlock(title: "Profile") {
            LedgerTextField(label: "Your Display Name", placeholder: "Optional", text: $displayName)
            LedgerTextField(label: "Country of Registration", placeholder: "e.g. PL", text: $country, mono: true)
            LedgerPicker(
                label: "Currency",
                selection: $currency,
                options: SetupView.currencyOptions,
                title: { code in
                    let symbol = Fmt.currencySymbol(code)
                    return symbol == code ? code : "\(code) · \(symbol)"
                }
            )
            NavigationLink(value: Route.drivers) {
                settingsRow(icon: "person.2.fill", title: "Drivers", detail: "\(store.drivers.count)")
            }
            .buttonStyle(.plain)
            NavigationLink(value: Route.payments) {
                settingsRow(icon: "creditcard.fill", title: "Payments", detail: "\(store.payments.count)")
            }
            .buttonStyle(.plain)
            NavigationLink(value: Route.history) {
                settingsRow(icon: "clock.arrow.circlepath", title: "History", detail: "\(store.closedCaseCount)")
            }
            .buttonStyle(.plain)
            MetalButton("Save Profile") { saveProfile() }
        }
    }

    private func settingsRow(icon: String, title: String, detail: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.goldDark)
                .frame(width: 22)
            Text(title)
                .font(TypeScale.body)
                .foregroundStyle(Theme.anchor)
            Spacer()
            if let detail {
                Text(detail)
                    .font(TypeScale.mono(13))
                    .foregroundStyle(Theme.anchor.opacity(0.5))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.anchor.opacity(0.3))
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { GoldRule(opacity: 0.2) }
    }

    // MARK: Deadline rules

    private var rulesBlock: some View {
        FormBlock(
            title: "Deadline Rules",
            footnote: "These periods differ by country and by type of fine. Set them from the notice you received — the app does not know them for you. Changing them here affects every fine that does not have its own windows."
        ) {
            LedgerDaysField(label: "Discount Window Days", days: $rules.discountWindowDays)
            LedgerDaysField(label: "Appeal Window Days", days: $rules.appealWindowDays)
            LedgerDaysField(label: "Enforcement After Days", days: $rules.enforcementAfterDays, range: 1...900)
            let affected = store.data.fines.filter { $0.rulesOverride == nil && !$0.status.isClosed }.count
            if affected > 0 && rules != store.data.settings.rules {
                WarningLine(
                    text: "\(affected) open fine(s) will have their deadlines recounted from these numbers.",
                    color: Theme.terracotta,
                    icon: "arrow.triangle.2.circlepath"
                )
            }
            MetalButton("Save Deadline Rules", enabled: rules.isValid) { saveRules() }
        }
    }

    // MARK: Notifications

    private var notificationsBlock: some View {
        FormBlock(title: "Notifications") {
            if !notificationsOn && !showNotificationExplainer {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Reminders are off. A discount deadline is the one date people notice too late.")
                        .font(TypeScale.body)
                        .foregroundStyle(Theme.anchor.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                    SecondaryButton("What Would Be Sent", icon: "bell") {
                        showNotificationExplainer = true
                    }
                }
            }

            if showNotificationExplainer && !notificationsOn {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach([
                        "Discount ends — a week before, three days before, and on the last day.",
                        "Appeal window closing — three days before and on the last day.",
                        "Enforcement approaching — a week before and the day before.",
                        "Document expiring — at your chosen lead time, then a week and a day before.",
                        "Appeal answer overdue — the day after the date you expected a reply.",
                        "Payment not recorded — three days after you marked a fine for payment."
                    ], id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.goldDark)
                                .padding(.top, 3)
                            Text(line)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.anchor.opacity(0.75))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Text("The last day is when people pay. The other two are so you have a choice.")
                        .font(TypeScale.caption)
                        .foregroundStyle(Theme.goldDark)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("All of it is local to this device. No account, no server.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.anchor.opacity(0.5))
                    MetalButton("Turn Reminders On") { enableNotifications() }
                }
            }

            if notificationDenied {
                WarningLine(
                    text: "Notifications are switched off for Ticket Ledger in iOS Settings. Turn them on there and come back.",
                    color: Theme.terracotta,
                    icon: "bell.slash"
                )
            }

            if notificationsOn {
                LedgerToggle(
                    label: "Reminders",
                    hint: pendingCount > 0 ? "\(pendingCount) reminder(s) scheduled." : "Nothing scheduled — no upcoming dates yet.",
                    isOn: Binding(
                        get: { notificationsOn },
                        set: { newValue in
                            notificationsOn = newValue
                            var settings = store.data.settings
                            settings.notificationsEnabled = newValue
                            store.settings = settings
                            Task { await refreshNotificationState() }
                        }
                    )
                )
                GoldRule(opacity: 0.2)
                LedgerToggle(label: "Discount Ending", isOn: $prefs.discountEnding)
                LedgerToggle(label: "Appeal Window Closing", isOn: $prefs.appealWindowClosing)
                LedgerToggle(label: "Enforcement Approaching", isOn: $prefs.enforcementApproaching)
                LedgerToggle(label: "Document Expiring", isOn: $prefs.documentExpiring)
                LedgerToggle(label: "Appeal Answer Overdue", isOn: $prefs.appealAnswerOverdue)
                LedgerToggle(label: "Payment Not Recorded", isOn: $prefs.paymentNotRecorded)
                MetalButton("Save Reminder Choices") { savePrefs() }
            }
        }
    }

    // MARK: Data

    private var dataBlock: some View {
        FormBlock(
            title: "Data",
            footnote: "Everything lives in one file on this device. Export before you change phones, or when you hand the car over."
        ) {
            if let importedSummary {
                WarningLine(text: importedSummary, color: Theme.green, icon: "checkmark.circle")
                    .onTapGesture { self.importedSummary = nil }
            }
            if let importError {
                WarningLine(text: importError, color: Theme.terracotta)
                    .onTapGesture { self.importError = nil }
            }
            if let exportError {
                WarningLine(text: exportError, color: Theme.terracotta)
                    .onTapGesture { self.exportError = nil }
            }

            SecondaryButton("Export CSV", icon: "tablecells") { exportCSV() }
            SecondaryButton("Export PDF Summary", icon: "doc.richtext") { exportPDF() }
            SecondaryButton("Export Backup (JSON)", icon: "arrow.up.doc") { exportBackup() }
            SecondaryButton("Import Backup", icon: "arrow.down.doc") { showImport = true }

            GoldRule(opacity: 0.25)

            DangerButton("Clear History", icon: "clock.badge.xmark") { showClearHistory = true }
            DangerButton("Delete All App Data", icon: "trash") { showDeleteAll = true }
        }
    }

    // MARK: About

    private var aboutBlock: some View {
        FormBlock(title: "About") {
            SecondaryButton("What This App Does and Does Not Do", icon: "info.circle") { showAbout = true }
            VStack(alignment: .leading, spacing: 6) {
                Text("Ticket Ledger 1.0")
                    .font(TypeScale.condensed(14, .bold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.anchor.opacity(0.6))
                Text("This app tracks dates you enter. It is not legal advice and it does not connect to any official register. Check the fine itself and the deadlines printed on it.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.anchor.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Actions

    private func load() {
        let settings = store.data.settings
        displayName = settings.displayName
        country = settings.country
        currency = settings.currencyCode
        rules = settings.rules
        notificationsOn = settings.notificationsEnabled
        prefs = settings.notificationPrefs
        loaded = true
    }

    private func saveProfile() {
        var settings = store.data.settings
        settings.displayName = displayName.trimmingCharacters(in: .whitespaces)
        settings.country = country.trimmingCharacters(in: .whitespaces).uppercased()
        settings.currencyCode = currency
        store.settings = settings
        store.saveNow()
    }

    private func saveRules() {
        guard rules.isValid else { return }
        var settings = store.data.settings
        settings.rules = rules
        store.settings = settings
        store.saveNow()
    }

    private func savePrefs() {
        var settings = store.data.settings
        settings.notificationPrefs = prefs
        store.settings = settings
        store.saveNow()
        Task { await refreshNotificationState() }
    }

    private func enableNotifications() {
        Task {
            let granted = await NotificationScheduler.shared.requestAuthorization()
            if granted {
                notificationsOn = true
                notificationDenied = false
                var settings = store.data.settings
                settings.notificationsEnabled = true
                store.settings = settings
                store.saveNow()
            } else {
                notificationDenied = true
            }
            await refreshNotificationState()
        }
    }

    private func refreshNotificationState() async {
        let status = await NotificationScheduler.shared.authorizationStatus()
        notificationDenied = status == .denied
        if status == .denied, store.data.settings.notificationsEnabled {
            var settings = store.data.settings
            settings.notificationsEnabled = false
            store.settings = settings
            notificationsOn = false
        }
        pendingCount = await NotificationScheduler.shared.pendingCount()
    }

    private func exportCSV() {
        do {
            shareItems = try ExportManager.writeCSVs(store)
            showShare = true
        } catch {
            exportError = "The CSV files could not be written: \(error.localizedDescription)"
        }
    }

    private func exportPDF() {
        do {
            shareItems = [try ExportManager.writePDF(store)]
            showShare = true
        } catch {
            exportError = "The PDF could not be written: \(error.localizedDescription)"
        }
    }

    private func exportBackup() {
        do {
            shareItems = [try store.exportBackup()]
            showShare = true
        } catch {
            exportError = "The backup could not be written: \(error.localizedDescription)"
        }
    }
}

// MARK: - About

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.page.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("What This App Does").screenTitleStyle()

                        Text("Ticket Ledger keeps every obligation attached to a car in one place, and counts the dates that cost money: how long a discount holds, how long the appeal window stays open, and when a debt goes to enforcement.")
                            .font(TypeScale.body)
                            .foregroundStyle(Theme.anchor.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)

                        FormBlock(title: "What it does not do") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach([
                                    "It does not connect to any official register. Every number here is one you typed.",
                                    "It does not pay fines and does not submit appeals.",
                                    "It does not write appeal texts and does not suggest wording.",
                                    "It does not give legal advice and does not predict the outcome of an appeal.",
                                    "It does not rate how strong your grounds are.",
                                    "It does not invent amounts. An unknown enforcement cost stays \"unknown amount added\".",
                                    "It does not send your data anywhere. There is no account and no server."
                                ], id: \.self) { line in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .black))
                                            .foregroundStyle(Theme.maroon)
                                            .padding(.top, 4)
                                        Text(line)
                                            .font(.system(size: 14))
                                            .foregroundStyle(Theme.anchor.opacity(0.8))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }

                        FormBlock(title: "The standing notice") {
                            Text("This app tracks dates you enter. It is not legal advice and it does not connect to any official register. Check the fine itself and the deadlines printed on it.")
                                .font(TypeScale.body)
                                .foregroundStyle(Theme.anchor)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Theme.gold.opacity(0.12))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Theme.gold.opacity(0.5), lineWidth: 2)
                                )
                        }

                        FormBlock(title: "Where your data is") {
                            Text("One JSON file plus your photos, inside this app's own storage on this device. Deleting the app deletes all of it. Export a backup before you switch phones.")
                                .font(TypeScale.body)
                                .foregroundStyle(Theme.anchor.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(Metric.screenPadding)
                    .padding(.bottom, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("About")
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
}
