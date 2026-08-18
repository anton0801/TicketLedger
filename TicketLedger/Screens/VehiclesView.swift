//
//  VehiclesView.swift
//  TicketLedger
//

import SwiftUI

struct VehiclesView: View {
    @Environment(Store.self) private var store
    @State private var path = NavigationPath()
    @State private var showForm = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.page.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Vehicles").screenTitleStyle()
                                Text("\(store.vehicles.count) tracked · \(store.drivers.count) driver(s)")
                                    .font(TypeScale.caption)
                                    .foregroundStyle(Theme.anchor.opacity(0.55))
                            }
                            Spacer()
                            Button {
                                path.append(Route.drivers)
                            } label: {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Theme.goldDark)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(Theme.gold.opacity(0.5), lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(spacing: 10) {
                            MetalButton("Add Vehicle", icon: "plus") { showForm = true }
                            SecondaryButton("Drivers", icon: "person.2") { path.append(Route.drivers) }
                        }
                        .frame(height: Metric.buttonHeight)

                        if store.vehicles.isEmpty {
                            EmptyState(
                                title: "No Vehicles",
                                message: "Every fine and document belongs to a car. Add one to start.",
                                actionTitle: "Add Vehicle",
                                action: { showForm = true }
                            )
                        } else {
                            VStack(spacing: 14) {
                                ForEach(Array(store.vehicles.enumerated()), id: \.element.id) { index, vehicle in
                                    Button {
                                        path.append(Route.vehicle(vehicle.id))
                                    } label: {
                                        VehicleToken(vehicle: vehicle)
                                    }
                                    .buttonStyle(.plain)
                                    .tokenAppear(index)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Metric.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, Metric.contentBottomInset)
                }
            }
            .ledgerDestinations()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showForm) { VehicleFormView(vehicle: nil) }
        }
    }
}

// MARK: - Vehicle token

struct VehicleToken: View {
    @Environment(Store.self) private var store
    var vehicle: Vehicle

    private var openFines: [Fine] {
        store.data.fines.filter { $0.vehicleID == vehicle.id && !$0.status.isClosed }
    }

    private var documents: [DocumentItem] {
        store.data.documents.filter { $0.vehicleID == vehicle.id }
    }

