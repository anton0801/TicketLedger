//
//  FormComponents.swift
//  TicketLedger
//
//  Fields, pickers and photo rows. Every form validates, blocks a second save
//  while writing, and says plainly what is missing.
//

import SwiftUI
import PhotosUI

// MARK: - Field frame

private struct FieldShell<Content: View>: View {
    var label: String
    var required: Bool = false
    var error: String?
    var hint: String?
    var focused: Bool = false
    var dark: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(TypeScale.condensed(12, .bold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle((dark ? Theme.page : Theme.anchor).opacity(0.55))
                if required {
                    Text("required")
                        .font(TypeScale.condensed(10, .bold))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.terracotta)
                }
            }
            content()
                .padding(.horizontal, 12)
                .frame(minHeight: 48)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(dark ? Theme.anchor.opacity(0.5) : Theme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            error != nil ? Theme.terracotta : (focused ? Theme.gold : Theme.gold.opacity(0.45)),
                            lineWidth: error != nil || focused ? 2 : 1.5
                        )
                )
            if let error {
                Text(error)
                    .font(TypeScale.caption)
                    .foregroundStyle(Theme.terracotta)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let hint {
                Text(hint)
                    .font(.system(size: 12))
                    .foregroundStyle((dark ? Theme.page : Theme.anchor).opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Text

struct LedgerTextField: View {
    var label: String
    var placeholder: String = ""
    @Binding var text: String
    var mono: Bool = false
    var required: Bool = false
    var error: String?
    var hint: String?
    var keyboard: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var dark: Bool = false

    @FocusState private var focused: Bool

    var body: some View {
        FieldShell(label: label, required: required, error: error, hint: hint, focused: focused, dark: dark) {
            TextField(placeholder, text: $text)
                .font(mono ? TypeScale.mono(15) : TypeScale.body)
                .foregroundStyle(dark ? Theme.page : Theme.anchor)
                .tint(Theme.goldDark)
                .keyboardType(keyboard)
                .textInputAutocapitalization(mono ? .characters : autocapitalization)
                .autocorrectionDisabled(mono)
                .focused($focused)
        }
    }
}

struct LedgerTextArea: View {
    var label: String
    @Binding var text: String
    var hint: String?
    var dark: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(TypeScale.condensed(12, .bold))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle((dark ? Theme.page : Theme.anchor).opacity(0.55))
            TextEditor(text: $text)
                .font(TypeScale.body)
                .foregroundStyle(dark ? Theme.page : Theme.anchor)
                .tint(Theme.goldDark)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 92)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(dark ? Theme.anchor.opacity(0.5) : Theme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(focused ? Theme.gold : Theme.gold.opacity(0.45), lineWidth: focused ? 2 : 1.5)
                )
                .focused($focused)
            if let hint {
                Text(hint)
                    .font(.system(size: 12))
                    .foregroundStyle((dark ? Theme.page : Theme.anchor).opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Money

struct LedgerMoneyField: View {
    var label: String
    @Binding var value: Double?
    var currency: String
    var required: Bool = false
    var error: String?
    var hint: String?
    var dark: Bool = false

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        FieldShell(label: label, required: required, error: error, hint: hint, focused: focused, dark: dark) {
            HStack(spacing: 8) {
                Text(Fmt.currencySymbol(currency))
                    .font(TypeScale.condensed(17, .black))
                    .foregroundStyle(Theme.goldDark)
                TextField("0", text: $text)
                    .font(TypeScale.number(20))
                    .foregroundStyle(dark ? Theme.page : Theme.anchor)
                    .tint(Theme.goldDark)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .onChange(of: text) { _, new in
                        let cleaned = new.replacingOccurrences(of: ",", with: ".")
                            .filter { $0.isNumber || $0 == "." }
                        if cleaned != new { text = cleaned; return }
                        value = cleaned.isEmpty ? nil : Double(cleaned)
                    }
            }
            .onAppear {
                if let value { text = Fmt.amount(value) }
            }
        }
    }
}

// MARK: - Dates

/// Date field with no system capsule: the value is set in condensed type and a
/// sheet carries the picker, tinted gold like everything else.
struct LedgerDateField: View {
    var label: String
    @Binding var date: Date
    var range: PartialRangeThrough<Date>?
    var hint: String?
    var error: String?
    var dark: Bool = false

    @State private var editing = false

    var body: some View {
        FieldShell(label: label, error: error, hint: hint, dark: dark) {
            Button {
                editing = true
            } label: {
                DateFieldFace(text: Fmt.date(date), dark: dark)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $editing) {
            DatePickerSheet(title: label, date: $date, range: range)
        }
    }
}

struct LedgerOptionalDateField: View {
    var label: String
    @Binding var date: Date?
    var hint: String?
    var addTitle: String = "Set a date"
    var dark: Bool = false

    @State private var editing = false
    @State private var working = Date()

    var body: some View {
        FieldShell(label: label, hint: hint, dark: dark) {
            HStack(spacing: 8) {
                Button {
                    working = date ?? Date()
                    editing = true
                } label: {
                    if let date {
                        DateFieldFace(text: Fmt.date(date), dark: dark)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                            Text(addTitle).font(TypeScale.body)
                        }
                        .foregroundStyle(Theme.goldDark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)

                if date != nil {
                    Button {
                        date = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle((dark ? Theme.page : Theme.anchor).opacity(0.35))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $editing) {
            DatePickerSheet(
                title: label,
                date: Binding(get: { working }, set: { working = $0; date = $0 }),
                range: nil
            )
        }
    }
}

private struct DateFieldFace: View {
    var text: String
    var dark: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.goldDark)
            Text(text)
                .font(TypeScale.condensed(17, .bold))
                .foregroundStyle(dark ? Theme.page : Theme.anchor)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.goldDark.opacity(0.7))
        }
        .contentShape(Rectangle())
    }
}

private struct DatePickerSheet: View {
    var title: String
    @Binding var date: Date
    var range: PartialRangeThrough<Date>?

    @Environment(\.dismiss) private var dismiss
    @State private var working = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.page.ignoresSafeArea()
                VStack(spacing: 18) {
                    Group {
                        if let range {
                            DatePicker("", selection: $working, in: range, displayedComponents: .date)
                        } else {
                            DatePicker("", selection: $working, displayedComponents: .date)
                        }
                    }
                    .datePickerStyle(.graphical)
                    .tint(Theme.goldDark)
                    .padding(.horizontal, 4)

                    MetalButton("Use This Date") {
                        date = working
                        dismiss()
                    }
                }
                .padding(Metric.screenPadding)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(TypeScale.condensed(17, .black))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.anchor)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(TypeScale.caption)
                        .foregroundStyle(Theme.goldDark)
                }
            }
            .toolbarBackground(Theme.page, for: .navigationBar)
        }
        .presentationDetents([.height(500)])
        .onAppear { working = date }
    }
}

