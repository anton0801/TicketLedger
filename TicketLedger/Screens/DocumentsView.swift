//
//  DocumentsView.swift
//  TicketLedger
//
//  Everything with an expiry date. Renewals join the same queue as fines and
//  are ordered by the same logic: a missed inspection costs more than an unpaid
//  parking ticket.
//

import SwiftUI

struct DocumentsView: View {
    @Environment(Store.self) private var store
    @State private var path = NavigationPath()
    @State private var showForm = false
    @State private var filter: DocumentType?
    @State private var now = Date()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.page.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        HStack(spacing: 10) {
                            MetalButton("Add Document", icon: "plus") { showForm = true }
                            SecondaryButton("Calendar", icon: "calendar") { path.append(Route.calendar) }
                        }
                        .frame(height: Metric.buttonHeight)

                        if store.documents.isEmpty {
                            EmptyState(
                                title: "Nothing With a Date",
                                message: "Insurance, inspection, road tax, licences, permits — anything that expires. They queue by urgency next to your fines.",
                                actionTitle: "Add Document",
                                action: { showForm = true }
                            )
                        } else {
                            typeChips
                            documentList
                        }

                        if !store.renewals.isEmpty {
                            renewalHistory
                        }

                        DeadlineDisclaimer().padding(.top, 4)
                    }
                    .padding(.horizontal, Metric.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, Metric.contentBottomInset)
                }
                .refreshable { now = Date() }
            }
            .ledgerDestinations()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showForm) { DocumentFormView(document: nil) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Documents").screenTitleStyle()
            Text(headline)
                .font(TypeScale.caption)
                .foregroundStyle(Theme.anchor.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var headline: String {
        let expired = store.documents.filter { DeadlineEngine.clock(for: $0, now: now).isExpired }.count
        if expired > 0 {
            return "\(expired) expired · \(store.documents.count) tracked"
        }
        if let next = store.documents.map({ DeadlineEngine.clock(for: $0, now: now) }).min(by: { $0.daysLeft < $1.daysLeft }) {
            return "Next expiry \(Fmt.relativeDays(next.daysLeft)) · \(store.documents.count) tracked"
        }
        return "\(store.documents.count) tracked"
    }

    private var typeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "All", selected: filter == nil, count: store.documents.count) { filter = nil }
                ForEach(DocumentType.allCases) { type in
                    let count = store.documents.filter { $0.type == type }.count
                    if count > 0 {
                        Chip(title: type.shortTitle, selected: filter == type, count: count) {
                            filter = filter == type ? nil : type
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var documentList: some View {
        let items = filter == nil ? store.documents : store.documents.filter { $0.type == filter }
        return VStack(spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, document in
                Button {
                    path.append(Route.document(document.id))
                } label: {
                    DocumentToken(document: document, now: now)
                }
                .buttonStyle(.plain)
                .tokenAppear(index)
            }
        }
    }

    private var renewalHistory: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Renewed", trailing: "\(store.renewals.count)")
            GoldRule()
            VStack(spacing: 0) {
                ForEach(store.renewals.prefix(6)) { record in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(record.typeSnapshot.title) · \(record.subjectSnapshot)")
                                .font(TypeScale.condensed(14, .bold))
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.anchor)
                            Text("\(Fmt.date(record.previousValidUntil)) → \(Fmt.date(record.newValidUntil))")
                                .font(TypeScale.mono(12))
                                .foregroundStyle(Theme.anchor.opacity(0.5))
                        }
                        Spacer()
                        Text(record.onTime ? "On time" : "Late")
                            .font(TypeScale.condensed(11, .black))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundStyle(record.onTime ? Theme.green : Theme.terracotta)
                    }
                    .padding(.vertical, 10)
                    if record.id != store.renewals.prefix(6).last?.id { GoldRule(opacity: 0.2) }
                }
            }
        }
    }
}

// MARK: - Token

struct DocumentToken: View {
    @Environment(Store.self) private var store
    var document: DocumentItem
    var now: Date

    private var clock: Clock { DeadlineEngine.clock(for: document, now: now) }

    private var statusColor: Color {
        if clock.isExpired { return document.type.expiryIsSerious ? Theme.maroon : Theme.terracotta }
        if clock.daysLeft <= 7 { return Theme.terracotta }
        if clock.daysLeft <= 30 { return Theme.gold }
        return Theme.green
    }

