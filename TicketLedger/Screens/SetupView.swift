//
//  SetupView.swift
//  TicketLedger
//
//  Cannot be finished without one vehicle and a confirmed set of deadline rules.
//

import SwiftUI

struct SetupView: View {
    @Environment(Store.self) private var store

    @State private var displayName = ""
    @State private var plate = ""
    @State private var makeModel = ""
    @State private var country = Locale.current.region?.identifier ?? ""
    @State private var rules = DeadlineRules.suggested
    @State private var currency = Locale.current.currency?.identifier ?? "EUR"
    @State private var rulesConfirmed = false
    @State private var saving = false
    @State private var showRulesError = false
    @State private var showPlateError = false

    private var plateTrimmed: String { plate.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canSave: Bool {
        !plateTrimmed.isEmpty && rules.isValid && rulesConfirmed && !saving
    }

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Initial Setup").screenTitleStyle()
                        Text("Four things, then the ledger is yours. Everything here can be changed later in Settings.")
                            .font(TypeScale.body)
                            .foregroundStyle(Theme.anchor.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    FormBlock(title: "You") {
                        LedgerTextField(
                            label: "Your Display Name",
                            placeholder: "Optional",
                            text: $displayName,
                            hint: "Used on your own screens and on exported summaries. It stays on this device."
                        )
                    }

                    FormBlock(title: "First Vehicle") {
                        LedgerTextField(
                            label: "Plate",
                            placeholder: "AB 123 CD",
                            text: $plate,
                            mono: true,
                            required: true,
                            error: showPlateError && plateTrimmed.isEmpty
                                ? "A plate is required — the ledger is organised by vehicle."
                                : nil
                        )
                        LedgerTextField(
                            label: "Make and Model",
                            placeholder: "Optional",
                            text: $makeModel
                        )
                        LedgerTextField(
                            label: "Country of Registration",
                            placeholder: "e.g. PL",
                            text: $country,
                            mono: true
                        )
                    }

                    FormBlock(
                        title: "Deadline Rules",
                        footnote: "These periods differ by country and by type of fine. Set them from the notice you received — the app does not know them for you."
                    ) {
                        LedgerDaysField(
                            label: "Discount Window Days",
                            days: $rules.discountWindowDays,
                            hint: "How long a reduced amount stays available after you receive the notice."
                        )
                        LedgerDaysField(
                            label: "Appeal Window Days",
                            days: $rules.appealWindowDays,
                            hint: "How long you have to contest it. This is usually the shortest of the three."
                        )
                        LedgerDaysField(
                            label: "Enforcement After Days",
                            days: $rules.enforcementAfterDays,
                            range: 1...900,
                            hint: "After this, the debt is normally passed on for enforcement and costs are added."
                        )

                        Button {
                            rulesConfirmed.toggle()
                            if rulesConfirmed { showRulesError = false }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: rulesConfirmed ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(rulesConfirmed ? Theme.goldDark : Theme.anchor.opacity(0.35))
                                Text("I have set these from my own notice or local rule, not from the app's suggestion.")
                                    .font(TypeScale.caption)
                                    .foregroundStyle(Theme.anchor.opacity(0.75))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .buttonStyle(.plain)

                        if showRulesError {
                            Text("Confirm the deadline rules before continuing.")
                                .font(TypeScale.caption)
                                .foregroundStyle(Theme.terracotta)
                        }
                    }

                    FormBlock(title: "Currency") {
                        LedgerPicker(
                            label: "Currency",
                            selection: $currency,
                            options: SetupView.currencyOptions,
                            title: { code in
                    let symbol = Fmt.currencySymbol(code)
                    return symbol == code ? code : "\(code) · \(symbol)"
                },
                            hint: "Used for every amount in the app. No conversion happens anywhere."
                        )
                    }

                    DeadlineDisclaimer()

                    MetalButton("Save Setup", enabled: canSave) { save() }

                    if plateTrimmed.isEmpty {
                        Text("One vehicle is needed before the ledger can open.")
                            .font(TypeScale.caption)
                            .foregroundStyle(Theme.anchor.opacity(0.5))
                    }
                }
                .padding(Metric.screenPadding)
                .padding(.top, 30)
                .padding(.bottom, 50)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func save() {
        guard !saving else { return }
        showPlateError = plateTrimmed.isEmpty
        guard rulesConfirmed else { showRulesError = true; return }
        guard !plateTrimmed.isEmpty, rules.isValid else { return }
        saving = true

        var vehicle = Vehicle()
        vehicle.plate = plateTrimmed.uppercased()
        vehicle.makeModel = makeModel.trimmingCharacters(in: .whitespacesAndNewlines)
        store.upsert(vehicle)

        var driver = Driver()
        driver.name = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Me"
            : displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        driver.relationship = .myself
        driver.usualVehicleID = vehicle.id
        store.upsert(driver)

        var settings = store.data.settings
        settings.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.country = country.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        settings.rules = rules
        settings.currencyCode = currency
        settings.setupDone = true
        store.settings = settings
        store.saveNow()
    }

    static let currencyOptions: [String] = {
        let common = ["EUR", "USD", "GBP", "PLN", "CZK", "RON", "HUF", "SEK", "NOK", "DKK", "CHF", "TRY", "UAH", "KZT", "GEL", "RSD", "BGN", "AED", "CAD", "AUD"]
        let local = Locale.current.currency?.identifier
        var list = common
        if let local, !list.contains(local) { list.insert(local, at: 0) }
        return list
    }()
}