// MARK: - Menu picker

struct LedgerPicker<Item: Hashable>: View {
    var label: String
    @Binding var selection: Item
    var options: [Item]
    var title: (Item) -> String
    var required: Bool = false
    var error: String?
    var hint: String?
    var dark: Bool = false

    var body: some View {
        FieldShell(label: label, required: required, error: error, hint: hint, dark: dark) {
            Menu {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Button {
                        selection = option
                    } label: {
                        if option == selection {
                            Label(title(option), systemImage: "checkmark")
                        } else {
                            Text(title(option))
                        }
                    }
                }
            } label: {
                HStack {
                    Text(title(selection))
                        .font(TypeScale.body)
                        .foregroundStyle(dark ? Theme.page : Theme.anchor)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.goldDark)
                }
            }
        }
    }
}

/// Picker that allows "not set".
struct LedgerOptionalPicker<Item: Hashable & Identifiable>: View {
    var label: String
    @Binding var selection: Item.ID?
    var options: [Item]
    var title: (Item) -> String
    var noneTitle: String = "Not set"
    var required: Bool = false
    var error: String?
    var hint: String?
    var dark: Bool = false

    private var currentTitle: String {
        if let selection, let match = options.first(where: { $0.id == selection }) {
            return title(match)
        }
        return noneTitle
    }

    var body: some View {
        FieldShell(label: label, required: required, error: error, hint: hint, dark: dark) {
            Menu {
                Button(noneTitle) { selection = nil }
                ForEach(options) { option in
                    Button {
                        selection = option.id
                    } label: {
                        if option.id == selection {
                            Label(title(option), systemImage: "checkmark")
                        } else {
                            Text(title(option))
                        }
                    }
                }
            } label: {
                HStack {
                    Text(currentTitle)
                        .font(TypeScale.body)
                        .foregroundStyle(
                            selection == nil
                                ? (dark ? Theme.page : Theme.anchor).opacity(0.45)
                                : (dark ? Theme.page : Theme.anchor)
                        )
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.goldDark)
                }
            }
        }
    }
}

// MARK: - Days

