//
//  Status.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/04/20.
//

import Foundation

enum Status:Equatable {
    case update(Location)
    case delete(Date)
    case loading(Date)
    case locationError(Date)
    case apiError(Date)
}

extension Status {
    var text: String {
        switch self {
        case .update(let location):
            return "\(location.timestamp.text()) 送信成功"
        case .loading(let date):
            return "\(date.text()) 読み込み中"
        case .locationError(let date):
            return "\(date.text()) 取得失敗"
        case .apiError(let date):
            return "\(date.text()) 送信失敗"
        case .delete(let date):
            return "\(date.text()) 削除済み"
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
        case .apiError(let date):
            return date.text()
        case .delete(let date):
            return date.text()
        }
    }
}