    var body: some View {
        TokenCard(status: vehicle.isSold ? Theme.anchor.opacity(0.3) : Theme.goldDark) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vehicle.plate.uppercased())
                            .font(TypeScale.mono(22))
                            .foregroundStyle(Theme.anchor)
                        Text(vehicle.makeModel.isEmpty ? "No make recorded" : vehicle.makeModel)
                            .font(TypeScale.condensed(15, .bold))
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .foregroundStyle(Theme.anchor.opacity(0.6))
                    }
                    Spacer()
                    if vehicle.isSold {
                        Text("Sold")
                            .font(TypeScale.condensed(11, .black))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.anchor.opacity(0.5))
                            .padding(.horizontal, 9)
                            .frame(height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .strokeBorder(Theme.anchor.opacity(0.3), lineWidth: 1.5)
                            )
                    }
                }

                GoldRule(opacity: 0.25)

                HStack(spacing: 0) {
                    stat(value: "\(openFines.count)", label: "Open fines")
                    stat(value: "\(documents.count)", label: "Documents")
                    stat(
                        value: nextExpiry.map { "\(max($0.daysLeft, 0))" } ?? "—",
                        label: nextExpiry != nil ? "Days to next" : "No dates",
                        color: nextExpiry.map { $0.daysLeft < 0 ? Theme.maroon : ($0.daysLeft <= 14 ? Theme.terracotta : Theme.anchor) }
                    )
                }
            }
        }
    }

    private var nextExpiry: Clock? {
        documents.map { DeadlineEngine.clock(for: $0) }.min { lhs, rhs in
            lhs.daysLeft < rhs.daysLeft
        }
    }

    private func stat(value: String, label: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: -1) {
            Text(value)
                .font(TypeScale.number(26))
                .foregroundStyle(color ?? Theme.anchor)
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

struct VehicleDetailView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var vehicleID: UUID

    @State private var showEdit = false
    @State private var showDelete = false
    @State private var now = Date()

    private var vehicle: Vehicle? { store.vehicle(vehicleID) }

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()

            if let vehicle {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header(vehicle)
                        documentsBlock(vehicle)
                        finesBlock(vehicle)
                        driversBlock(vehicle)
                        detailsBlock(vehicle)
                        DangerButton("Delete Vehicle", icon: "trash") { showDelete = true }
                        Text("Deleting a car keeps its history: each fine holds a snapshot of the plate and model.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.anchor.opacity(0.45))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, Metric.screenPadding)
                    .padding(.bottom, Metric.contentBottomInset)
                }
            } else {
                EmptyState(
                    title: "This Vehicle Is Gone",
                    message: "The record was removed. Fines keep a snapshot of the plate.",
                    actionTitle: "Back",
                    action: { dismiss() }
                )
                .padding(Metric.screenPadding)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if vehicle != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEdit = true
                    } label: {
                        Text("Edit")
                            .font(TypeScale.caption)
                            .foregroundStyle(Theme.goldDark)
                    }
                }
            }
        }
        .toolbarBackground(Theme.page, for: .navigationBar)
        .sheet(isPresented: $showEdit) {
            if let vehicle { VehicleFormView(vehicle: vehicle) }
        }
        .alert("Delete this vehicle?", isPresented: $showDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let vehicle { store.deleteVehicle(vehicle) }
                dismiss()
            }
        } message: {
            Text("Its documents are removed too. Fines stay in the ledger with a snapshot of the plate and model.")
        }
    }

    // MARK: Header with the guilloche

    private func header(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(vehicle.plate.uppercased())
                    .font(TypeScale.mono(30))
                    .foregroundStyle(Theme.anchor)
                Text(vehicle.makeModel.isEmpty ? "No make recorded" : vehicle.makeModel)
                    .screenTitleStyle()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Metric.tokenRadius, style: .continuous)
                        .fill(Theme.card)
                    Guilloche(opacity: 0.22, spacing: 20)
                        .clipShape(RoundedRectangle(cornerRadius: Metric.tokenRadius, style: .continuous))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metric.tokenRadius, style: .continuous)
                    .strokeBorder(Theme.metal, lineWidth: 3)
            )

            if vehicle.photoName != nil {
                StoredImageView(name: vehicle.photoName, height: 180)
            }

            if let saleDate = vehicle.saleDate {
                WarningLine(
                    text: "Sold on \(Fmt.date(saleDate)). Any fine dated after that is flagged — it is usually a reason to appeal, not to pay.",
                    color: Theme.terracotta,
                    icon: "car.side.arrowtriangle.up"
                )
            }
        }
        .padding(.top, 4)
    }

    // MARK: Documents

    private func documentsBlock(_ vehicle: Vehicle) -> some View {
        let documents = store.data.documents
            .filter { $0.vehicleID == vehicle.id }
            .sorted { $0.validUntil < $1.validUntil }

        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Documents and Dates", trailing: documents.isEmpty ? nil : "\(documents.count)")
            GoldRule()
            if documents.isEmpty {
                Text("No documents recorded for this car. Insurance, inspection and road tax go in the same queue as fines.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.anchor.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(documents) { document in
                        let clock = DeadlineEngine.clock(for: document, now: now)
                        NavigationLink(value: Route.document(document.id)) {
                            HStack {
                                Image(systemName: document.type.icon)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Theme.goldDark)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(document.type.title)
                                        .font(TypeScale.condensed(15, .bold))
                                        .textCase(.uppercase)
                                        .foregroundStyle(Theme.anchor)
                                    Text(Fmt.date(document.validUntil))
                                        .font(TypeScale.condensed(13, .bold))
                                        .foregroundStyle(Theme.anchor.opacity(0.5))
                                }
                                Spacer()
                                Text(clock.isExpired ? "expired" : "\(clock.daysLeft)d")
                                    .font(TypeScale.number(18))
                                    .foregroundStyle(clock.isExpired ? Theme.maroon : (clock.daysLeft <= 14 ? Theme.terracotta : Theme.anchor.opacity(0.6)))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.anchor.opacity(0.3))
                            }
                            .padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)
                        if document.id != documents.last?.id { GoldRule(opacity: 0.2) }
                    }
                }
            }
        }
    }

    // MARK: Fines

    private func finesBlock(_ vehicle: Vehicle) -> some View {
        let fines = store.data.fines
            .filter { $0.vehicleID == vehicle.id }
            .sorted { $0.dateReceived > $1.dateReceived }
        let open = fines.filter { !$0.status.isClosed }

        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Fines", trailing: fines.isEmpty ? nil : "\(open.count) open of \(fines.count)")
            GoldRule()
            if fines.isEmpty {
                Text("No fines recorded for this car.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.anchor.opacity(0.6))
            } else {
                VStack(spacing: 12) {
                    ForEach(fines.prefix(5)) { fine in
                        NavigationLink(value: Route.fine(fine.id)) {
                            FineToken(fine: fine, now: now) {}
                                .allowsHitTesting(false)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if fines.count > 5 {
                    Text("and \(fines.count - 5) more in the Fines tab")
                        .font(TypeScale.caption)
                        .foregroundStyle(Theme.anchor.opacity(0.5))
                }
            }
        }
    }

    // MARK: Drivers

    private func driversBlock(_ vehicle: Vehicle) -> some View {
        let drivers = store.drivers(of: vehicle)
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Drivers", trailing: drivers.isEmpty ? nil : "\(drivers.count)")
            GoldRule()
            if drivers.isEmpty {
                Text("Nobody is assigned to this car. With two or more drivers, recording who was driving becomes required on every fine.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.anchor.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(drivers) { driver in
                        NavigationLink(value: Route.driver(driver.id)) {
                            HStack {
                                Text(driver.name)
                                    .font(TypeScale.body)
                                    .foregroundStyle(Theme.anchor)
                                Text(driver.relationship.title)
                                    .font(TypeScale.condensed(11, .bold))
                                    .tracking(1)
                                    .textCase(.uppercase)
                                    .foregroundStyle(Theme.anchor.opacity(0.45))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.anchor.opacity(0.3))
                            }
                            .padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)
                        if driver.id != drivers.last?.id { GoldRule(opacity: 0.2) }
                    }
                }
            }
        }
    }

    // MARK: Details

    private func detailsBlock(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("The Record")
            GoldRule()
            VStack(spacing: 0) {
                if !vehicle.year.isEmpty { DetailRow(label: "Year", value: vehicle.year, mono: true) }
                if !vehicle.vin.isEmpty { DetailRow(label: "VIN", value: vehicle.vin, mono: true) }
                if !vehicle.owner.isEmpty { DetailRow(label: "Owner", value: vehicle.owner) }
                if !vehicle.registeredKeeper.isEmpty {
                    DetailRow(label: "Registered Keeper", value: vehicle.registeredKeeper)
                }
                if !vehicle.insurancePolicy.isEmpty {
                    DetailRow(label: "Insurance Policy", value: vehicle.insurancePolicy, mono: true)
                }
                if let purchase = vehicle.purchaseDate {
                    DetailRow(label: "Purchased", value: Fmt.date(purchase))
                }
                if let sale = vehicle.saleDate {
                    DetailRow(label: "Sold", value: Fmt.date(sale))
                }
                if !vehicle.notes.isEmpty { DetailRow(label: "Notes", value: vehicle.notes) }
            }
        }
    }
}

