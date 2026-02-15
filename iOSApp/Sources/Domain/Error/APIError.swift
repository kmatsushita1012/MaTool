//
//  APIError.swift
//  MaTool
//
//  Created by 松下和也 on 2025/06/19.
//

import Foundation

enum APIError: LocalizedError, Equatable, Hashable {
    case network(message: String)
    case server(statusCode: Int, message: String)
    case notFound(message: String)
    case unauthorized(message: String)
    case forbidden(message: String)
    case badRequest(message: String)
    case decoding(message: String)
    case encoding(message: String)
    case unknown(message: String)
    case cache(message: String)

    init(statusCode: Int?, message: String) {
        guard let statusCode else {
            self = .network(message: message)
            return
        }
        switch statusCode {
        case 400:
            self = .badRequest(message: message)
        case 401:
            self = .unauthorized(message: message)
        case 403:
            self = .forbidden(message: message)
        case 404:
            self = .notFound(message: message)
        case 500...599:
            self = .server(statusCode: statusCode, message: message)
        default:
            self = .unknown(message: message)
        }
    }

    var errorDescription: String? {
        switch self {
        case .network(let message):
            return message
        case .notFound(let message):
            return message
        case .unauthorized(let message):
            return "\(message) \nログインし直してください。"
        case .forbidden(let message):
            return message
        case .badRequest(let message):
            return message
        case .decoding(let message):
            return "データの読み取りに失敗しました。 \n\(message)"
        case .encoding(let message):
            return "データの変換に失敗しました。 \n\(message)"
        case .unknown(let message):
            return "予期せぬエラーが発生しました。 \n\(message)"
        case .cache(message: let message):
            return "キャッシュでエラーが発生しました \n\(message)"
        case .server(statusCode: let statusCode, message: let message):
            return "サーバーエラーが発生しました。\nステータスコード: \(statusCode)\n\(message) "
        }
    }
}

