//
//  Visibility.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/05/08.
//

enum Visibility: String, Codable, Hashable, CaseIterable {
    case admin
    case route
    case all
}

extension Visibility: Identifiable{
    var id: Self { self }
}

extension Visibility {
    var label: String {
        switch self {
        case .admin:
            return "非公開"
        case .route:
            return "経路のみ公開"
        case .all:
            return "全て公開"
        }
    }
}
