//
//  ExportManager.swift
//  TicketLedger
//
//  CSV and PDF export. Useful as a report for an employer, or handed over with
//  the car when it is sold.
//

import SwiftUI
import UIKit

enum ExportManager {

    // MARK: CSV

    @MainActor
    static func csvFines(_ store: Store) -> String {
        var rows: [[String]] = [[
            "Notice Number", "Status", "Plate", "Make and Model", "Driver",
            "Date of Offence", "Date Received", "Amount", "Discounted Amount",
            "Discount Ends", "Appeal Closes", "Enforcement From",
            "Article", "Description", "Location", "Authority",
            "Paid Total", "Appeal Outcome", "Closed", "Notes"
        ]]
        let settings = store.data.settings
        for fine in store.fines {
            rows.append([
                fine.noticeNumber,
                fine.status.title,
                fine.vehiclePlateSnapshot,
                fine.vehicleModelSnapshot,
                fine.driverNameSnapshot ?? "",
                iso(fine.dateOfOffence),
                iso(fine.dateReceived),
                number(fine.amount),
                fine.discountedAmount.map(number) ?? "",
                DeadlineEngine.discountDeadline(for: fine, settings: settings).map(iso) ?? "",
                DeadlineEngine.appealDeadline(for: fine, settings: settings).map(iso) ?? "",
                DeadlineEngine.enforcementDate(for: fine, settings: settings).map(iso) ?? "",
                fine.article,
                fine.details,
                fine.location,
                fine.issuingAuthority,
                number(store.totalPaid(forFine: fine.id)),
                fine.appeal?.outcome?.title ?? "",
                fine.closedAt.map(iso) ?? "",
                fine.notes
            ])
        }
        return csv(rows)
    }

    @MainActor
    static func csvPayments(_ store: Store) -> String {
        var rows: [[String]] = [[
            "Subject", "Amount Paid", "Expected Amount", "Difference",
            "Date", "Method", "Reference", "Paid By", "Notes"
        ]]
        for payment in store.payments {
            rows.append([
                payment.subjectSnapshot,
                number(payment.amountPaid),
                payment.expectedAmount.map(number) ?? "",
                payment.discrepancy.map(number) ?? "",
                iso(payment.date),
                payment.method.title,
                payment.reference,
                store.driver(payment.paidByDriverID)?.name ?? payment.paidByName,
                payment.notes
            ])
        }
        return csv(rows)
    }

    @MainActor
    static func csvDocuments(_ store: Store) -> String {
        var rows: [[String]] = [[
            "Document", "Subject", "Reference", "Valid From", "Valid Until",
            "Cost", "Reminder Days", "Last Renewed", "Notes"
        ]]
        for document in store.documents {
            rows.append([
                document.type.title,
                store.subject(for: document),
                document.reference,
                document.validFrom.map(iso) ?? "",
                iso(document.validUntil),
                document.cost.map(number) ?? "",
                document.reminderDays.map(String.init) ?? "",
                document.renewedAt.map(iso) ?? "",
                document.notes
            ])
        }
        return csv(rows)
    }

    private static func csv(_ rows: [[String]]) -> String {
        rows.map { row in
            row.map { field in
                let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\""
            }.joined(separator: ",")
        }.joined(separator: "\n")
    }

