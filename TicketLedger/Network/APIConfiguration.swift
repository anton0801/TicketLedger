import Foundation
import UIKit

enum APIConfiguration {
    private static let overrideKey = "api.baseURL"

    static let fallbackURL = URL(string: "https://ticket-app.space")!

    static var baseURL: URL {
        if let stored = UserDefaults.standard.string(forKey: overrideKey),
           let url = URL(string: stored) {
            return url
        }
        return fallbackURL
    }

    /// - Returns: nil when the address is usable, otherwise the reason it is not.
    @discardableResult
    static func setBaseURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            UserDefaults.standard.removeObject(forKey: overrideKey)
            return nil
        }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              let host = url.host, !host.isEmpty else {
            return "That is not a usable web address."
        }
        guard scheme == "https" || scheme == "http" else {
            return "The address has to start with https://"
        }
        if scheme == "http" && !isLocal(host) {
            return "Plain http is only allowed for a server on this machine. Use https:// for anything else."
        }
        UserDefaults.standard.set(trimmed, forKey: overrideKey)
        return nil
    }

    static func isLocal(_ host: String) -> Bool {
        host == "localhost" || host == "127.0.0.1" || host == "::1" || host.hasSuffix(".local")
    }

    static var isUsingLocalServer: Bool {
        isLocal(baseURL.host ?? "")
    }

    static let requestTimeout: TimeInterval = 20
    static let deviceName: String = {
        return UIDevice.current.name
    }()
}