// MARK: - Form

struct VehicleFormView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var vehicle: Vehicle?

    @State private var draft = Vehicle()
    @State private var insuranceUntil: Date?
    @State private var inspectionUntil: Date?
    @State private var roadTaxDue: Date?
    @State private var saving = false
    @State private var showValidation = false

    private var plateTrimmed: String { draft.plate.trimmingCharacters(in: .whitespaces) }

    private var duplicatePlate: Bool {
        let key = plateTrimmed.uppercased().replacingOccurrences(of: " ", with: "")
        guard !key.isEmpty else { return false }
        return store.data.vehicles.contains {
            $0.id != draft.id && $0.plate.uppercased().replacingOccurrences(of: " ", with: "") == key
        }
    }

    private var dateOrderError: String? {
        guard let purchase = draft.purchaseDate, let sale = draft.saleDate else { return nil }
        return sale < purchase ? "Sold before it was bought — check both dates." : nil
    }

    private var canSave: Bool {
        !plateTrimmed.isEmpty && !duplicatePlate && dateOrderError == nil
    }

    var body: some View {
        FormScaffold(
            title: vehicle == nil ? "Add Vehicle" : "Edit Vehicle",
            saveTitle: vehicle == nil ? "Save Vehicle" : "Save Changes",
            canSave: canSave,
            saving: saving,
            onSave: save
        ) {
            FormBlock(title: "Identity") {
                LedgerTextField(
                    label: "Plate",
                    placeholder: "AB 123 CD",
                    text: $draft.plate,
                    mono: true,
                    required: true,
                    error: showValidation && plateTrimmed.isEmpty
                        ? "A plate is required."
                        : (duplicatePlate ? "Another vehicle already has this plate." : nil)
                )
                LedgerTextField(label: "Make and Model", placeholder: "Skoda Octavia", text: $draft.makeModel)
                LedgerTextField(label: "Year", placeholder: "2018", text: $draft.year, mono: true, keyboard: .numberPad)
                LedgerTextField(label: "VIN", placeholder: "Optional", text: $draft.vin, mono: true)
            }

            FormBlock(title: "Who Holds It") {
                LedgerTextField(label: "Owner", placeholder: "Name on the papers", text: $draft.owner)
                LedgerTextField(label: "Registered Keeper", placeholder: "If different", text: $draft.registeredKeeper)
                LedgerTextField(label: "Insurance Policy", placeholder: "Policy number", text: $draft.insurancePolicy, mono: true)
            }

            FormBlock(
                title: "Dates With Deadlines",
                footnote: "These three are kept as documents, so they appear in the same queue as fines and in the calendar."
            ) {
                LedgerOptionalDateField(label: "Insurance Valid Until", date: $insuranceUntil)
                LedgerOptionalDateField(label: "Inspection Valid Until", date: $inspectionUntil)
                LedgerOptionalDateField(label: "Road Tax Due", date: $roadTaxDue)
            }

            FormBlock(
                title: "Ownership Period",
                footnote: "With a sale date entered, the app flags any fine dated after it."
            ) {
                LedgerOptionalDateField(label: "Purchase Date", date: $draft.purchaseDate)
                LedgerOptionalDateField(label: "Sale Date", date: $draft.saleDate)
                if let dateOrderError {
                    WarningLine(text: dateOrderError)
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
        if let vehicle {
            draft = vehicle
            insuranceUntil = store.vehicleDeadline(.insurance, for: vehicle.id)?.validUntil
            inspectionUntil = store.vehicleDeadline(.technicalInspection, for: vehicle.id)?.validUntil
            roadTaxDue = store.vehicleDeadline(.roadTax, for: vehicle.id)?.validUntil
        }
    }

    private func save() {
        showValidation = true
        guard canSave, !saving else { return }
        saving = true
        var copy = draft
        copy.plate = plateTrimmed.uppercased()
        copy.makeModel = copy.makeModel.trimmingCharacters(in: .whitespaces)
        store.upsert(copy)
        store.setVehicleDeadline(.insurance, for: copy.id, validUntil: insuranceUntil, reference: copy.insurancePolicy)
        store.setVehicleDeadline(.technicalInspection, for: copy.id, validUntil: inspectionUntil)
        store.setVehicleDeadline(.roadTax, for: copy.id, validUntil: roadTaxDue)
        dismiss()
    }
}
