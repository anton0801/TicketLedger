//
//  DriversView.swift
//  TicketLedger
//
//  Local profiles of whoever drives the cars. The app shows facts by driver —
//  it does not issue invoices and does not create debts between people.
//

import SwiftUI

struct DriversView: View {
    @Environment(Store.self) private var store
    @State private var showForm = false
    @State private var now = Date()

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Drivers").screenTitleStyle()
                        Text("Who drives which car, and what came in on their watch")
                            .font(TypeScale.caption)
                            .foregroundStyle(Theme.anchor.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    MetalButton("Add Driver", icon: "plus") { showForm = true }

                    if store.drivers.isEmpty {
                        EmptyState(
                            title: "No Drivers",
                            message: "Add the people who use your cars. With two or more on one car, recording who was driving becomes required on every fine.",
                            actionTitle: "Add Driver",
                            action: { showForm = true }
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader("By Driver")
                            GoldRule()
                        }
                        VStack(spacing: 14) {
                            ForEach(Array(store.drivers.enumerated()), id: \.element.id) { index, driver in
                                NavigationLink(value: Route.driver(driver.id)) {
                                    DriverToken(driver: driver, now: now)
                                }
                                .buttonStyle(.plain)
                                .tokenAppear(index)
                            }
                        }
                        Text("These are facts, not invoices. The app does not settle anything between people.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.anchor.opacity(0.45))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Metric.screenPadding)
                .padding(.bottom, Metric.contentBottomInset)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.page, for: .navigationBar)
        .sheet(isPresented: $showForm) { DriverFormView(driver: nil) }
    }
}

// MARK: - Token

struct DriverToken: View {
    @Environment(Store.self) private var store
    var driver: Driver
    var now: Date

    private var fines: [Fine] { store.fines(of: driver) }

    private var totalAmount: Double {
        fines.reduce(0) { $0 + $1.amount }
    }

    private var paidByThem: Double {
        store.data.payments
            .filter { $0.paidByDriverID == driver.id }
            .reduce(0) { $0 + $1.amountPaid }
    }

    private var licenceClock: Clock? {
        guard let until = driver.licenceValidUntil else { return nil }
        return Clock(
            kind: .documentExpiry,
            deadline: Fmt.cal.startOfDay(for: until),
            daysLeft: Fmt.days(from: now, to: until),
            span: 365
        )
    }