    var body: some View {
        TokenCard(status: statusColor) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: document.type.icon)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.goldDark)
                            Text(document.type.title)
                                .font(TypeScale.condensed(17, .black))
                                .tracking(0.5)
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.anchor)
                        }
                        Text(store.subject(for: document))
                            .font(TypeScale.mono(12))
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.anchor.opacity(0.55))
                    }
                    Spacer()
                    RingGauge(
                        progress: clock.isExpired ? 1 : clock.progress,
                        value: clock.isExpired ? "\(-clock.daysLeft)" : "\(clock.daysLeft)",
                        label: clock.isExpired ? "Overdue" : "Valid",
                        caption: "days",
                        tint: clock.isExpired ? statusColor : (clock.daysLeft <= 30 ? statusColor : nil),
                        diameter: 70
                    )
                }

                HStack {
                    Text(clock.isExpired ? "Expired" : "Valid until")
                        .font(TypeScale.condensed(12, .bold))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.anchor.opacity(0.5))
                    Text(Fmt.date(document.validUntil))
                        .font(TypeScale.condensed(15, .black))
                        .foregroundStyle(clock.isExpired ? statusColor : Theme.anchor)
                    Spacer()
                    if let cost = document.cost, cost > 0 {
                        Text(Fmt.money(cost, store.currency))
                            .font(TypeScale.number(18))
                            .foregroundStyle(Theme.anchor.opacity(0.6))
                    }
                }

                if clock.isExpired && document.type.expiryIsSerious {
                    WarningLine(
                        text: "Driving on an expired \(document.type.title.lowercased()) is usually the expensive kind of late. It sits above unpaid fines in the queue.",
                        color: Theme.maroon
                    )
                }
            }
        }
    }
}

// MARK: - Detail

