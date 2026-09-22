//
//  AppStatus.swift
//  MaTool
//
//  Created by 松下和也 on 2025/08/12.
//

import Foundation

public struct AppStatus: Sendable, Decodable {
    public let maintenance: Maintenance?
    public let update: Update
}

public struct Update: Sendable, Decodable {
    public let ios: UpdateInfo
    public let android: UpdateInfo?
}

public struct Maintenance: Sendable, Decodable {
    public let message: String
    public let until: Date
}

public struct UpdateInfo: Sendable, Decodable {
    public let requiredVersion: String
    public let storeUrl: URL
}

public enum StatusCheckResult: Equatable, Sendable {
    case maintenance(message: String, until: Date)
    case updateRequired(storeURL: URL)
}

extension StatusCheckResult: Identifiable {
    public var id: String {
        switch self {
        case .maintenance(message: let message, until: _):
            return message
        case .updateRequired(storeURL: let storeURL):
            return storeURL.absoluteString
        }
    }
}
