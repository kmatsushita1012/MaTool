//
//  ApiError.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/06/19.
//

enum ApiError: Error, Equatable {
    case network(String)
    case encoding(String)
    case decoding(String)
    case unauthorized(String)
    case unknown(String)
    
    var localizedDescription: String {
        switch self {
        case .network(let message):
            return "通信中に問題が発生しました。 \n\(message)"
        case .encoding(let message):
            return "データの変換中に問題が発生しました。 \n\(message)"
        case .decoding(let message):
            return "受け取ったデータの読み取りに失敗しました。 \n\(message)"
        case .unauthorized(let message):
            return "ログインの有効期限が切れました。\nもう一度ログインしてください。 \n\(message)"
        case .unknown(let message):
            return "予期しないエラーが発生しました。 \n\(message)"
        }
    }
}
