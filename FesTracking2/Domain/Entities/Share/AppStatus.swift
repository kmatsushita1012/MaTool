//
//  AppStatus.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/08/12.
//

import Foundation

struct AppStatus: Sendable, Decodable {
    let maintenance: Maintenance
    let update: Update
}

struct Update: Sendable, Decodable {
    let ios: UpdateInfo
    let android: UpdateInfo?  // optionalに変更
}

struct Maintenance: Sendable, Decodable {
    let isActive: Bool
    let message: String
    let until: Date
}

struct UpdateInfo: Sendable, Decodable {
    let requiredVersion: String
    let storeUrl: URL
}

enum StatusCheckResult: Equatable {
    case maintenance(message: String)
    case updateRequired(storeURL: URL)
}

extension StatusCheckResult: Identifiable {
    var id: String {
        switch self {
        case .maintenance(message: let message):
            return message
        case .updateRequired(storeURL: let storeURL):
            return storeURL.absoluteString
        }
    }
}


extension String {
    func isVersion(greaterThanOrEqualTo other: String) -> Bool {
        let components1 = self.split(separator: ".").compactMap { Int($0) }
        let components2 = other.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(components1.count, components2.count) {
            let v1 = i < components1.count ? components1[i] : 0
            let v2 = i < components2.count ? components2[i] : 0
            if v1 > v2 { return true }
            if v1 < v2 { return false }
        }
        return true
    }
}

