//
//  APIError.swift
//  MaTool
//
//  Created by 松下和也 on 2025/06/19.
//

import Foundation

enum APIError: Error, Equatable, Hashable {
    case network(statusCode: Int?, message: String)
    case notFound(message: String)
    case unauthorized(message: String)
    case forbidden(message: String)
    case badRequest(message: String)
    case decoding(message: String)
    case encoding(message: String)
    case unknown(message: String)
    
    init(_ error: Error) {
        if let nsError = error as NSError? {
            let code = nsError.code
            switch code {
            case 400: self = .badRequest(message: nsError.localizedDescription)
            case 401: self = .unauthorized(message: nsError.localizedDescription)
            case 403: self = .forbidden(message: nsError.localizedDescription)
            case 404: self = .notFound(message: nsError.localizedDescription)
            case 500...599: self = .network(statusCode: code, message: nsError.localizedDescription)
            default: self = .unknown(message: nsError.localizedDescription)
            }
        } else {
            self = .unknown(message: error.localizedDescription)
        }
    }

    var localizedDescription: String {
        switch self {
        case .network(let statusCode, let message):
            return "サーバーエラー(\(statusCode ?? -1))が発生しました。 \n\(message)"
        case .notFound(let message):
            return " 情報が見つかりません。 \n\(message)"
        case .unauthorized(let message):
            return "ログインの有効期限が切れました。\n再度ログインしてください。 \n\(message)"
        case .forbidden(let message):
            return "アクセス権限がありません。 \n\(message)"
        case .badRequest(let message):
            return "リクエストが不正です。 \n\(message)"
        case .decoding(let message):
            return "データの読み取りに失敗しました。 \n\(message)"
        case .encoding(let message):
            return "データの変換に失敗しました。 \n\(message)"
        case .unknown(let message):
            return "予期せぬエラーが発生しました。 \n\(message)"
        }
    }
}

