//
//  APIError.swift
//  TicketLedger
//

import Foundation

enum APIError: LocalizedError, Equatable {
    /// The device has no route to the server. Not a reason to sign anyone out.
    case offline
    case timedOut
    case unauthorized(String)
    case forbidden(String)
    case notFound
    case conflict(String)
    case validation(fields: [String: String], message: String)
    case rateLimited(retryAfter: Int, message: String)
    case server(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .offline:
            "No connection to the server. Your records are safe on this device and will sync later."
        case .timedOut:
            "The server took too long to answer. Try again."
        case .unauthorized(let message):
            message
        case .forbidden(let message):
            message
        case .notFound:
            "That record is no longer on the server."
        case .conflict(let message):
            message
        case .validation(_, let message):
            message
        case .rateLimited(let retryAfter, let message):
            retryAfter > 60
                ? "\(message) Try again in about \(max(1, retryAfter / 60)) minutes."
                : "\(message) Try again in \(retryAfter) seconds."
        case .server(let message):
            message
        case .decoding:
            "The server sent something this app could not read."
        }
    }

    /// Field level messages, so a form can mark the input that was refused.
    var fieldErrors: [String: String] {
        if case .validation(let fields, _) = self { return fields }
        return [:]
    }

    /// True when the session itself is gone and the app has to sign out.
    var isAuthFailure: Bool {
        if case .unauthorized = self { return true }
        return false
    }
}