struct DocumentDetailView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var documentID: UUID

    @State private var showEdit = false
    @State private var showRenew = false
    @State private var showPayment = false
    @State private var showDelete = false
    @State private var now = Date()

    private var document: DocumentItem? { store.document(documentID) }

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()

            if let document {
                let clock = DeadlineEngine.clock(for: document, now: now)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(document.type.title).screenTitleStyle()
                            Text(store.subject(for: document))
                                .font(TypeScale.mono(15))
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.goldDark)
                        }
                        .padding(.top, 4)

                        HStack {
                            RingGauge(
                                progress: clock.isExpired ? 1 : clock.progress,
                                value: clock.isExpired ? "\(-clock.daysLeft)" : "\(clock.daysLeft)",
                                label: clock.isExpired ? "Days overdue" : "Days valid",
                                caption: nil,
                                tint: clock.isExpired ? Theme.maroon : nil,
                                diameter: 120
                            )
                            Spacer()
                            VStack(alignment: .leading, spacing: 8) {
                                Text(clock.isExpired ? "Expired on" : "Valid until")
                                    .font(TypeScale.condensed(12, .bold))
                                    .tracking(1.5)
                                    .textCase(.uppercase)
                                    .foregroundStyle(Theme.anchor.opacity(0.5))
                                Text(Fmt.date(document.validUntil))
                                    .font(TypeScale.condensed(24, .black))
                                    .foregroundStyle(clock.isExpired ? Theme.maroon : Theme.anchor)
                                if let from = document.validFrom {
                                    Text("From \(Fmt.date(from))")
                                        .font(TypeScale.caption)
                                        .foregroundStyle(Theme.anchor.opacity(0.5))
                                }
                            }
                            Spacer()
                        }

                        if clock.isExpired {
                            WarningLine(
                                text: "Expired \(Fmt.dayCount(-clock.daysLeft)) ago. In the queue this sits above fines that still have days left.",
                                color: document.type.expiryIsSerious ? Theme.maroon : Theme.terracotta
                            )
                        }

                        VStack(spacing: 10) {
                            MetalButton("Record Renewal", icon: "arrow.clockwise") { showRenew = true }
                            HStack(spacing: 10) {
                                SecondaryButton("Record Payment", icon: "creditcard") { showPayment = true }
                                SecondaryButton("Edit", icon: "square.and.pencil") { showEdit = true }
                            }
                        }

                        detailsBlock(document)
                        paymentsBlock(document)
                        renewalsBlock(document)

                        if document.photoName != nil {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeader("Photo")
                                GoldRule()
                                StoredImageView(name: document.photoName, height: 220)
                            }
                        }

                        DangerButton("Delete Document", icon: "trash") { showDelete = true }
                        DeadlineDisclaimer()
                    }
                    .padding(.horizontal, Metric.screenPadding)
                    .padding(.bottom, Metric.contentBottomInset)
                }
            } else {
                EmptyState(
                    title: "This Document Is Gone",
                    message: "The record was removed.",
                    actionTitle: "Back",
                    action: { dismiss() }
                )
                .padding(Metric.screenPadding)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.page, for: .navigationBar)
        .sheet(isPresented: $showEdit) {
            if let document { DocumentFormView(document: document) }
        }
        .sheet(isPresented: $showRenew) {
            if let document { RenewDocumentView(document: document) }
        }
        .sheet(isPresented: $showPayment) {
            if let document { DocumentPaymentFormView(document: document, payment: nil) }
        }
        .alert("Delete this document?", isPresented: $showDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let document { store.deleteDocument(document) }
                dismiss()
            }
        } message: {
            Text("Its renewal history stays in the ledger. Payments recorded against it are removed.")
        }
    }

    private func detailsBlock(_ document: DocumentItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("The Record")
            GoldRule()
            VStack(spacing: 0) {
                if !document.reference.isEmpty {
                    DetailRow(label: "Reference", value: document.reference, mono: true)
                }
                DetailRow(label: "Valid Until", value: Fmt.date(document.validUntil))
                if let from = document.validFrom {
                    DetailRow(label: "Valid From", value: Fmt.date(from))
                }
                DetailRow(
                    label: "Cost",
                    value: document.cost.map { Fmt.money($0, store.currency) } ?? "Not recorded"
                )
                DetailRow(
                    label: "Reminder",
                    value: document.reminderDays.map { "\($0) days before" } ?? "Off"
                )
                if let renewed = document.renewedAt {
                    DetailRow(label: "Last Renewed", value: Fmt.date(renewed))
                }
                if !document.notes.isEmpty {
                    DetailRow(label: "Notes", value: document.notes)
                }
            }
        }
    }

    @ViewBuilder
    private func paymentsBlock(_ document: DocumentItem) -> some View {
        let payments = store.payments(forDocument: document.id)
        if !payments.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("Payments", trailing: Fmt.money(payments.reduce(0) { $0 + $1.amountPaid }, store.currency))
                GoldRule()
                VStack(spacing: 12) {
                    ForEach(payments) { PaymentRow(payment: $0) }
                }
            }
        }
    }

    @ViewBuilder
    private func renewalsBlock(_ document: DocumentItem) -> some View {
        let records = store.renewals.filter { $0.documentID == document.id }
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("Renewal History", trailing: "\(records.count)")
                GoldRule()
                VStack(spacing: 0) {
                    ForEach(records) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(Fmt.date(record.previousValidUntil)) → \(Fmt.date(record.newValidUntil))")
                                    .font(TypeScale.mono(13))
                                    .foregroundStyle(Theme.anchor)
                                Text("Recorded \(Fmt.date(record.renewedOn))")
                                    .font(TypeScale.caption)
                                    .foregroundStyle(Theme.anchor.opacity(0.5))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                if let cost = record.cost {
                                    Text(Fmt.money(cost, store.currency))
                                        .font(TypeScale.number(17))
                                        .foregroundStyle(Theme.anchor.opacity(0.7))
                                }
                                Text(record.onTime ? "On time" : "Late")
                                    .font(TypeScale.condensed(11, .black))
                                    .tracking(1)
                                    .textCase(.uppercase)
                                    .foregroundStyle(record.onTime ? Theme.green : Theme.terracotta)
                            }
                        }
                        .padding(.vertical, 10)
                        if record.id != records.last?.id { GoldRule(opacity: 0.2) }
                    }
                }
            }
        }
    }
}

// MARK: - Form