/// Typed or stepped, with the app's own controls — no system stepper.
struct LedgerDaysField: View {
    var label: String
    @Binding var days: Int
    var range: ClosedRange<Int> = 0...365
    var hint: String?
    var dark: Bool = false

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        FieldShell(label: label, hint: hint, focused: focused, dark: dark) {
            HStack(spacing: 10) {
                TextField("0", text: $text)
                    .font(TypeScale.number(24))
                    .foregroundStyle(dark ? Theme.page : Theme.anchor)
                    .tint(Theme.goldDark)
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .frame(width: 56)
                    .onChange(of: text) { _, new in
                        let digits = new.filter(\.isNumber)
                        if digits != new { text = digits; return }
                        if let value = Int(digits) {
                            days = min(max(value, range.lowerBound), range.upperBound)
                        }
                    }
                Text("days")
                    .font(TypeScale.condensed(13, .bold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle((dark ? Theme.page : Theme.anchor).opacity(0.5))
                Spacer()
                stepButton("minus", enabled: days > range.lowerBound) {
                    days = max(range.lowerBound, days - 1)
                    text = "\(days)"
                }
                stepButton("plus", enabled: days < range.upperBound) {
                    days = min(range.upperBound, days + 1)
                    text = "\(days)"
                }
            }
            .padding(.vertical, 6)
            .onAppear { text = "\(days)" }
            .onChange(of: days) { _, new in
                if Int(text) != new { text = "\(new)" }
            }
        }
    }

    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Theme.goldDark)
                .frame(width: 38, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Theme.gold.opacity(enabled ? 0.7 : 0.25), lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Toggle

struct LedgerToggle: View {
    var label: String
    var hint: String?
    @Binding var isOn: Bool
    var dark: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $isOn) {
                Text(label)
                    .font(TypeScale.condensed(15, .bold))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(dark ? Theme.page : Theme.anchor)
            }
            .tint(Theme.goldDark)
            if let hint {
                Text(hint)
                    .font(.system(size: 12))
                    .foregroundStyle((dark ? Theme.page : Theme.anchor).opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Photo field

struct PhotoField: View {
    var label: String
    @Binding var photoName: String?
    var hint: String?

    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(TypeScale.condensed(12, .bold))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.anchor.opacity(0.55))

            StoredImageView(name: photoName, height: photoName == nil ? 56 : 150)

            HStack(spacing: 10) {
                Button {
                    showCamera = true
                } label: {
                    fieldButton(icon: "camera.fill", title: photoName == nil ? "Camera" : "Retake")
                }
                .buttonStyle(.plain)

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    fieldButton(icon: "photo.on.rectangle", title: "Library")
                }
                .buttonStyle(.plain)

                if photoName != nil {
                    Button {
                        ImageStore.delete(photoName)
                        photoName = nil
                    } label: {
                        fieldButton(icon: "trash", title: "Remove", danger: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            if let hint {
                Text(hint)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.anchor.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(busy ? 0.5 : 1)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            busy = true
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    let old = photoName
                    if let name = ImageStore.save(image) {
                        photoName = name
                        if old != name { ImageStore.delete(old) }
                    }
                }
                busy = false
                pickerItem = nil
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                let old = photoName
                if let name = ImageStore.save(image) {
                    photoName = name
                    if old != name { ImageStore.delete(old) }
                }
            }
        }
    }

    private func fieldButton(icon: String, title: String, danger: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold))
            Text(title)
                .font(TypeScale.condensed(13, .bold))
                .tracking(1)
                .textCase(.uppercase)
        }
        .foregroundStyle(danger ? Theme.maroon : Theme.goldDark)
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder((danger ? Theme.maroon : Theme.gold).opacity(0.6), lineWidth: 2)
        )
    }
}

// MARK: - Camera

struct CameraPicker: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIViewController {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return NoCameraViewController()
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onPick(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// Shown instead of a black screen when the device has no camera.
final class NoCameraViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Theme.page)
        let label = UILabel()
        label.text = "This device has no camera available.\nUse Library to pick a photo instead."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = UIColor(Theme.anchor)
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }
}

// MARK: - Form scaffolding

/// Grouped block inside a form, with the section rule above it.
struct FormBlock<Content: View>: View {
    var title: String?
    var footnote: String?
    var dark: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                VStack(alignment: .leading, spacing: 6) {
                    SectionHeader(title, dark: dark)
                    GoldRule()
                }
            }
            content()
            if let footnote {
                Text(footnote)
                    .font(.system(size: 12))
                    .foregroundStyle((dark ? Theme.page : Theme.anchor).opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Sheet wrapper: cream page, condensed title, cancel and save.
struct FormScaffold<Content: View>: View {
    var title: String
    var saveTitle: String = "Save"
    var canSave: Bool
    var saving: Bool = false
    var onSave: () -> Void
    var onCancel: (() -> Void)?
    @ViewBuilder var content: () -> Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.page.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        content()
                        MetalButton(saveTitle, enabled: canSave && !saving) { onSave() }
                            .padding(.top, 4)
                    }
                    .padding(Metric.screenPadding)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(TypeScale.condensed(19, .black))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.anchor)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel?()
                        dismiss()
                    }
                    .font(TypeScale.caption)
                    .foregroundStyle(Theme.goldDark)
                }
            }
            .toolbarBackground(Theme.page, for: .navigationBar)
        }
    }
}
