//
//  LocationError.swift
//  MaTool
//
//  Created by Codex on 2026/03/21.
//

import Foundation

enum LocationError: LocalizedError, Sendable {
    case authorizationDenied
    case servicesDisabled

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            "位置情報の常に許可がありません。"
        case .servicesDisabled:
            "位置情報サービスが無効です。"
        }
    }
}