    var body: some View {
        TokenCard(status: licenceClock?.isExpired == true ? Theme.maroon : Theme.goldDark) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(driver.name)
                            .font(TypeScale.condensed(20, .black))
                            .tracking(0.5)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.anchor)
                        Text(subtitle)
                            .font(TypeScale.caption)
                            .foregroundStyle(Theme.anchor.opacity(0.55))
                    }
                    Spacer()
                    if let licenceClock, licenceClock.isExpired {
                        Text("Licence expired")
                            .font(TypeScale.condensed(11, .black))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.maroon)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 76)
                    }
                }

                GoldRule(opacity: 0.25)

                HStack(spacing: 0) {
                    stat(value: "\(fines.count)", label: "Fines")
                    stat(value: Fmt.amount(totalAmount), label: "Total issued")
                    stat(value: Fmt.amount(paidByThem), label: "Paid by them")
                }
            }
        }
    }

    private var subtitle: String {
        var parts = [driver.relationship.title]
        if let vehicle = store.vehicle(driver.usualVehicleID) {
            parts.append(vehicle.plate.uppercased())
        }
        if let until = driver.licenceValidUntil {
            parts.append("licence to \(Fmt.shortDate(until))")
        }
        return parts.joined(separator: " · ")
    }

    private func stat(value: String, label: String) -> some View {
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

struct DriverDetailView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var driverID: UUID

    @State private var showEdit = false
    @State private var showDelete = false
    @State private var now = Date()

    private var driver: Driver? { store.driver(driverID) }

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()

            if let driver {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(driver.name).screenTitleStyle()
                            Text(driver.relationship.title)
                                .font(TypeScale.condensed(14, .bold))
                                .tracking(2)
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.goldDark)
                        }
                        .padding(.top, 4)

                        if let until = driver.licenceValidUntil {
                            let days = Fmt.days(from: now, to: until)
                            if days < 0 {
                                WarningLine(
                                    text: "Licence expired \(Fmt.dayCount(-days)) ago, on \(Fmt.date(until)).",
                                    color: Theme.maroon
                                )
                            } else if days <= 60 {
                                WarningLine(
                                    text: "Licence valid for \(Fmt.dayCount(days)) more, until \(Fmt.date(until)).",
                                    color: Theme.terracotta,
                                    icon: "person.text.rectangle"
                                )
                            }
                        }

                        detailsBlock(driver)
                        finesBlock(driver)
                        paymentsBlock(driver)

                        DangerButton("Delete Driver", icon: "trash") { showDelete = true }
                        Text("Fines keep the name that was recorded at the time, so history stays readable.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.anchor.opacity(0.45))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, Metric.screenPadding)
                    .padding(.bottom, Metric.contentBottomInset)
                }
            } else {
                EmptyState(
                    title: "This Driver Is Gone",
                    message: "The profile was removed.",
                    actionTitle: "Back",
                    action: { dismiss() }
                )
                .padding(Metric.screenPadding)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if driver != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEdit = true
                    } label: {
                        Text("Edit").font(TypeScale.caption).foregroundStyle(Theme.goldDark)
                    }
                }
            }
        }
        .toolbarBackground(Theme.page, for: .navigationBar)
        .sheet(isPresented: $showEdit) {
            if let driver { DriverFormView(driver: driver) }
        }
        .alert("Delete this driver?", isPresented: $showDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let driver { store.deleteDriver(driver) }
                dismiss()
            }
        } message: {
            Text("Fines keep the recorded name. Any licence document for this person is removed.")
        }
    }

    private func detailsBlock(_ driver: Driver) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("The Record")
            GoldRule()
            VStack(spacing: 0) {
                DetailRow(
                    label: "Usual Vehicle",
                    value: store.vehicle(driver.usualVehicleID).map { "\($0.plate.uppercased()) \($0.makeModel)" } ?? "Not set",
                    mono: true
                )
                DetailRow(
                    label: "Licence Until",
                    value: driver.licenceValidUntil.map(Fmt.date) ?? "Not recorded"
                )
                if !driver.notes.isEmpty {
                    DetailRow(label: "Notes", value: driver.notes)
                }
            }
        }
    }

    private func finesBlock(_ driver: Driver) -> some View {
        let fines = store.fines(of: driver).sorted { $0.dateReceived > $1.dateReceived }
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Fines on Their Watch", trailing: fines.isEmpty ? nil : "\(fines.count)")
            GoldRule()
            if fines.isEmpty {
                Text("Nothing recorded with this driver.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.anchor.opacity(0.6))
            } else {
                VStack(spacing: 12) {
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
    }

    private func paymentsBlock(_ driver: Driver) -> some View {
        let payments = store.data.payments
            .filter { $0.paidByDriverID == driver.id }
            .sorted { $0.date > $1.date }
        let total = payments.reduce(0) { $0 + $1.amountPaid }

        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Paid By Them", trailing: payments.isEmpty ? nil : Fmt.money(total, store.currency))
            GoldRule()
            if payments.isEmpty {
                Text("No payments recorded under this name.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.anchor.opacity(0.6))
            } else {
                VStack(spacing: 12) {
                    ForEach(payments) { payment in
                        PaymentRow(payment: payment)
                    }
                }
            }
        }
    }
}

// MARK: - Form

struct DriverFormView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var driver: Driver?

    @State private var draft = Driver()
    @State private var saving = false
    @State private var showValidation = false

    private var nameTrimmed: String { draft.name.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !nameTrimmed.isEmpty }

    var body: some View {
        FormScaffold(
            title: driver == nil ? "Add Driver" : "Edit Driver",
            saveTitle: driver == nil ? "Save Driver" : "Save Changes",
            canSave: canSave,
            saving: saving,
            onSave: save
        ) {
            FormBlock(title: "Who") {
                LedgerTextField(
                    label: "Name",
                    placeholder: "As you refer to them",
                    text: $draft.name,
                    required: true,
                    error: showValidation && nameTrimmed.isEmpty ? "A name is required." : nil
                )
                LedgerPicker(
                    label: "Relationship",
                    selection: $draft.relationship,
                    options: DriverRelationship.allCases,
                    title: \.title
                )
                LedgerOptionalPicker(
                    label: "Usual Vehicle",
                    selection: $draft.usualVehicleID,
                    options: store.vehicles,
                    title: { "\($0.plate.uppercased()) \($0.makeModel)" },
                    noneTitle: "Not set",
                    hint: "Two or more drivers on one car makes \"driver at the time\" required on its fines."
                )
            }

            FormBlock(title: "Licence") {
                LedgerOptionalDateField(
                    label: "Licence Valid Until",
                    date: $draft.licenceValidUntil,
                    hint: "Tracked as a document, so it joins the queue and the calendar."
                )
                LedgerTextArea(label: "Notes", text: $draft.notes)
            }
        }
        .onAppear {
            if let driver { draft = driver }
        }
    }

    private func save() {
        showValidation = true
        guard canSave, !saving else { return }
        saving = true
        var copy = draft
        copy.name = nameTrimmed
        store.upsert(copy)
        // A licence date is kept as a document so it lands in the same queue.
        if let until = copy.licenceValidUntil {
            if var existing = store.data.documents.first(where: { $0.personID == copy.id && $0.type == .drivingLicence }) {
                existing.validUntil = until
                store.upsert(existing)
            } else {
                var document = DocumentItem()
                document.type = .drivingLicence
                document.personID = copy.id
                document.validUntil = until
                store.upsert(document)
            }
        } else if let existing = store.data.documents.first(where: { $0.personID == copy.id && $0.type == .drivingLicence }) {
            store.deleteDocument(existing)
        }
        dismiss()
    }
}
