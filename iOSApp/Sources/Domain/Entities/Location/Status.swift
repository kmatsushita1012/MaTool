//
//  Status.swift
//  MaTool
//
//  Created by 松下和也 on 2025/04/20.
//

import Foundation
import Shared

enum Status:Sendable, Equatable, Hashable {
    case update(FloatLocation)
    case delete(Date)
    case loading(Date)
    case locationError(Date)
    case apiError(Date, APIError)
}

extension Status {
    var text: String {
        switch self {
        case .update(let location):
            return "\(location.timestamp.text(of: "HH:mm:ss")) 送信成功"
        case .loading(let date):
            return "\(date.text(of: "HH:mm:ss")) 読み込み中"
        case .locationError(let date):
            return "\(date.text(of: "HH:mm:ss")) 取得失敗"
        case .apiError(let date, let error):
            return "\(date.text(of: "HH:mm:ss")) 送信失敗 \(error.localizedDescription)"
        case .delete(let date):
            return "\(date.text(of: "HH:mm:ss")) 削除済み"
        }
    }
}


extension Status: Identifiable {
    var id: String {
        switch self {
        case .update(let location):
            return location.timestamp.text()
        case .loading(let date):
            return date.text()
        case .locationError(let date):
            return date.text()
        case .apiError(let date, _):
            return date.text()
        case .delete(let date):
            return date.text()
        }
    }
}