    private static func iso(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func number(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    // MARK: Files

    @MainActor
    static func writeCSVs(_ store: Store) throws -> [URL] {
        let folder = FileManager.default.temporaryDirectory
        var urls: [URL] = []
        let files: [(String, String)] = [
            ("ticket-ledger-fines.csv", csvFines(store)),
            ("ticket-ledger-payments.csv", csvPayments(store)),
            ("ticket-ledger-documents.csv", csvDocuments(store))
        ]
        for (name, contents) in files {
            let url = folder.appendingPathComponent(name)
            try contents.write(to: url, atomically: true, encoding: .utf8)
            urls.append(url)
        }
        return urls
    }

    // MARK: PDF

    @MainActor
    static func writePDF(_ store: Store) throws -> URL {
        let pageSize = CGSize(width: 595, height: 842) // A4 at 72dpi
        let margin: CGFloat = 40
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ticket-ledger-summary.pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let settings = store.data.settings
        let currency = settings.currencyCode

        // Build the lines first, then paginate them.
        enum Line {
            case title(String)
            case section(String)
            case body(String)
            case rule
            case gap
        }

        var lines: [Line] = []
        lines.append(.title("Ticket Ledger — Summary"))
        lines.append(.body("Generated \(Fmt.date(Date()))\(settings.displayName.isEmpty ? "" : " for \(settings.displayName)")"))
        lines.append(.body("Local records entered by hand. Not an official document and not legal advice."))
        lines.append(.gap)

        lines.append(.section("Vehicles"))
        lines.append(.rule)
        if store.vehicles.isEmpty {
            lines.append(.body("None recorded."))
        }
        for vehicle in store.vehicles {
            var text = "\(vehicle.plate.uppercased())  \(vehicle.makeModel)"
            if !vehicle.year.isEmpty { text += " (\(vehicle.year))" }
            if let sale = vehicle.saleDate { text += " — sold \(Fmt.date(sale))" }
            lines.append(.body(text))
        }
        lines.append(.gap)

        lines.append(.section("Fines"))
        lines.append(.rule)
        if store.fines.isEmpty {
            lines.append(.body("None recorded."))
        }
        for fine in store.fines {
            lines.append(.body("\(fine.noticeNumber)  \(fine.vehiclePlateSnapshot.uppercased())  \(fine.status.title)"))
            var detail = "  \(Fmt.date(fine.dateOfOffence)) · \(Fmt.money(fine.amount, currency))"
            if let discounted = fine.discountedAmount {
                detail += " (discounted \(Fmt.money(discounted, currency)))"
            }
            if !fine.location.isEmpty { detail += " · \(fine.location)" }
            lines.append(.body(detail))
            if let deadline = DeadlineEngine.discountDeadline(for: fine, settings: settings) {
                lines.append(.body("  Discount until \(Fmt.date(deadline))"))
            }
            if let deadline = DeadlineEngine.appealDeadline(for: fine, settings: settings) {
                lines.append(.body("  Appeal until \(Fmt.date(deadline))"))
            }
            if let deadline = DeadlineEngine.enforcementDate(for: fine, settings: settings) {
                lines.append(.body("  Enforcement from \(Fmt.date(deadline))"))
            }
            let paid = store.totalPaid(forFine: fine.id)
            if paid > 0 { lines.append(.body("  Paid \(Fmt.money(paid, currency))")) }
            if let outcome = fine.appeal?.outcome {
                lines.append(.body("  Appeal outcome: \(outcome.title)"))
            }
            lines.append(.gap)
        }

        lines.append(.section("Documents"))
        lines.append(.rule)
        if store.documents.isEmpty {
            lines.append(.body("None recorded."))
        }
        for document in store.documents {
            lines.append(.body("\(document.type.title) · \(store.subject(for: document)) · valid until \(Fmt.date(document.validUntil))"))
        }
        lines.append(.gap)

        lines.append(.section("Payments"))
        lines.append(.rule)
        if store.payments.isEmpty {
            lines.append(.body("None recorded."))
        }
        for payment in store.payments {
            var text = "\(Fmt.date(payment.date))  \(Fmt.money(payment.amountPaid, currency))  \(payment.method.title)"
            if !payment.subjectSnapshot.isEmpty { text += "  — \(payment.subjectSnapshot)" }
            lines.append(.body(text))
        }

        let titleFont = UIFont.systemFont(ofSize: 22, weight: .black)
        let sectionFont = UIFont.systemFont(ofSize: 12, weight: .bold)
        let bodyFont = UIFont.systemFont(ofSize: 10, weight: .regular)
        let anchor = UIColor(Theme.anchor)
        let gold = UIColor(Theme.goldDark)

        try renderer.writePDF(to: url) { context in
            var y: CGFloat = margin
            context.beginPage()

            func newPageIfNeeded(_ height: CGFloat) {
                if y + height > pageSize.height - margin {
                    context.beginPage()
                    y = margin
                }
            }

            for line in lines {
                switch line {
                case .title(let text):
                    newPageIfNeeded(34)
                    draw(text, font: titleFont, color: anchor, at: CGPoint(x: margin, y: y), width: pageSize.width - margin * 2)
                    y += 34
                case .section(let text):
                    newPageIfNeeded(22)
                    draw(text.uppercased(), font: sectionFont, color: gold, at: CGPoint(x: margin, y: y), width: pageSize.width - margin * 2)
                    y += 16
                case .body(let text):
                    let height = textHeight(text, font: bodyFont, width: pageSize.width - margin * 2)
                    newPageIfNeeded(height + 2)
                    draw(text, font: bodyFont, color: anchor, at: CGPoint(x: margin, y: y), width: pageSize.width - margin * 2)
                    y += height + 2
                case .rule:
                    newPageIfNeeded(8)
                    let path = UIBezierPath(rect: CGRect(x: margin, y: y, width: pageSize.width - margin * 2, height: 1.5))
                    gold.setFill()
                    path.fill()
                    y += 8
                case .gap:
                    y += 10
                }
            }
        }
        return url
    }

    private static func draw(_ text: String, font: UIFont, color: UIColor, at point: CGPoint, width: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let rect = CGRect(x: point.x, y: point.y, width: width, height: textHeight(text, font: font, width: width))
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }

    private static func textHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(bounds.height)
    }
}

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Document picker for import

struct JSONImportPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: JSONImportPicker
        init(_ parent: JSONImportPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { parent.onPick(url) }
            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}
