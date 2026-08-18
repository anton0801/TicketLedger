//
//  PaymentsView.swift
//  TicketLedger
//
//  Records the fact of a payment. The app never makes one. It does compare what
//  was paid with what was due, because that difference is the cost of
//  inattention over a year.
//

import SwiftUI

struct PaymentsView: View {
    @Environment(Store.self) private var store
    @State private var editing: PaymentRecord?
    @State private var showForm = false
    @State private var deleteTarget: PaymentRecord?

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Payments").screenTitleStyle()
                        Text("\(store.payments.count) recorded · \(Fmt.money(total, store.currency)) in total")
                            .font(TypeScale.caption)
                            .foregroundStyle(Theme.anchor.opacity(0.55))
                    }

                    if store.payments.isEmpty {
                        EmptyState(
                            title: "No Payments Recorded",
                            message: "Record a payment from a fine or a document. The app checks it against what was due on that date and keeps the receipt with the record.",
                            actionTitle: nil,
                            action: nil
                        )
                    } else {
                        if !discrepancies.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeader("Differences Found", trailing: "\(discrepancies.count)")
                                GoldRule()
                                Text("Not a reproach — this is the raw material for the Insights section.")
                                    .font(TypeScale.caption)
                                    .foregroundStyle(Theme.anchor.opacity(0.55))
                            }
                        }

                        VStack(spacing: 14) {
                            ForEach(Array(store.payments.enumerated()), id: \.element.id) { index, payment in
                                PaymentRow(payment: payment, onEdit: {
                                    editing = payment
                                    showForm = true
                                }, onDelete: {
                                    deleteTarget = payment
                                })
                                .tokenAppear(index)
                            }
                        }
                    }
                }
                .padding(Metric.screenPadding)
                .padding(.bottom, Metric.contentBottomInset)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.page, for: .navigationBar)
        .sheet(isPresented: $showForm) {
            if let editing, let fineID = editing.target.fineID, let fine = store.fine(fineID) {
                PaymentFormView(fine: fine, payment: editing)
            } else if let editing, let documentID = editing.target.documentID, let document = store.document(documentID) {
                DocumentPaymentFormView(document: document, payment: editing)
            }
        }
        .alert("Delete this payment record?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("Cancel", role: .cancel) { deleteTarget = nil }
            Button("Delete", role: .destructive) {
                if let deleteTarget { store.deletePayment(deleteTarget) }
                deleteTarget = nil
            }
        } message: {
            Text("The fine itself is not changed. Only this record and its receipt photo are removed.")
        }
    }

    private var total: Double {
        store.payments.reduce(0) { $0 + $1.amountPaid }
    }

    private var discrepancies: [PaymentRecord] {
        store.payments.filter { $0.discrepancy != nil }
    }
}

// MARK: - Row

struct PaymentRow: View {
    @Environment(Store.self) private var store
    var payment: PaymentRecord
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        TokenCard(status: payment.discrepancy == nil ? Theme.green : Theme.terracotta, showsHoles: false) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(payment.subjectSnapshot.isEmpty ? "Payment" : payment.subjectSnapshot)
                            .font(TypeScale.mono(12))
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.anchor.opacity(0.55))
                            .lineLimit(2)
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text(Fmt.amount(payment.amountPaid))
                                .font(TypeScale.number(30))
                                .foregroundStyle(Theme.anchor)
                            Text(Fmt.currencySymbol(store.currency))
                                .font(TypeScale.condensed(13, .bold))
                                .foregroundStyle(Theme.anchor.opacity(0.45))
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(Fmt.date(payment.date))
                            .font(TypeScale.condensed(13, .bold))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.anchor.opacity(0.55))
                        Text(payment.method.title)
                            .font(TypeScale.caption)
                            .foregroundStyle(Theme.anchor.opacity(0.45))
                        if onEdit != nil || onDelete != nil {
                            Menu {
                                if let onEdit {
                                    Button {
                                        onEdit()
                                    } label: {
                                        Label("Edit", systemImage: "square.and.pencil")
                                    }
                                }
                                if let onDelete {
                                    Button(role: .destructive) {
                                        onDelete()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Theme.anchor.opacity(0.5))
                                    .frame(width: 30, height: 22)
                            }
                        }
                    }
                }

                if let delta = payment.discrepancy, let expected = payment.expectedAmount {
                    Text(discrepancyText(delta: delta, expected: expected))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(delta > 0 ? Theme.terracotta : Theme.gold)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !payment.reference.isEmpty {
                    DetailRow(label: "Reference", value: payment.reference, mono: true)
                }
                if !payment.paidByName.isEmpty || payment.paidByDriverID != nil {
                    DetailRow(label: "Paid By", value: paidByName)
                }
                if !payment.notes.isEmpty {
                    Text(payment.notes)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.anchor.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if payment.receiptPhotoName != nil {
                    StoredImageView(name: payment.receiptPhotoName, height: 120)
                }
            }
        }
    }

    private var paidByName: String {
        if let driver = store.driver(payment.paidByDriverID) { return driver.name }
        return payment.paidByName
    }

    private func discrepancyText(delta: Double, expected: Double) -> String {
        let code = store.currency
        if delta > 0 {
            return "You paid \(Fmt.money(payment.amountPaid, code)). \(Fmt.money(expected, code)) was due on that date — \(Fmt.money(delta, code)) more than needed."
        }
        return "You paid \(Fmt.money(payment.amountPaid, code)), which is \(Fmt.money(-delta, code)) less than the \(Fmt.money(expected, code)) due on that date. Check whether a balance is still open."
    }
}

