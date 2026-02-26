//
//  AppStatus.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/12.
//

import Foundation

struct AppStatus: Sendable, Decodable {
    let maintenance: Maintenance?
    let update: Update
}

struct Update: Sendable, Decodable {
    let ios: UpdateInfo
    let android: UpdateInfo?  // optionalに変更
}

struct Maintenance: Sendable, Decodable {
    let message: String
    let until: Date
}

struct UpdateInfo: Sendable, Decodable {
    let requiredVersion: String
    let storeUrl: URL
}

enum StatusCheckResult: Equatable {
    case maintenance(message: String, until: Date)
    case updateRequired(storeURL: URL)
}

extension StatusCheckResult: Identifiable {
    var id: String {
        switch self {
        case .maintenance(message: let message, until: _):
            return message
        case .updateRequired(storeURL: let storeURL):
            return storeURL.absoluteString
        }
    }
}
