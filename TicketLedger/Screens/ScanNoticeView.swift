//
//  ScanNoticeView.swift
//  TicketLedger
//
//  Reads a photographed notice with Vision, on the device. Nothing is ever
//  saved from a scan without a person confirming it.
//

import SwiftUI
import Vision
import PhotosUI

// MARK: - What a scan produced

struct ScanResult: Equatable {
    var noticeNumber: String?
    var amount: Double?
    var discountedAmount: Double?
    var date: Date?
    var plate: String?
    var article: String?
    var photoName: String?
    var lineCount: Int = 0

    var isEmpty: Bool {
        noticeNumber == nil && amount == nil && date == nil && plate == nil && article == nil
    }

    /// "Read 40.00 and 12 March. Correct anything that is wrong."
    var readBackSentence: String {
        var parts: [String] = []
        if let amount { parts.append(Fmt.amount(amount)) }
        if let discountedAmount { parts.append("a reduced \(Fmt.amount(discountedAmount))") }
        if let date { parts.append(Fmt.dayMonth(date)) }
        if let noticeNumber { parts.append("number \(noticeNumber)") }
        if let plate { parts.append("plate \(plate)") }
        if let article { parts.append("article \(article)") }
        guard !parts.isEmpty else {
            return "Nothing could be read from this photo. Type the fields in by hand — the photo is kept either way."
        }
        let list: String
        if parts.count == 1 {
            list = parts[0]
        } else {
            list = parts.dropLast().joined(separator: ", ") + " and " + parts[parts.count - 1]
        }
        return "Read \(list). Correct anything that is wrong."
    }
}

// MARK: - Recognition

enum NoticeRecognizer {

    static func scan(_ image: UIImage, knownPlates: [String]) async -> ScanResult {
        let lines = await recognizeLines(image)
        return parse(lines: lines, knownPlates: knownPlates)
    }

    private static func recognizeLines(_ image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /// Deliberately conservative: it is better to leave a field empty than to
    /// fill it with a wrong number the user then trusts.
    static func parse(lines: [String], knownPlates: [String]) -> ScanResult {
        var result = ScanResult()
        result.lineCount = lines.count
        let joined = lines.joined(separator: "\n")

        // Amounts: numbers with a decimal separator, or numbers next to a currency word.
        var amounts: [Double] = []
        let amountPattern = #"(?<![\d.,])(\d{1,3}(?:[ .]\d{3})*|\d+)[.,](\d{2})(?![\d])"#
        if let regex = try? NSRegularExpression(pattern: amountPattern) {
            let range = NSRange(joined.startIndex..., in: joined)
            for match in regex.matches(in: joined, range: range) {
                guard let whole = Range(match.range(at: 1), in: joined),
                      let cents = Range(match.range(at: 2), in: joined) else { continue }
                let wholePart = joined[whole].replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: ".", with: "")
                if let value = Double("\(wholePart).\(joined[cents])"), value > 0, value < 1_000_000 {
                    amounts.append(value)
                }
            }
        }
        let unique = Array(Set(amounts)).sorted(by: >)
        if let biggest = unique.first {
            result.amount = biggest
            // A second, smaller figure on a notice is usually the early-payment one.
            if let second = unique.dropFirst().first, second < biggest, second > biggest * 0.2 {
                result.discountedAmount = second
            }
        }

        // Dates: dd.mm.yyyy, dd/mm/yyyy, yyyy-mm-dd.
        result.date = firstDate(in: joined)

        // Notice number: a long code with digits, often after a label.
        result.noticeNumber = firstNoticeNumber(in: lines)

        // Plate: only when it matches a car already in the ledger.
        let squashedText = joined.uppercased().replacingOccurrences(of: " ", with: "")
        for plate in knownPlates {
            let squashedPlate = plate.uppercased().replacingOccurrences(of: " ", with: "")
            guard squashedPlate.count >= 4 else { continue }
            if squashedText.contains(squashedPlate) {
                result.plate = plate
                break
            }
        }

        // Article: patterns like "12.5", "art. 92 §1".
        if let regex = try? NSRegularExpression(pattern: #"(?:art\.?|article|§)\s*([0-9]{1,4}(?:[.,][0-9]{1,3})?(?:\s*§\s*[0-9]{1,3})?)"#, options: .caseInsensitive) {
            let range = NSRange(joined.startIndex..., in: joined)
            if let match = regex.firstMatch(in: joined, range: range),
               let group = Range(match.range(at: 1), in: joined) {
                result.article = String(joined[group]).trimmingCharacters(in: .whitespaces)
            }
        }

        return result
    }