// MARK: - Payment form for a fine

struct PaymentFormView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var fine: Fine
    var payment: PaymentRecord?

    @State private var amount: Double?
    @State private var date = Date()
    @State private var method: PaymentMethod = .card
    @State private var reference = ""
    @State private var receiptPhoto: String?
    @State private var paidByDriverID: UUID?
    @State private var paidByName = ""
    @State private var notes = ""
    @State private var closeFine = true
    @State private var saving = false
    @State private var showValidation = false

    private var expected: Double {
        DeadlineEngine.amountToday(for: fine, settings: store.data.settings, now: date)
    }

    private var canSave: Bool { (amount ?? 0) > 0 }

    var body: some View {
        FormScaffold(
            title: payment == nil ? "Record Payment" : "Edit Payment",
            saveTitle: payment == nil ? "Record Payment" : "Save Changes",
            canSave: canSave,
            saving: saving,
            onSave: save
        ) {
            TokenCard(status: Theme.green, showsHoles: false) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(fine.noticeNumber.isEmpty ? "NO NUMBER" : fine.noticeNumber)
                        .font(TypeScale.mono(13))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.goldDark)
                    Text("Due on \(Fmt.date(date)): \(Fmt.money(expected, store.currency))")
                        .font(TypeScale.body)
                        .foregroundStyle(Theme.anchor)
                    Text("The app records the payment. It does not make it.")
                        .font(TypeScale.caption)
                        .foregroundStyle(Theme.anchor.opacity(0.55))
                }
            }

            if showValidation && !canSave {
                WarningLine(text: "Enter the amount that actually left your account.")
            }

            FormBlock(title: "The Payment") {
                LedgerMoneyField(
                    label: "Amount Paid",
                    value: $amount,
                    currency: store.currency,
                    required: true
                )
                LedgerDateField(label: "Date", date: $date, range: ...Date())
                LedgerPicker(
                    label: "Method",
                    selection: $method,
                    options: PaymentMethod.allCases,
                    title: \.title
                )
                LedgerTextField(
                    label: "Reference",
                    placeholder: "Transaction or receipt number",
                    text: $reference,
                    mono: true
                )
                if let amount, abs(amount - expected) > 0.005 {
                    WarningLine(
                        text: amount > expected
                            ? "You paid \(Fmt.money(amount, store.currency)). \(Fmt.money(expected, store.currency)) was due on this date\(discountNote). The difference is kept for the Insights section."
                            : "That is \(Fmt.money(expected - amount, store.currency)) less than the \(Fmt.money(expected, store.currency)) due on this date. The fine may stay partly open.",
                        color: Theme.terracotta,
                        icon: "equal.circle"
                    )
                }
            }

            FormBlock(title: "Who and What") {
                LedgerOptionalPicker(
                    label: "Paid By",
                    selection: $paidByDriverID,
                    options: store.drivers,
                    title: { "\($0.name) · \($0.relationship.title)" },
                    noneTitle: "Someone not in the list"
                )
                if paidByDriverID == nil {
                    LedgerTextField(label: "Name", placeholder: "Who paid", text: $paidByName)
                }
                PhotoField(label: "Receipt Photo", photoName: $receiptPhoto)
                LedgerTextArea(label: "Notes", text: $notes)
            }

            if payment == nil {
                FormBlock(title: "The Fine") {
                    LedgerToggle(
                        label: "Close this fine as paid",
                        hint: "Turn off if this was a part payment or a deposit.",
                        isOn: $closeFine
                    )
                }
            }
        }
        .onAppear(perform: prepare)
    }

    private var discountNote: String {
        guard let discounted = fine.discountedAmount,
              let deadline = DeadlineEngine.discountDeadline(for: fine, settings: store.data.settings) else { return "" }
        let daysLeft = Fmt.days(from: date, to: deadline)
        if daysLeft >= 0 {
            return " — the discounted amount was \(Fmt.money(discounted, store.currency)) and the window was still open for \(Fmt.dayCount(daysLeft))"
        }
        return " — the discount had already run out on \(Fmt.date(deadline))"
    }

    private func prepare() {
        if let payment {
            amount = payment.amountPaid
            date = payment.date
            method = payment.method
            reference = payment.reference
            receiptPhoto = payment.receiptPhotoName
            paidByDriverID = payment.paidByDriverID
            paidByName = payment.paidByName
            notes = payment.notes
        } else {
            amount = expected
            paidByDriverID = fine.driverID ?? store.drivers.first?.id
        }
    }

    private func save() {
        showValidation = true
        guard canSave, !saving, let amount else { return }
        saving = true

        if var existing = payment {
            existing.amountPaid = amount
            existing.date = date
            existing.method = method
            existing.reference = reference
            existing.receiptPhotoName = receiptPhoto
            existing.paidByDriverID = paidByDriverID
            existing.paidByName = paidByName
            existing.notes = notes
            store.upsert(existing)
        } else {
            store.recordPayment(
                for: fine,
                amount: amount,
                date: date,
                method: method,
                reference: reference,
                receiptPhotoName: receiptPhoto,
                paidByDriverID: paidByDriverID,
                paidByName: paidByName,
                notes: notes,
                closeFine: closeFine
            )
        }
        dismiss()
    }
}

