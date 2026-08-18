//
//  FineFormView.swift
//  TicketLedger
//
//  Add by hand, or edit anything a scan read. Cannot be saved without a notice
//  number, a vehicle, a date and an amount.
//

import SwiftUI

struct FineFormView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// nil creates a new record.
    var fine: Fine?
    /// Values a scan proposed, so the form can show what was read.
    var scanned: ScanResult?

    @State private var draft = Fine()
    @State private var saving = false
    @State private var showValidation = false
    @State private var useCustomWindows = false
    @State private var customRules = DeadlineRules.suggested
    @State private var overrideDeadlines = false
    @State private var knowsEnforcementCost = false
    @State private var enforcementCost: Double?
    @State private var discounted: Double?
    @State private var amount: Double?

    private var isNew: Bool { fine == nil }

    var body: some View {
        FormScaffold(
            title: isNew ? "Add Fine" : "Edit Fine",
            saveTitle: isNew ? "Save Fine" : "Save Changes",
            canSave: validationErrors.isEmpty,
            saving: saving,
            onSave: save
        ) {
            if let scanned {
                ScanReadBackBlock(result: scanned)
            }

            if showValidation && !validationErrors.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(validationErrors, id: \.self) { error in
                        WarningLine(text: error)
                    }
                }
            }

            FormBlock(title: "The Notice") {
                LedgerTextField(
                    label: "Notice Number",
                    placeholder: "As printed",
                    text: $draft.noticeNumber,
                    mono: true,
                    required: true,
                    error: noticeError
                )
                LedgerOptionalPicker(
                    label: "Vehicle",
                    selection: $draft.vehicleID,
                    options: store.vehicles,
                    title: { vehicle in
                        let plate = vehicle.plate.uppercased()
                        return vehicle.makeModel.isEmpty ? plate : "\(plate) · \(vehicle.makeModel)"
                    },
                    noneTitle: "Choose a vehicle",
                    required: true,
                    error: draft.vehicleID == nil && showValidation ? "A fine belongs to a vehicle." : nil
                )
                LedgerDateField(
                    label: "Date of Offence",
                    date: $draft.dateOfOffence,
                    range: ...Date(),
                    hint: "The date on the notice, not the day you found it."
                )
                LedgerDateField(
                    label: "Date Received",
                    date: $draft.dateReceived,
                    range: ...Date(),
                    hint: "The three windows are counted from this date unless you override them below.",
                    error: dateError
                )
            }

            FormBlock(title: "The Money") {
                LedgerMoneyField(
                    label: "Amount",
                    value: $amount,
                    currency: store.currency,
                    required: true,
                    error: amountError
                )
                LedgerMoneyField(
                    label: "Discounted Amount",
                    value: $discounted,
                    currency: store.currency,
                    error: discountError,
                    hint: "The reduced figure for paying early, if the notice offers one. Leave empty if it does not."
                )
                if let amount, let discounted, discounted < amount {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                        Text("Paying in time saves \(Fmt.money(amount - discounted, store.currency)).")
                            .font(TypeScale.condensed(13, .bold))
                            .tracking(0.5)
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(Theme.green)
                }
            }

            FormBlock(title: "What and Where") {
                LedgerTextField(
                    label: "Article or Code",
                    placeholder: "e.g. 92.1",
                    text: $draft.article,
                    mono: true
                )
                LedgerTextField(
                    label: "Description",
                    placeholder: "Parking without a ticket",
                    text: $draft.details
                )
                LedgerTextField(
                    label: "Location",
                    placeholder: "Street, zone, city",
                    text: $draft.location,
                    hint: "Written the same way each time, this is what makes the Repeat Spots section work."
                )
                LedgerTextField(
                    label: "Issuing Authority",
                    placeholder: "Who sent it",
                    text: $draft.issuingAuthority
                )
            }

            FormBlock(
                title: "Driver at the Time",
                footnote: driverRequired
                    ? "If someone else was driving, the answer to \"pay or appeal\" is a different conversation. Record it now, not in three weeks."
                    : nil
            ) {
                LedgerOptionalPicker(
                    label: "Driver",
                    selection: $draft.driverID,
                    options: store.drivers,
                    title: { "\($0.name) · \($0.relationship.title)" },
                    noneTitle: driverRequired ? "Choose a driver" : "Not recorded",
                    required: driverRequired,
                    error: driverError
                )
            }

            FormBlock(
                title: "Deadlines",
                footnote: "These periods differ by country and by type of fine. Set them from the notice you received — the app does not know them for you."
            ) {
                LedgerToggle(
                    label: "Different windows for this notice",
                    hint: "Off means your Settings rules apply: \(store.data.settings.rules.discountWindowDays)/\(store.data.settings.rules.appealWindowDays)/\(store.data.settings.rules.enforcementAfterDays) days.",
                    isOn: $useCustomWindows
                )
                if useCustomWindows {
                    LedgerDaysField(label: "Discount Window Days", days: $customRules.discountWindowDays)
                    LedgerDaysField(label: "Appeal Window Days", days: $customRules.appealWindowDays)
                    LedgerDaysField(label: "Enforcement After Days", days: $customRules.enforcementAfterDays, range: 1...900)
                }

                LedgerToggle(
                    label: "Dates printed on the notice",
                    hint: "Use this when the notice states the exact dates. Entered dates always win over counted ones.",
                    isOn: $overrideDeadlines
                )
                if overrideDeadlines {
                    LedgerOptionalDateField(label: "Discount Ends", date: $draft.discountDeadlineOverride)
                    LedgerOptionalDateField(label: "Appeal Window Closes", date: $draft.appealDeadlineOverride)
                    LedgerOptionalDateField(label: "Enforcement From", date: $draft.enforcementDateOverride)
                }

                DeadlinePreview(
                    fine: previewFine,
                    settings: store.data.settings
                )
            }

            FormBlock(title: "Enforcement Costs") {
                LedgerToggle(
                    label: "I know what enforcement adds",
                    hint: "Leave this off if you do not. The app will show \"unknown amount added\" rather than invent a figure.",
                    isOn: $knowsEnforcementCost
                )
                if knowsEnforcementCost {
                    LedgerMoneyField(
                        label: "Added at Enforcement",
                        value: $enforcementCost,
                        currency: store.currency
                    )
                }
            }

            FormBlock(title: "Status and Records") {
                LedgerPicker(
                    label: "Status",
                    selection: $draft.status,
                    options: FineStatus.allCases,
                    title: \.title,
                    hint: "Discount running, appeal window open and enforcement are worked out from the dates — you do not set them here."
                )
                PhotoField(
                    label: "Photo of Notice",
                    photoName: $draft.noticePhotoName,
                    hint: "Kept on this device only."
                )
                LedgerTextArea(label: "Notes", text: $draft.notes)
            }

            if let existing = duplicate {
                WarningLine(
                    text: "Notice \(existing.noticeNumber) is already in the ledger, dated \(Fmt.date(existing.dateOfOffence)). If this is the same notice, edit that one instead. If it is genuinely a second notice, a duplicate is itself a ground for appeal.",
                    color: Theme.terracotta
                )
            }

            if soldWarning {
                WarningLine(
                    text: "This fine is dated after you sold the car. That is usually a reason to appeal, not to pay.",
                    color: Theme.maroon
                )
            }
        }
        .onAppear(perform: prepare)
    }

    // MARK: Setup

    private func prepare() {
        if let fine {
            draft = fine
            amount = fine.amount
            discounted = fine.discountedAmount
            useCustomWindows = fine.rulesOverride != nil
            customRules = fine.rulesOverride ?? store.data.settings.rules
            overrideDeadlines = fine.discountDeadlineOverride != nil
                || fine.appealDeadlineOverride != nil
                || fine.enforcementDateOverride != nil
            knowsEnforcementCost = fine.enforcementExtraCost != nil
            enforcementCost = fine.enforcementExtraCost
        } else {
            var new = Fine()
            new.vehicleID = store.vehicles.count == 1 ? store.vehicles.first?.id : nil
            if let scanned {
                if let number = scanned.noticeNumber { new.noticeNumber = number }
                if let value = scanned.amount { amount = value }
                if let value = scanned.discountedAmount { discounted = value }
                if let date = scanned.date { new.dateOfOffence = date }
                if let article = scanned.article { new.article = article }
                if let plate = scanned.plate,
                   let match = store.vehicles.first(where: {
                       $0.plate.replacingOccurrences(of: " ", with: "").uppercased()
                           == plate.replacingOccurrences(of: " ", with: "").uppercased()
                   }) {
                    new.vehicleID = match.id
                }
                new.noticePhotoName = scanned.photoName
            }
            if store.drivers.count == 1 { new.driverID = store.drivers.first?.id }
            customRules = store.data.settings.rules
            draft = new
        }
    }

    // MARK: Validation

    private var driverRequired: Bool { store.requiresDriver(for: draft.vehicleID) }

    private var duplicate: Fine? {
        store.duplicateNotice(draft.noticeNumber, excluding: fine?.id)
    }

    private var soldWarning: Bool {
        guard let vehicle = store.vehicle(draft.vehicleID), let saleDate = vehicle.saleDate else { return false }
        return Fmt.cal.startOfDay(for: draft.dateOfOffence) > Fmt.cal.startOfDay(for: saleDate)
    }

    private var noticeError: String? {
        guard showValidation else { return nil }
        return draft.noticeNumber.trimmingCharacters(in: .whitespaces).isEmpty
            ? "The notice number identifies the fine everywhere else."
            : nil
    }

    private var amountError: String? {
        guard showValidation else { return nil }
        guard let amount else { return "Enter the amount printed on the notice." }
        return amount <= 0 ? "The amount has to be more than zero." : nil
    }

    private var discountError: String? {
        guard let discounted, let amount else { return nil }
        return discounted >= amount ? "A discounted amount has to be lower than the full amount." : nil
    }

    private var dateError: String? {
        Fmt.cal.startOfDay(for: draft.dateReceived) < Fmt.cal.startOfDay(for: draft.dateOfOffence)
            ? "Received before the offence — check both dates."
            : nil
    }

    private var driverError: String? {
        guard showValidation, driverRequired, draft.driverID == nil else { return nil }
        return "More than one person drives this car, so the driver has to be recorded."
    }

    private var validationErrors: [String] {
        var errors: [String] = []
        if draft.noticeNumber.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("A notice number is required.")
        }
        if draft.vehicleID == nil { errors.append("A vehicle is required.") }
        if (amount ?? 0) <= 0 { errors.append("An amount above zero is required.") }
        if let discounted, let amount, discounted >= amount {
            errors.append("The discounted amount has to be lower than the full amount.")
        }
        if dateError != nil { errors.append("Date received cannot be before the date of the offence.") }
        if driverRequired && draft.driverID == nil {
            errors.append("This car has more than one driver — record who was driving.")
        }
        return errors
    }

    /// Used only to show the counted deadlines while typing.
    private var previewFine: Fine {
        var copy = draft
        copy.amount = amount ?? 0
        copy.discountedAmount = discounted
        copy.rulesOverride = useCustomWindows ? customRules : nil
        if !overrideDeadlines {
            copy.discountDeadlineOverride = nil
            copy.appealDeadlineOverride = nil
            copy.enforcementDateOverride = nil
        }
        return copy
    }

    // MARK: Save

    private func save() {
        showValidation = true
        guard validationErrors.isEmpty, !saving else { return }
        saving = true

        var copy = draft
        copy.amount = amount ?? 0
        copy.discountedAmount = discounted
        copy.noticeNumber = copy.noticeNumber.trimmingCharacters(in: .whitespaces).uppercased()
        copy.location = copy.location.trimmingCharacters(in: .whitespaces)
        copy.rulesOverride = useCustomWindows ? customRules : nil
        if !overrideDeadlines {
            copy.discountDeadlineOverride = nil
            copy.appealDeadlineOverride = nil
            copy.enforcementDateOverride = nil
        }
        copy.enforcementExtraCost = knowsEnforcementCost ? enforcementCost : nil

        store.upsert(copy)
        dismiss()
    }
}