    private static func firstDate(in text: String) -> Date? {
        let patterns: [(String, (Int, Int, Int))] = [
            (#"\b(\d{4})-(\d{1,2})-(\d{1,2})\b"#, (0, 1, 2)),   // year, month, day
            (#"\b(\d{1,2})[./](\d{1,2})[./](\d{4})\b"#, (2, 1, 0)),
            (#"\b(\d{1,2})[./](\d{1,2})[./](\d{2})\b"#, (2, 1, 0))
        ]
        for (pattern, order) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                var numbers: [Int] = []
                for index in 1...3 {
                    guard let r = Range(match.range(at: index), in: text),
                          let value = Int(text[r]) else { numbers = []; break }
                    numbers.append(value)
                }
                guard numbers.count == 3 else { continue }
                var year = numbers[order.0]
                let month = numbers[order.1]
                let day = numbers[order.2]
                if year < 100 { year += 2000 }
                guard (1...12).contains(month), (1...31).contains(day),
                      (2000...2100).contains(year) else { continue }
                var components = DateComponents()
                components.year = year
                components.month = month
                components.day = day
                if let date = Fmt.cal.date(from: components), date <= Date() {
                    return date
                }
            }
        }
        return nil
    }

    private static func firstNoticeNumber(in lines: [String]) -> String? {
        let labels = ["notice", "no.", "nr", "number", "ref", "постановление", "mandat", "ticket", "penalty"]
        // Prefer a code on a line that names itself.
        for line in lines {
            let lower = line.lowercased()
            guard labels.contains(where: { lower.contains($0) }) else { continue }
            if let code = codeCandidate(in: line) { return code }
        }
        for line in lines {
            if let code = codeCandidate(in: line), code.count >= 8 { return code }
        }
        return nil
    }

    private static func codeCandidate(in line: String) -> String? {
        let tokens = line.split(whereSeparator: { $0 == " " || $0 == ":" || $0 == "#" })
        let candidates = tokens
            .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: ".,;()[]")) }
            .filter { token in
                let digits = token.filter(\.isNumber).count
                let valid = token.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "/" }
                return valid && digits >= 5 && token.count >= 6 && token.count <= 30
            }
        return candidates.max(by: { $0.count < $1.count })?.uppercased()
    }
}

// MARK: - Screen

struct ScanNoticeView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    private enum Phase: Equatable {
        case pick
        case reading
        case done(ScanResult)
        case failed(String)
    }

    @State private var phase: Phase = .pick
    @State private var showCamera = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var showForm = false
    @State private var result = ScanResult()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.page.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch phase {
                        case .pick:
                            pickPhase
                        case .reading:
                            VStack(spacing: 16) {
                                LoadingState(message: "Reading the notice")
                                    .frame(height: 160)
                                Text("This happens on the device. The photo is not uploaded anywhere.")
                                    .font(TypeScale.caption)
                                    .foregroundStyle(Theme.anchor.opacity(0.5))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        case .done(let scanned):
                            donePhase(scanned)
                        case .failed(let message):
                            ErrorState(
                                title: "The photo could not be read",
                                message: message,
                                retryTitle: "Try Another Photo",
                                retry: { phase = .pick }
                            )
                        }
                    }
                    .padding(Metric.screenPadding)
                    .padding(.bottom, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Scan Notice")
                        .font(TypeScale.condensed(19, .black))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.anchor)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        // A scan that is abandoned leaves no photo behind.
                        if case .done(let scanned) = phase { ImageStore.delete(scanned.photoName) }
                        dismiss()
                    }
                    .font(TypeScale.caption)
                    .foregroundStyle(Theme.goldDark)
                }
            }
            .toolbarBackground(Theme.page, for: .navigationBar)
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in handle(image) }
            }
            .sheet(isPresented: $showForm, onDismiss: { dismiss() }) {
                FineFormView(fine: nil, scanned: result)
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                phase = .reading
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        handle(image)
                    } else {
                        phase = .failed("That file could not be opened as an image. Pick another one, or add the fine by hand.")
                    }
                    pickerItem = nil
                }
            }
        }
    }

    // MARK: Phases

    private var pickPhase: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Photograph the notice")
                .screenTitleStyle()
            Text("The app reads the number, the date, the amount and the article from the photo, on this device, and puts them in the form for you to check.")
                .font(TypeScale.body)
                .foregroundStyle(Theme.anchor.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            TokenCard(status: Theme.gold) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What helps the reading")
                        .sectionTitleStyle()
                    ForEach([
                        "Flat notice, no folds across the numbers.",
                        "Even light, no flash glare on the paper.",
                        "The whole page in frame, edge to edge."
                    ], id: \.self) { hint in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(Theme.green)
                                .padding(.top, 3)
                            Text(hint)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.anchor.opacity(0.75))
                        }
                    }
                }
            }

            MetalButton("Take Photo", icon: "camera.fill") { showCamera = true }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle").font(.system(size: 15, weight: .bold))
                    Text("Choose From Library")
                        .font(TypeScale.condensed(16, .bold))
                        .tracking(1)
                        .textCase(.uppercase)
                }
                .foregroundStyle(Theme.goldDark)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: Metric.buttonRadius, style: .continuous)
                        .strokeBorder(Theme.gold, lineWidth: 2.5)
                )
            }
            .buttonStyle(.plain)

            Text("Recognition happens locally with the system text reader. No image and no field ever leaves the device.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.anchor.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func donePhase(_ scanned: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(scanned.isEmpty ? "Nothing Recognised" : "Check What Was Read")
                .screenTitleStyle()

            StoredImageView(name: scanned.photoName, height: 200)

            ScanReadBackBlock(result: scanned)

            if scanned.isEmpty {
                Text("The reader found \(scanned.lineCount) lines of text but nothing that looks like a notice number, a date or an amount. The photo is kept — fill the fields in by hand.")
                    .font(TypeScale.body)
                    .foregroundStyle(Theme.anchor.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            MetalButton(scanned.isEmpty ? "Continue by Hand" : "Open the Form") {
                result = scanned
                showForm = true
            }
            SecondaryButton("Take Another Photo") {
                ImageStore.delete(scanned.photoName)
                phase = .pick
            }
        }
    }

    // MARK: Work

    private func handle(_ image: UIImage) {
        phase = .reading
        Task {
            let plates = store.vehicles.map(\.plate).filter { !$0.isEmpty }
            var scanned = await NoticeRecognizer.scan(image, knownPlates: plates)
            scanned.photoName = ImageStore.save(image)
            if scanned.photoName == nil {
                phase = .failed("The photo could not be stored on the device. Check the available space and try again.")
            } else {
                phase = .done(scanned)
            }
        }
    }
}
