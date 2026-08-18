//
//  AccountView.swift
//  TicketLedger
//
//  The account itself: who is signed in, what other devices are open, and the
//  two ways out — signing out, and removing the account for good.
//

import SwiftUI

struct AccountView: View {
    @Environment(Store.self) private var store
    @Environment(AuthSession.self) private var session
    @Environment(SyncEngine.self) private var sync
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var email = ""
    @State private var emailPassword = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var sessions: [APISession] = []
    @State private var loadingSessions = false
    @State private var message: String?
    @State private var messageIsGood = false
    @State private var showSignOut = false
    @State private var showDelete = false
    @State private var deletePassword = ""
    @State private var deleteError: String?

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    if let message {
                        WarningLine(
                            text: message,
                            color: messageIsGood ? Theme.green : Theme.terracotta,
                            icon: messageIsGood ? "checkmark.circle" : "exclamationmark.triangle.fill"
                        )
                    }

                    syncBlock
                    profileBlock
                    passwordBlock
                    sessionsBlock
                    dangerBlock
                }
                .padding(.horizontal, Metric.screenPadding)
                .padding(.bottom, Metric.contentBottomInset)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.page, for: .navigationBar)
        .onAppear {
            displayName = session.state.user?.displayName ?? ""
            email = session.state.user?.email ?? ""
        }
        .task { await loadSessions() }
        .alert("Sign out of this device?", isPresented: $showSignOut) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task {
                    await session.signOut()
                    store.wipeForSignOut()
                }
            }
        } message: {
            Text("Your records stay on the server. This device clears its copy, and gets it back when you sign in again.")
        }
        .sheet(isPresented: $showDelete) { deleteSheet }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Account").screenTitleStyle()
            if let user = session.state.user {
                Text(user.email)
                    .font(TypeScale.mono(14))
                    .foregroundStyle(Theme.goldDark)
                if let created = user.createdAt {
                    Text("With you since \(Fmt.date(created))")
                        .font(TypeScale.caption)
                        .foregroundStyle(Theme.anchor.opacity(0.5))
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: Sync

    private var syncBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Sync")
            GoldRule()
            TokenCard(status: syncColor, showsHoles: false) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        if sync.status == .syncing {
                            ProgressView().tint(Theme.goldDark).scaleEffect(0.8)
                        } else {
                            Image(systemName: syncIcon)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(syncColor)
                        }
                        Text(syncTitle)
                            .font(TypeScale.condensed(16, .black))
                            .tracking(0.5)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.anchor)
                    }
                    Text(syncDetail)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.anchor.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                    if !sync.rejected.isEmpty {
                        Text("The server would not take: \(sync.rejected.joined(separator: "; "))")
                            .font(TypeScale.caption)
                            .foregroundStyle(Theme.terracotta)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            SecondaryButton("Sync Now", icon: "arrow.triangle.2.circlepath") { sync.syncNow() }
        }
    }

    private var syncColor: Color {
        switch sync.status {
        case .idle: sync.hasPendingChanges ? Theme.gold : Theme.green
        case .syncing: Theme.gold
        case .offline: Theme.terracotta
        case .failed: Theme.maroon
        }
    }

    private var syncIcon: String {
        switch sync.status {
        case .idle: sync.hasPendingChanges ? "arrow.up.circle" : "checkmark.circle.fill"
        case .syncing: "arrow.triangle.2.circlepath"
        case .offline: "wifi.slash"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var syncTitle: String {
        switch sync.status {
        case .idle: sync.hasPendingChanges ? "Waiting to sync" : "Up to date"
        case .syncing: "Syncing"
        case .offline: "Working offline"
        case .failed: "Sync problem"
        }
    }

    private var syncDetail: String {
        switch sync.status {
        case .failed(let reason):
            return reason
        case .offline:
            return "The server cannot be reached. Everything you enter is kept here and goes up as soon as there is a connection."
        default:
            if let last = sync.lastSyncedAt {
                return "Last synced \(Fmt.date(last)) at \(last.formatted(date: .omitted, time: .shortened))."
            }
            return "Nothing has been synced yet."
        }
    }

    // MARK: Profile

    private var profileBlock: some View {
        FormBlock(title: "Profile") {
            LedgerTextField(label: "Display Name", placeholder: "Optional", text: $displayName)
            MetalButton("Save Name", enabled: !session.busy) { saveName() }

            GoldRule(opacity: 0.2)

            LedgerTextField(
                label: "Email",
                placeholder: "you@example.com",
                text: $email,
                keyboard: .emailAddress,
                autocapitalization: .never
            )
            if email != (session.state.user?.email ?? "") {
                SecureFieldRow(label: "Current Password", text: $emailPassword)
                SecondaryButton("Change Email", enabled: !session.busy) { saveEmail() }
                Text("Changing the address that owns the account needs your password.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.anchor.opacity(0.5))
            }
        }
    }

    // MARK: Password

    private var passwordBlock: some View {
        FormBlock(
            title: "Password",
            footnote: "Changing it signs out every other device. This one stays signed in."
        ) {
            SecureFieldRow(label: "Current Password", text: $currentPassword)
            SecureFieldRow(label: "New Password", text: $newPassword)
            MetalButton("Change Password", enabled: !session.busy && newPassword.count >= 10) {
                changePassword()
            }
        }
    }

    // MARK: Sessions

    private var sessionsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Signed-in Devices", trailing: sessions.isEmpty ? nil : "\(sessions.count)")
            GoldRule()

            if loadingSessions {
                ProgressView().tint(Theme.goldDark)
            } else if sessions.isEmpty {
                Text("Only this device, or the list could not be loaded.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.anchor.opacity(0.6))
            } else {
                VStack(spacing: 0) {
                    ForEach(sessions) { item in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.deviceName.isEmpty ? "Unknown device" : item.deviceName)
                                        .font(TypeScale.condensed(15, .bold))
                                        .textCase(.uppercase)
                                        .foregroundStyle(Theme.anchor)
                                    if item.current {
                                        Text("this one")
                                            .font(TypeScale.condensed(10, .black))
                                            .tracking(1)
                                            .textCase(.uppercase)
                                            .foregroundStyle(Theme.green)
                                    }
                                }
                                if let used = item.lastUsedAt ?? item.createdAt {
                                    Text("Last used \(Fmt.date(used))")
                                        .font(TypeScale.caption)
                                        .foregroundStyle(Theme.anchor.opacity(0.5))
                                }
                            }
                            Spacer()
                            if !item.current {
                                Button {
                                    revoke(item)
                                } label: {
                                    Text("End")
                                        .font(TypeScale.condensed(12, .black))
                                        .tracking(1)
                                        .textCase(.uppercase)
                                        .foregroundStyle(Theme.maroon)
                                        .padding(.horizontal, 10)
                                        .frame(height: 30)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(Theme.maroon.opacity(0.5), lineWidth: 1.5)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 10)
                        if item.id != sessions.last?.id { GoldRule(opacity: 0.2) }
                    }
                }
            }

            SecondaryButton("Sign Out Everywhere", icon: "iphone.slash") { signOutEverywhere() }
        }
    }

    // MARK: Danger

    private var dangerBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Leaving")
            GoldRule()
            DangerButton("Sign Out", icon: "rectangle.portrait.and.arrow.right") { showSignOut = true }
            DangerButton("Delete Account", icon: "trash") { showDelete = true }
            Text("Deleting removes every vehicle, fine, document and payment from the server, and clears this device. There is no copy anywhere else and it cannot be undone.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.anchor.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var deleteSheet: some View {
        NavigationStack {
            ZStack {
                Theme.page.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Delete Account").screenTitleStyle()
                        WarningLine(
                            text: "Everything goes: your vehicles, fines, evidence, payments and history, on the server and on this device. This cannot be undone.",
                            color: Theme.maroon
                        )
                        if let deleteError {
                            WarningLine(text: deleteError, color: Theme.terracotta)
                        }
                        SecureFieldRow(label: "Your Password", text: $deletePassword)
                        DangerButton("Delete Everything", icon: "trash") { deleteAccount() }
                        SecondaryButton("Keep My Account") { showDelete = false }
                    }
                    .padding(Metric.screenPadding)
                }
            }
            .toolbarBackground(Theme.page, for: .navigationBar)
        }
    }

    // MARK: Actions

    private func saveName() {
        Task {
            do {
                try await session.updateProfile(displayName: displayName, email: nil, currentPassword: nil)
                var settings = store.data.settings
                settings.displayName = displayName
                store.settings = settings
                show("Name saved.", good: true)
            } catch {
                show(error.localizedDescription, good: false)
            }
        }
    }

    private func saveEmail() {
        Task {
            do {
                try await session.updateProfile(
                    displayName: nil,
                    email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                    currentPassword: emailPassword
                )
                emailPassword = ""
                show("Email changed.", good: true)
            } catch {
                show(error.localizedDescription, good: false)
            }
        }
    }

    private func changePassword() {
        Task {
            do {
                try await session.changePassword(current: currentPassword, next: newPassword)
                currentPassword = ""
                newPassword = ""
                await loadSessions()
                show("Password changed. Other devices were signed out.", good: true)
            } catch {
                show(error.localizedDescription, good: false)
            }
        }
    }

    private func loadSessions() async {
        loadingSessions = true
        sessions = (try? await session.sessions()) ?? []
        loadingSessions = false
    }

    private func revoke(_ item: APISession) {
        Task {
            do {
                try await session.revokeSession(id: item.id)
                await loadSessions()
                show("That device was signed out.", good: true)
            } catch {
                show(error.localizedDescription, good: false)
            }
        }
    }

    private func signOutEverywhere() {
        Task {
            do {
                try await session.signOutEverywhere()
                store.wipeForSignOut()
            } catch {
                show(error.localizedDescription, good: false)
            }
        }
    }

    private func deleteAccount() {
        deleteError = nil
        Task {
            do {
                try await session.deleteAccount(password: deletePassword)
                deletePassword = ""
                showDelete = false
                store.wipeForSignOut()
            } catch {
                deleteError = error.localizedDescription
            }
        }
    }

    private func show(_ text: String, good: Bool) {
        message = text
        messageIsGood = good
    }
}

// MARK: - Secure field in the app's style

struct SecureFieldRow: View {
    var label: String
    @Binding var text: String
    @State private var visible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(TypeScale.condensed(12, .bold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.anchor.opacity(0.55))
                Spacer()
                Button {
                    visible.toggle()
                } label: {
                    Image(systemName: visible ? "eye.slash" : "eye")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.goldDark)
                }
                .buttonStyle(.plain)
            }
            Group {
                if visible {
                    TextField("", text: $text)
                } else {
                    SecureField("", text: $text)
                }
            }
            .font(TypeScale.body)
            .foregroundStyle(Theme.anchor)
            .tint(Theme.goldDark)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.card))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.gold.opacity(0.45), lineWidth: 1.5)
            )
        }
    }
}
