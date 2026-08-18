//
//  AuthView.swift
//  TicketLedger
//
//  The gate. An account is what lets the same ledger open on a second device;
//  the records still live on this one and still work without a signal.
//

import SwiftUI

struct AuthView: View {
    @Environment(AuthSession.self) private var session

    private enum Mode: String, CaseIterable {
        case signIn, register
        var title: String { self == .signIn ? "Sign In" : "Create Account" }
    }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var showPassword = false
    @State private var errorMessage: String?
    @State private var fieldErrors: [String: String] = [:]
    @State private var showServerSettings = false

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
            && password.count >= (mode == .register ? 10 : 1)
            && !session.busy
    }

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    modeChips

                    if let errorMessage {
                        WarningLine(text: errorMessage, color: Theme.terracotta)
                    }

                    FormBlock(title: mode == .signIn ? "Your Account" : "New Account") {
                        if mode == .register {
                            LedgerTextField(
                                label: "Your Display Name",
                                placeholder: "Optional",
                                text: $displayName,
                                error: fieldErrors["displayName"]
                            )
                        }
                        LedgerTextField(
                            label: "Email",
                            placeholder: "you@example.com",
                            text: $email,
                            required: true,
                            error: fieldErrors["email"],
                            keyboard: .emailAddress,
                            autocapitalization: .never
                        )
                        passwordField
                        if mode == .register {
                            Text("At least 10 characters, and not your email address. It is hashed with Argon2id on the server — nobody can read it back, so it cannot be recovered, only replaced.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.anchor.opacity(0.5))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    MetalButton(
                        mode.title,
                        icon: mode == .signIn ? "arrow.right.circle.fill" : "person.badge.plus",
                        enabled: canSubmit
                    ) {
                        submit()
                    }

                    if session.busy {
                        HStack(spacing: 8) {
                            ProgressView().tint(Theme.goldDark)
                            Text(mode == .signIn ? "Signing in" : "Creating your account")
                                .font(TypeScale.caption)
                                .foregroundStyle(Theme.anchor.opacity(0.6))
                        }
                    }

                    privacyBlock

                    Button {
                        showServerSettings = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "server.rack").font(.system(size: 11, weight: .bold))
                            Text("Server: \(APIConfiguration.baseURL.host ?? "not set")")
                                .font(TypeScale.condensed(12, .bold))
                                .tracking(1)
                                .textCase(.uppercase)
                        }
                        .foregroundStyle(Theme.anchor.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(Metric.screenPadding)
                .padding(.top, 40)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $showServerSettings) { ServerAddressView() }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ticket Ledger").screenTitleStyle()
            Text("Your deadlines, on every device you carry.")
                .font(TypeScale.body)
                .foregroundStyle(Theme.anchor.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var modeChips: some View {
        HStack(spacing: 8) {
            ForEach(Mode.allCases, id: \.self) { option in
                Chip(title: option.title, selected: mode == option, count: nil) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = option
                        errorMessage = nil
                        fieldErrors = [:]
                    }
                }
            }
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Password")
                    .font(TypeScale.condensed(12, .bold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.anchor.opacity(0.55))
                Text("required")
                    .font(TypeScale.condensed(10, .bold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.terracotta)
                Spacer()
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.goldDark)
                }
                .buttonStyle(.plain)
            }

            Group {
                if showPassword {
                    TextField("", text: $password)
                } else {
                    SecureField("", text: $password)
                }
            }
            .font(TypeScale.body)
            .foregroundStyle(Theme.anchor)
            .tint(Theme.goldDark)
            .textContentType(mode == .register ? .newPassword : .password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.card))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        fieldErrors["password"] != nil ? Theme.terracotta : Theme.gold.opacity(0.45),
                        lineWidth: fieldErrors["password"] != nil ? 2 : 1.5
                    )
            )

            if let message = fieldErrors["password"] ?? fieldErrors["newPassword"] {
                Text(message)
                    .font(TypeScale.caption)
                    .foregroundStyle(Theme.terracotta)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var privacyBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("What Leaves This Device")
            GoldRule()
            ForEach([
                "Your records travel over HTTPS to your own server and nowhere else.",
                "Photos of notices and evidence stay on this device. They are never uploaded.",
                "The app still works with no signal: everything is written here first and synced after.",
                "Deleting your account removes every record from the server and from this device.",
            ], id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.goldDark)
                        .padding(.top, 3)
                    Text(line)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.anchor.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Actions

    private func submit() {
        errorMessage = nil
        fieldErrors = [:]
        let address = email.trimmingCharacters(in: .whitespaces).lowercased()

        Task {
            do {
                if mode == .signIn {
                    try await session.signIn(email: address, password: password)
                } else {
                    try await session.register(
                        email: address,
                        password: password,
                        displayName: displayName.trimmingCharacters(in: .whitespaces)
                    )
                }
                password = ""
            } catch let error as APIError {
                fieldErrors = error.fieldErrors
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Server address

struct ServerAddressView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var address = APIConfiguration.baseURL.absoluteString
    @State private var problem: String?
    @State private var checking = false
    @State private var reachable: Bool?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.page.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Where your records are kept. Point this at your own server; the app talks to nothing else.")
                            .font(TypeScale.body)
                            .foregroundStyle(Theme.anchor.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)

                        LedgerTextField(
                            label: "API Address",
                            placeholder: "https://api.example.com",
                            text: $address,
                            error: problem,
                            hint: "Plain http is only accepted for a server on this machine. Anything else has to be https.",
                            keyboard: .URL,
                            autocapitalization: .never
                        )

                        if let reachable {
                            WarningLine(
                                text: reachable
                                    ? "The server answered. You can sign in."
                                    : "No answer from that address.",
                                color: reachable ? Theme.green : Theme.terracotta,
                                icon: reachable ? "checkmark.circle" : "xmark.circle"
                            )
                        }

                        MetalButton("Save Address", enabled: !checking) { save() }
                        SecondaryButton("Test Connection", icon: "antenna.radiowaves.left.and.right", enabled: !checking) {
                            test()
                        }
                    }
                    .padding(Metric.screenPadding)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Server")
                        .font(TypeScale.condensed(19, .black))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.anchor)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .font(TypeScale.caption)
                        .foregroundStyle(Theme.goldDark)
                }
            }
            .toolbarBackground(Theme.page, for: .navigationBar)
        }
    }

    private func save() {
        problem = APIConfiguration.setBaseURL(address)
        if problem == nil { dismiss() }
    }

    private func test() {
        problem = APIConfiguration.setBaseURL(address)
        guard problem == nil else { return }
        checking = true
        reachable = nil
        Task {
            reachable = (try? await APIClient.shared.health()) == true
            checking = false
        }
    }
}