// MARK: - Deadline preview

struct DeadlinePreview: View {
    var fine: Fine
    var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Counted deadlines")
            VStack(spacing: 0) {
                row("Discount ends", DeadlineEngine.discountDeadline(for: fine, settings: settings), note: fine.discountSaving == nil ? "no discount entered" : nil)
                GoldRule(opacity: 0.2)
                row("Appeal closes", DeadlineEngine.appealDeadline(for: fine, settings: settings), note: nil)
                GoldRule(opacity: 0.2)
                row("Enforcement", DeadlineEngine.enforcementDate(for: fine, settings: settings), note: nil)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.gold.opacity(0.07))
            )
        }
    }

    private func row(_ label: String, _ date: Date?, note: String?) -> some View {
        HStack {
            Text(label)
                .font(TypeScale.condensed(12, .bold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.anchor.opacity(0.55))
            Spacer()
            if let date {
                Text(Fmt.date(date))
                    .font(TypeScale.mono(13))
                    .foregroundStyle(Theme.anchor)
            } else {
                Text(note ?? "not counted")
                    .font(TypeScale.caption)
                    .foregroundStyle(Theme.anchor.opacity(0.4))
            }
        }
        .padding(.vertical, 9)
    }
}

// MARK: - Scan read-back

struct ScanReadBackBlock: View {
    var result: ScanResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 13, weight: .bold))
                Text("Read from the photo")
                    .font(TypeScale.condensed(13, .black))
                    .tracking(1.5)
                    .textCase(.uppercase)
            }
            .foregroundStyle(Theme.goldDark)

            Text(result.readBackSentence)
                .font(TypeScale.body)
                .foregroundStyle(Theme.anchor)
                .fixedSize(horizontal: false, vertical: true)

            Text("Nothing is saved until you press save. Correct anything that is wrong.")
                .font(TypeScale.caption)
                .foregroundStyle(Theme.anchor.opacity(0.6))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.gold.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.gold.opacity(0.5), lineWidth: 2)
        )
    }
}