// MARK: - Payment form for a document renewal

struct DocumentPaymentFormView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var document: DocumentItem
    var payment: PaymentRecord?

    @State private var amount: Double?
    @State private var date = Date()
    @State private var method: PaymentMethod = .card
    @State private var reference = ""
    @State private var receiptPhoto: String?
    @State private var notes = ""
    @State private var saving = false

    var body: some View {
        FormScaffold(
            title: "Record Payment",
            saveTitle: "Record Payment",
            canSave: (amount ?? 0) > 0,
            saving: saving,
            onSave: save
        ) {
            FormBlock(title: "\(document.type.title) · \(store.subject(for: document))") {
                LedgerMoneyField(
                    label: "Amount Paid",
                    value: $amount,
                    currency: store.currency,
                    required: true
                )
                LedgerDateField(label: "Date", date: $date, range: ...Date())
                LedgerPicker(
                    label: "Method",
                    selection: $method,
                    options: PaymentMethod.allCases,
                    title: \.title
                )
                LedgerTextField(label: "Reference", placeholder: "Receipt number", text: $reference, mono: true)
                PhotoField(label: "Receipt Photo", photoName: $receiptPhoto)
                LedgerTextArea(label: "Notes", text: $notes)
            }
        }
        .onAppear {
            if let payment {
                amount = payment.amountPaid
                date = payment.date
                method = payment.method
                reference = payment.reference
                receiptPhoto = payment.receiptPhotoName
                notes = payment.notes
            } else {
                amount = document.cost
            }
        }
    }

    private func save() {
        guard let amount, amount > 0, !saving else { return }
        saving = true
        var record = payment ?? PaymentRecord(target: .document(document.id))
        record.subjectSnapshot = "\(document.type.title) · \(store.subject(for: document))"
        record.amountPaid = amount
        record.expectedAmount = document.cost
        record.date = date
        record.method = method
        record.reference = reference
        record.receiptPhotoName = receiptPhoto
        record.notes = notes
        store.upsert(record)
        dismiss()
    }
}
