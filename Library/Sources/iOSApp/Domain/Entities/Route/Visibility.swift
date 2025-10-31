//
//  Visibility.swift
//  MaTool
//
//  Created by 松下和也 on 2025/05/08.
//
import Shared

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
    
    var isTimeHidden: Bool {
        switch self {
        case .admin, .route:
            return true
        case .all:
            return false
        }
    }
}
