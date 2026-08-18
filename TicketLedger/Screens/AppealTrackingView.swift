//
//  AppealTrackingView.swift
//  TicketLedger
//
//  Tracks what was sent and when. Writing the appeal is the user's part — the
//  app does not draft text and does not promise an outcome.
//

import SwiftUI

struct AppealTrackingView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var fineID: UUID

    @State private var appeal = AppealCase()
    @State private var submitted = false
    @State private var submittedOn = Date()
    @State private var expectedAnswerBy: Date?
    @State private var answerReceived: Date?
    @State private var outcome: AppealOutcome?
    @State private var reducedTo: Double?
    @State private var saving = false
    @State private var showValidation = false

    private var fine: Fine? { store.fine(fineID) }

    private var validationErrors: [String] {
        var errors: [String] = []
        if submitted, let expected = expectedAnswerBy,
           Fmt.cal.startOfDay(for: expected) < Fmt.cal.startOfDay(for: submittedOn) {
            errors.append("The answer date cannot be before the date you sent it.")
        }
        if let received = answerReceived, Fmt.cal.startOfDay(for: received) < Fmt.cal.startOfDay(for: submittedOn) {
            errors.append("The answer cannot arrive before the appeal was sent.")
        }
        if answerReceived != nil && outcome == nil {
            errors.append("An answer arrived — record what it said.")
        }
        if outcome == .reduced && (reducedTo ?? 0) <= 0 {
            errors.append("Reduced to what amount?")
        }
        return errors
    }

    var body: some View {
        FormScaffold(
            title: "Appeal Tracking",
            saveTitle: "Save Appeal Record",
            canSave: validationErrors.isEmpty,
            saving: saving,
            onSave: save
        ) {
            if let fine {
                statusBlock(fine)
            }

            if showValidation && !validationErrors.isEmpty {
                VStack(spacing: 6) {
                    ForEach(validationErrors, id: \.self) { WarningLine(text: $0) }
                }
            }

            FormBlock(
                title: "What You Sent",
                footnote: "The app tracks what you sent and when. Writing the appeal is your part."
            ) {
                LedgerToggle(
                    label: "The appeal has been sent",
                    hint: "Turn this on once it has actually gone out. The appeal window clock stops then.",
                    isOn: $submitted
                )
                if submitted {
                    LedgerDateField(label: "Submitted On", date: $submittedOn, range: ...Date())
                    LedgerPicker(
                        label: "Method",
                        selection: $appeal.method,
                        options: AppealMethod.allCases,
                        title: \.title
                    )
                    LedgerTextField(
                        label: "Reference Number",
                        placeholder: "Their case number, if given",
                        text: $appeal.referenceNumber,
                        mono: true
                    )
                    LedgerOptionalDateField(
                        label: "Expected Answer By",
                        date: $expectedAnswerBy,
                        hint: "If the authority states a period, put the end of it here and the app will tell you when it has passed."
                    )
                }
            }

            if submitted {
                FormBlock(title: "Reminders Sent") {
                    remindersBlock
                }

                FormBlock(title: "The Answer") {
                    LedgerOptionalDateField(label: "Answer Received", date: $answerReceived)
                    LedgerOptionalPicker(
                        label: "Outcome",
                        selection: Binding(
                            get: { outcome?.id },
                            set: { newValue in
                                outcome = AppealOutcome.allCases.first { $0.id == newValue }
                            }
                        ),
                        options: AppealOutcome.allCases,
                        title: \.title,
                        noneTitle: "No answer yet"
                    )
                    if outcome == .reduced {
                        LedgerMoneyField(
                            label: "Reduced To",
                            value: $reducedTo,
                            currency: store.currency
                        )
                    }
                    LedgerTextField(
                        label: "Next Step",
                        placeholder: "Pay it, escalate, send a reminder",
                        text: $appeal.nextStep
                    )
                    if let outcome {
                        outcomeNote(outcome)
                    }
                }
            }
        }
        .onAppear(perform: prepare)
    }

    // MARK: Status

    private func statusBlock(_ fine: Fine) -> some View {
        let clock = DeadlineEngine.clocks(for: fine, settings: store.data.settings)
            .first { $0.kind == .appealAnswer }

        return TokenCard(status: statusColor(fine), showsHoles: false) {
            VStack(alignment: .leading, spacing: 8) {
                Text(fine.noticeNumber.isEmpty ? "NO NUMBER" : fine.noticeNumber)
                    .font(TypeScale.mono(13))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.goldDark)
                Text(statusText(fine))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.anchor.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                if let clock, clock.isExpired {
                    WarningLine(
                        text: "The answer was due \(Fmt.dayCount(-clock.daysLeft)) ago. Recording a reminder keeps the trail complete.",
                        color: Theme.terracotta,
                        icon: "clock.badge.exclamationmark"
                    )
                }
                if !fine.grounds.isEmpty {
                    Text("Grounds: \(fine.grounds.map(\.title).joined(separator: ", "))")
                        .font(TypeScale.caption)
                        .foregroundStyle(Theme.anchor.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func statusColor(_ fine: Fine) -> Color {
        if let outcome = fine.appeal?.outcome { return outcome.color }
        return fine.appeal?.isSubmitted == true ? Theme.gold : Theme.goldDark
    }

    private func statusText(_ fine: Fine) -> String {
        guard let existing = fine.appeal, existing.isSubmitted else {
            if let clock = DeadlineEngine.clocks(for: fine, settings: store.data.settings).first(where: { $0.kind == .appeal }) {
                return clock.isExpired
                    ? "The appeal window closed on \(Fmt.date(clock.deadline)). You can still keep a record of what happened."
                    : "Not sent yet. \(Fmt.dayCount(clock.daysLeft)) left in the appeal window."
            }
            return "Not sent yet."
        }
        if let outcome = existing.outcome {
            return "Answered: \(outcome.title.lowercased())\(existing.answerReceived.map { " on \(Fmt.date($0))" } ?? "")."
        }
        return "Sent on \(Fmt.date(existing.submittedOn ?? Date())) by \(existing.method.title.lowercased()). No answer recorded."
    }

    private func outcomeNote(_ outcome: AppealOutcome) -> some View {
        let text: String
        switch outcome {
        case .cancelled: text = "Saving this closes the fine as cancelled."
        case .reduced: text = "Saving this sets the amount to the reduced figure and leaves the fine open for payment."
        case .upheld: text = "Saving this leaves the fine open. Check whether the discount still applies where you are."
        case .noAnswer: text = "Kept open. The app keeps reminding you that no answer arrived."
        case .withdrawn: text = "Saving this leaves the fine open for payment."
        }
        return Text(text)
            .font(TypeScale.caption)
            .foregroundStyle(Theme.anchor.opacity(0.65))
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Reminders

    private var remindersBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            if appeal.remindersSent.isEmpty {
                Text("No reminders recorded.")
                    .font(TypeScale.caption)
                    .foregroundStyle(Theme.anchor.opacity(0.5))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(appeal.remindersSent.enumerated()), id: \.offset) { index, date in
                        HStack {
                            Text("Reminder \(index + 1)")
                                .font(TypeScale.condensed(13, .bold))
                                .tracking(1)
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.anchor.opacity(0.55))
                            Spacer()
                            Text(Fmt.date(date))
                                .font(TypeScale.mono(13))
                                .foregroundStyle(Theme.anchor)
                            Button {
                                appeal.remindersSent.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Theme.anchor.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 9)
                        if index < appeal.remindersSent.count - 1 { GoldRule(opacity: 0.2) }
                    }
                }
            }
            SecondaryButton("Record a Reminder Sent Today", icon: "bell.badge") {
                appeal.remindersSent.append(Date())
            }
        }
    }

    // MARK: Load & save

    private func prepare() {
        guard let fine, let existing = fine.appeal else {
            expectedAnswerBy = nil
            return
        }
        appeal = existing
        submitted = existing.isSubmitted
        submittedOn = existing.submittedOn ?? Date()
        expectedAnswerBy = existing.expectedAnswerBy
        answerReceived = existing.answerReceived
        outcome = existing.outcome
        reducedTo = existing.reducedToAmount
    }

    private func save() {
        showValidation = true
        guard validationErrors.isEmpty, !saving, let fine else { return }
        saving = true

        var copy = fine
        var record = appeal
        record.submittedOn = submitted ? submittedOn : nil
        record.expectedAnswerBy = expectedAnswerBy
        record.answerReceived = answerReceived
        record.outcome = outcome
        record.reducedToAmount = outcome == .reduced ? reducedTo : nil
        copy.appeal = record

        if submitted, copy.status == .open { copy.status = .underAppeal }

        switch outcome {
        case .cancelled:
            copy.status = .cancelled
            copy.closedAt = answerReceived ?? Date()
        case .reduced:
            if let reducedTo, reducedTo > 0 {
                copy.amount = reducedTo
                // The old discount figure no longer describes this notice.
                if let discounted = copy.discountedAmount, discounted >= reducedTo {
                    copy.discountedAmount = nil
                }
            }
            copy.status = .open
        case .upheld, .withdrawn:
            copy.status = .open
        case .noAnswer, .none:
            break
        }

        store.upsert(copy)
        dismiss()
    }
}
