//
//  EvidenceView.swift
//  TicketLedger
//
//  Material for a contested fine. The app suggests what is usually needed for
//  the grounds marked, and flags what is missing.
//

import SwiftUI

struct EvidenceView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var fineID: UUID

    @State private var editing: EvidenceItem?
    @State private var showForm = false
    @State private var deleteTarget: EvidenceItem?

    private var fine: Fine? { store.fine(fineID) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.page.ignoresSafeArea()

                if let fine {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if !fine.grounds.isEmpty {
                                groundsBlock(fine)
                            }

                            if fine.evidence.isEmpty {
                                EmptyState(
                                    title: "Nothing Collected",
                                    message: fine.grounds.isEmpty
                                        ? "Add photos, contracts, receipts or contacts here. Mark grounds on the Pay or Appeal screen and the app will say what is usually needed."
                                        : "Nothing has been added yet for the grounds you marked.",
                                    actionTitle: "Add Evidence",
                                    action: { editing = nil; showForm = true }
                                )
                            } else {
                                VStack(spacing: 14) {
                                    ForEach(Array(fine.evidence.enumerated()), id: \.element.id) { index, item in
                                        evidenceToken(item)
                                            .tokenAppear(index)
                                    }
                                }
                                MetalButton("Add Evidence", icon: "plus") {
                                    editing = nil
                                    showForm = true
                                }
                            }
                        }
                        .padding(Metric.screenPadding)
                        .padding(.bottom, 40)
                    }
                } else {
                    EmptyState(
                        title: "This Fine Is Gone",
                        message: "The record was removed.",
                        actionTitle: "Close",
                        action: { dismiss() }
                    )
                    .padding(Metric.screenPadding)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Evidence")
                        .font(TypeScale.condensed(19, .black))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.anchor)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(TypeScale.caption)
                        .foregroundStyle(Theme.goldDark)
                }
            }
            .toolbarBackground(Theme.page, for: .navigationBar)
            .sheet(isPresented: $showForm) {
                if let fine {
                    EvidenceFormView(fineID: fine.id, item: editing)
                }
            }
            .alert("Remove this evidence?", isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            )) {
                Button("Cancel", role: .cancel) { deleteTarget = nil }
                Button("Remove", role: .destructive) {
                    if let fine, let target = deleteTarget {
                        var copy = fine
                        copy.evidence.removeAll { $0.id == target.id }
                        ImageStore.delete(target.fileName)
                        store.upsert(copy)
                    }
                    deleteTarget = nil
                }
            } message: {
                Text("The attached file is deleted from the device too.")
            }
        }
    }

    // MARK: Grounds and gaps

    private func groundsBlock(_ fine: Fine) -> some View {
        let held = Set(fine.evidence.map(\.type))
        let missing = fine.grounds.flatMap(\.usualEvidence).filter { !held.contains($0) }
        let uniqueMissing = Array(Set(missing)).sorted { $0.title < $1.title }

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Grounds Marked")
            GoldRule()
            VStack(alignment: .leading, spacing: 6) {
                ForEach(fine.grounds) { ground in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.goldDark)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ground.title)
                                .font(TypeScale.condensed(14, .black))
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.anchor)
                            if let hint = ground.evidenceHint {
                                Text(hint)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.anchor.opacity(0.7))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            if !uniqueMissing.isEmpty {
                WarningLine(
                    text: "Missing so far: \(uniqueMissing.map(\.title).joined(separator: ", ")).",
                    color: Theme.terracotta,
                    icon: "tray"
                )
            }
        }
    }

    // MARK: Token

    private func evidenceToken(_ item: EvidenceItem) -> some View {
        TokenCard(status: item.fileName == nil ? Theme.terracotta : Theme.green, showsHoles: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    HStack(spacing: 8) {
                        Image(systemName: item.type.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.goldDark)
                        Text(item.type.title)
                            .font(TypeScale.condensed(16, .black))
                            .tracking(0.5)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.anchor)
                    }
                    Spacer()
                    Menu {
                        Button {
                            editing = item
                            showForm = true
                        } label: {
                            Label("Edit", systemImage: "square.and.pencil")
                        }
                        Button(role: .destructive) {
                            deleteTarget = item
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.anchor.opacity(0.5))
                            .frame(width: 30, height: 24)
                    }
                }

                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.anchor.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if item.fileName != nil {
                    StoredImageView(name: item.fileName, height: 140)
                } else {
                    Text("No file attached yet.")
                        .font(TypeScale.caption)
                        .foregroundStyle(Theme.terracotta)
                }

                HStack(spacing: 12) {
                    if let date = item.dateTaken {
                        smallMeta(icon: "calendar", text: Fmt.date(date))
                    }
                    if !item.source.isEmpty {
                        smallMeta(icon: "arrow.down.doc", text: item.source)
                    }
                }
                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.anchor.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func smallMeta(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
            Text(text).font(TypeScale.condensed(12, .bold)).textCase(.uppercase)
        }
        .foregroundStyle(Theme.anchor.opacity(0.5))
    }
}

// MARK: - Evidence form

struct EvidenceFormView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var fineID: UUID
    var item: EvidenceItem?

    @State private var draft = EvidenceItem()
    @State private var saving = false
    @State private var showValidation = false

    private var canSave: Bool {
        !draft.description.trimmingCharacters(in: .whitespaces).isEmpty || draft.fileName != nil
    }

    var body: some View {
        FormScaffold(
            title: item == nil ? "Add Evidence" : "Edit Evidence",
            saveTitle: "Save Evidence",
            canSave: canSave,
            saving: saving,
            onSave: save
        ) {
            if showValidation && !canSave {
                WarningLine(text: "Add a description or attach a file — an empty record helps nobody.")
            }

            FormBlock(title: "What It Is") {
                LedgerPicker(
                    label: "Evidence Type",
                    selection: $draft.type,
                    options: EvidenceType.allCases,
                    title: \.title
                )
                LedgerTextField(
                    label: "Description",
                    placeholder: "What it shows",
                    text: $draft.description
                )
                LedgerOptionalDateField(
                    label: "Date Taken",
                    date: $draft.dateTaken,
                    hint: "For a sale contract or a sign photo, the date is often the whole point."
                )
            }

            FormBlock(title: "The File") {
                PhotoField(
                    label: "File or Photo",
                    photoName: $draft.fileName,
                    hint: "Stored on this device. Video files are not stored — note where the footage is kept instead."
                )
                LedgerTextField(
                    label: "Where It Came From",
                    placeholder: "Dashcam, my phone, the seller",
                    text: $draft.source
                )
                LedgerTextArea(label: "Notes", text: $draft.notes)
            }
        }
        .onAppear {
            if let item { draft = item }
        }
    }

    private func save() {
        showValidation = true
        guard canSave, !saving, let fine = store.fine(fineID) else { return }
        saving = true
        var copy = fine
        if let index = copy.evidence.firstIndex(where: { $0.id == draft.id }) {
            copy.evidence[index] = draft
        } else {
            copy.evidence.append(draft)
        }
        store.upsert(copy)
        dismiss()
    }
}
