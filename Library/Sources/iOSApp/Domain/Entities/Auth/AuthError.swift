//
//  AuthError.swift
//  MaTool
//
//  Created by 松下和也 on 2025/06/19.
//

enum AuthError: Error, Equatable {
    case network(String)
    case encoding(String)
    case decoding(String)
    case unknown(String)
    case auth(String)
    case timeout(String)
    
    var localizedDescription: String {
        switch self {
        case .network(let message):
            return "ネットワークエラー \(message)"
        case .encoding(let message):
            return "送信失敗 \(message)"
        case .decoding(let message):
            return "解析失敗 \(message)"
        case .unknown(let message):
            return "予期しないエラー \(message)"
        case .auth(let message):
            return "認証エラー \(message) このエラーが繰り返し発生する場合は、設定画面からログアウトし、再度サインインしてください。"
        case .timeout(let message):
            return "タイムアウト \(message) このエラーが繰り返し発生する場合は、設定画面からログアウトし、再度サインインしてください。"
        }
    }
}
