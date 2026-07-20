//
//  AppError.swift
//  MaTool
//
//  Created by 松下和也 on 2025/06/19.
//

import Foundation
import Shared

enum AppError: LocalizedError, Equatable, Hashable, Sendable {
    case be(BEErrorKind)
    case auth(AuthErrorKind)
    case location(LocationErrorKind)
    case export(ExportErrorKind)
    case validation(ValidationErrorKind)
    case persistence(PersistenceErrorKind)
    case system(SystemErrorKind)

    init(statusCode: Int?, message: String) {
        guard let statusCode else {
            self = .be(.network(message))
            return
        }
        switch statusCode {
        case 400:
            self = .be(.badRequest(message))
        case 401:
            self = .be(.unauthorized(message))
        case 403:
            self = .be(.forbidden(message))
        case 404:
            self = .be(.notFound(message))
        case 409:
            self = .be(.conflict(message))
        case 500...599:
            self = .be(.server(statusCode: statusCode, message: message))
        default:
            self = .be(.unknown(message))
        }
    }

    var message: String {
        switch self {
        case .be(let error):
            return error.message
        case .auth(let error):
            return error.message
        case .location(let error):
            return error.message
        case .export(let error):
            return error.message
        case .validation(let error):
            return error.message
        case .persistence(let error):
            return error.message
        case .system(let error):
            return error.message
        }
    }

    var errorDescription: String? {
        message
    }
}

extension AppError {
    enum BEErrorKind: Equatable, Hashable, Sendable {
        case badRequest(String)
        case unauthorized(String)
        case forbidden(String)
        case notFound(String)
        case conflict(String)
        case server(statusCode: Int, message: String)
        case network(String)
        case timeout(String)
        case unknown(String)

        var message: String {
            switch self {
            case .badRequest(let message),
                 .forbidden(let message),
                 .notFound(let message),
                 .conflict(let message),
                 .network(let message),
                 .timeout(let message),
                 .unknown(let message):
                return message
            case .unauthorized(let message):
                return "\(message)\nログインし直してください。"
            case .server(let statusCode, let message):
                return "サーバーエラーが発生しました。\nステータスコード: \(statusCode)\n\(message)"
            }
        }
    }

    enum AuthErrorKind: Equatable, Hashable, Sendable {
        case badRequest(String)
        case unauthorized(String)
        case forbidden(String)
        case conflict(String)
        case network(String)
        case timeout(String)
        case configuration(String)
        case cancelled(String)
        case unknown(String)

        var message: String {
            switch self {
            case .badRequest(let message),
                 .unauthorized(let message),
                 .forbidden(let message),
                 .conflict(let message),
                 .network(let message),
                 .configuration(let message),
                 .cancelled(let message),
                 .unknown(let message):
                return message
            case .timeout(let message):
                return "タイムアウト \(message) このエラーが繰り返し発生する場合は、設定画面からログアウトし、再度サインインしてください。"
            }
        }
    }

    enum LocationErrorKind: Equatable, Hashable, Sendable {
        case badRequest(String)
        case unauthorized(String)
        case forbidden(String)
        case notFound(String)
        case network(String)
        case timeout(String)
        case servicesDisabled(String)
        case permissionDenied(String)
        case unknown(String)

        var message: String {
            switch self {
            case .badRequest(let message),
                 .unauthorized(let message),
                 .forbidden(let message),
                 .notFound(let message),
                 .network(let message),
                 .timeout(let message),
                 .servicesDisabled(let message),
                 .permissionDenied(let message),
                 .unknown(let message):
                return message
            }
        }
    }

    enum ExportErrorKind: Equatable, Hashable, Sendable {
        case badRequest(String)
        case notFound(String)
        case conflict(String)
        case timeout(String)
        case unknown(String)

        var message: String {
            switch self {
            case .badRequest(let message),
                 .notFound(let message),
                 .conflict(let message),
                 .timeout(let message),
                 .unknown(let message):
                return message
            }
        }
    }

    enum ValidationErrorKind: Equatable, Hashable, Sendable {
        case badRequest(String)
        case conflict(String)
        case unknown(String)

        var message: String {
            switch self {
            case .badRequest(let message),
                 .conflict(let message),
                 .unknown(let message):
                return message
            }
        }
    }

    enum PersistenceErrorKind: Equatable, Hashable, Sendable {
        case badRequest(String)
        case notFound(String)
        case conflict(String)
        case database(String)
        case cache(String)
        case unknown(String)

        var message: String {
            switch self {
            case .badRequest(let message),
                 .notFound(let message),
                 .conflict(let message),
                 .database(let message),
                 .cache(let message),
                 .unknown(let message):
                return message
            }
        }
    }

    enum SystemErrorKind: Equatable, Hashable, Sendable {
        case badRequest(String)
        case network(String)
        case timeout(String)
        case decoding(String)
        case encoding(String)
        case invalidURL(String)
        case unexpected(String)
        case unknown(String)

        var message: String {
            switch self {
            case .badRequest(let message):
                return message
            case .network(let message):
                return message
            case .timeout(let message):
                return message
            case .decoding(let message):
                return "データの読み取りに失敗しました。\n\(message)"
            case .encoding(let message):
                return "データの変換に失敗しました。\n\(message)"
            case .invalidURL(let message):
                return "URLの生成に失敗しました。\n\(message)"
            case .unexpected(let message),
                 .unknown(let message):
                return "予期せぬエラーが発生しました。\n\(message)"
            }
        }
    }
}

extension Error {
    var asAppError: AppError {
        if let error = self as? AppError {
            return error
        }
        if let error = self as? PresentationError {
            return error.appError
        }
        if let error = self as? Point.Error {
            return .validation(.badRequest(error.localizedDescription))
        }
        if let error = self as? DomainError {
            return .validation(.badRequest(String(describing: error)))
        }
        return .system(.unexpected(localizedDescription))
    }
}