struct DocumentFormView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var document: DocumentItem?

    @State private var draft = DocumentItem()
    @State private var cost: Double?
    @State private var remindersOn = true
    @State private var reminderDays = 30
    @State private var saving = false
    @State private var showValidation = false

    private var needsPerson: Bool { draft.type.isPersonal }

    private var subjectMissing: Bool {
        needsPerson ? draft.personID == nil : draft.vehicleID == nil
    }

    private var dateError: String? {
        guard let from = draft.validFrom else { return nil }
        return draft.validUntil < from ? "Valid until is before valid from — check both dates." : nil
    }

    private var canSave: Bool { !subjectMissing && dateError == nil }

    var body: some View {
        FormScaffold(
            title: document == nil ? "Add Document" : "Edit Document",
            saveTitle: document == nil ? "Save Document" : "Save Changes",
            canSave: canSave,
            saving: saving,
            onSave: save
        ) {
            FormBlock(title: "What It Is") {
                LedgerPicker(
                    label: "Document",
                    selection: $draft.type,
                    options: DocumentType.allCases,
                    title: \.title
                )
                if needsPerson {
                    LedgerOptionalPicker(
                        label: "Person",
                        selection: $draft.personID,
                        options: store.drivers,
                        title: \.name,
                        noneTitle: "Choose a person",
                        required: true,
                        error: showValidation && draft.personID == nil ? "This document belongs to a person." : nil
                    )
                } else {
                    LedgerOptionalPicker(
                        label: "Vehicle",
                        selection: $draft.vehicleID,
                        options: store.vehicles,
                        title: { "\($0.plate.uppercased()) \($0.makeModel)" },
                        noneTitle: "Choose a vehicle",
                        required: true,
                        error: showValidation && draft.vehicleID == nil ? "This document belongs to a vehicle." : nil
                    )
                }
                LedgerTextField(
                    label: "Reference",
                    placeholder: "Policy or certificate number",
                    text: $draft.reference,
                    mono: true
                )
            }

            FormBlock(title: "Dates") {
                LedgerOptionalDateField(label: "Valid From", date: $draft.validFrom)
                LedgerDateField(
                    label: "Valid Until",
                    date: $draft.validUntil,
                    hint: "This is the date the queue counts down to.",
                    error: dateError
                )
            }

            FormBlock(title: "Money and Reminders") {
                LedgerMoneyField(
                    label: "Cost",
                    value: $cost,
                    currency: store.currency,
                    hint: "What the last renewal cost, if you know it."
                )
                LedgerToggle(
                    label: "Renewal reminder",
                    hint: "A local reminder ahead of the expiry date, plus a week and a day before.",
                    isOn: $remindersOn
                )
                if remindersOn {
                    LedgerDaysField(label: "Remind Days Before", days: $reminderDays, range: 1...180)
                }
            }

            FormBlock(title: "Extras") {
                PhotoField(label: "Photo", photoName: $draft.photoName)
                LedgerTextArea(label: "Notes", text: $draft.notes)
            }
        }
        .onAppear(perform: prepare)
    }

    private func prepare() {
        if let document {
            draft = document
            cost = document.cost
            remindersOn = document.reminderDays != nil
            reminderDays = document.reminderDays ?? 30
        } else {
            draft.validUntil = Fmt.addDays(365, to: Date())
            if store.vehicles.count == 1 { draft.vehicleID = store.vehicles.first?.id }
        }
    }

    private func save() {
        showValidation = true
        guard canSave, !saving else { return }
        saving = true
        var copy = draft
        copy.cost = cost
        copy.reminderDays = remindersOn ? reminderDays : nil
        if copy.type.isPersonal {
            copy.vehicleID = nil
        } else {
            copy.personID = nil
        }
        store.upsert(copy)
        dismiss()
    }
}

// MARK: - Renew

struct RenewDocumentView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var document: DocumentItem

    @State private var newValidUntil = Date()
    @State private var cost: Double?
    @State private var renewedOn = Date()
    @State private var saving = false

    private var canSave: Bool {
        Fmt.cal.startOfDay(for: newValidUntil) > Fmt.cal.startOfDay(for: document.validUntil)
    }

    var body: some View {
        FormScaffold(
            title: "Record Renewal",
            saveTitle: "Record Renewal",
            canSave: canSave,
            saving: saving,
            onSave: save
        ) {
            TokenCard(status: Theme.green, showsHoles: false) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(document.type.title) · \(store.subject(for: document))")
                        .font(TypeScale.condensed(16, .black))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.anchor)
                    Text("Currently valid until \(Fmt.date(document.validUntil))")
                        .font(TypeScale.body)
                        .foregroundStyle(Theme.anchor.opacity(0.7))
                }
            }

            FormBlock(
                title: "New Period",
                footnote: "The old period goes to history, marked on time or late against the date you renewed."
            ) {
                LedgerDateField(
                    label: "New Valid Until",
                    date: $newValidUntil,
                    error: canSave ? nil : "The new date has to be after \(Fmt.date(document.validUntil))."
                )
                LedgerDateField(label: "Renewed On", date: $renewedOn, range: ...Date())
                LedgerMoneyField(label: "Cost", value: $cost, currency: store.currency)
                if Fmt.cal.startOfDay(for: renewedOn) > Fmt.cal.startOfDay(for: document.validUntil) {
                    WarningLine(
                        text: "Renewed \(Fmt.dayCount(Fmt.days(from: document.validUntil, to: renewedOn))) after it expired. This is recorded as late and shows up in Insights.",
                        color: Theme.terracotta
                    )
                }
            }
        }
        .onAppear {
            newValidUntil = Fmt.addDays(365, to: document.validUntil)
            cost = document.cost
        }
    }

    private func save() {
        guard canSave, !saving else { return }
        saving = true
        store.renew(document, newValidUntil: newValidUntil, cost: cost, on: renewedOn)
        dismiss()
    }
}
