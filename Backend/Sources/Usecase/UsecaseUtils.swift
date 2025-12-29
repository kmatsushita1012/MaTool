//
//  UsecaseUtils.swift
//  matool-backend
//
//  Created by 松下和也 on 2025/12/20.
//

import Foundation
import Shared

func hasAccess(festivalId: String, districtId: String, visibility: Visibility, user: UserRole) -> Bool{
    return (visibility == .admin) || hasAccess(festivalId: festivalId, districtId: districtId, user: user)
}

func hasAccess(festivalId: String, districtId: String, user: UserRole) -> Bool{
    return {
        switch user {
        case .guest:
            false
        case .district(let id):
            districtId == id
        case .headquarter(let id):
            festivalId == id
        }
    }()
}

let threthold: TimeInterval = 15 * 60



