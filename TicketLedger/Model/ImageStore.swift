//
//  ImageStore.swift
//  TicketLedger
//
//  Photos of notices, documents and evidence live as files next to the ledger,
//  so the JSON stays small and nothing leaves the device.
//

import SwiftUI
import UIKit

enum ImageStore {
    private static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TicketLedger/Media", isDirectory: true)
        if !FileManager.default.fileExists(atPath: base.path) {
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base
    }

    static func url(for name: String) -> URL {
        folder.appendingPathComponent(name)
    }

    /// Saves a JPEG, downscaled so a ledger of hundreds of photos stays sane.
    @discardableResult
    static func save(_ image: UIImage, name: String = UUID().uuidString + ".jpg") -> String? {
        let resized = downscale(image, maxDimension: 2000)
        guard let data = resized.jpegData(compressionQuality: 0.8) else { return nil }
        do {
            try data.write(to: url(for: name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func load(_ name: String?) -> UIImage? {
        guard let name, !name.isEmpty else { return nil }
        return UIImage(contentsOfFile: url(for: name).path)
    }

    static func delete(_ name: String?) {
        guard let name, !name.isEmpty else { return }
        try? FileManager.default.removeItem(at: url(for: name))
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: folder)
    }

    static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

/// Thumbnail that keeps the token look and never shows a broken box.
struct StoredImageView: View {
    var name: String?
    var height: CGFloat = 120
    var dark: Bool = false

    var body: some View {
        if let image = ImageStore.load(name) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.gold.opacity(0.6), lineWidth: 2)
                )
        } else {
            HStack(spacing: 8) {
                Image(systemName: "photo")
                Text("No photo attached")
                    .font(TypeScale.caption)
            }
            .foregroundStyle((dark ? Theme.page : Theme.anchor).opacity(0.4))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2))
                    .foregroundStyle(Theme.gold.opacity(0.25))
            )
        }
    }
}
